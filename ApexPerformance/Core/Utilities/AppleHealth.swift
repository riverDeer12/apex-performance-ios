//
//  AppleHealth.swift
//  ApexPerformance
//

import Foundation
import HealthKit

/// Client's heart rate from Apple Health (Apple Watch or a chest strap),
/// read between a training's start and end on the client's iPhone. Only the
/// lowest, highest and average value go to the server.
enum AppleHealth {
    private static let store = HKHealthStore()
    private static let heartRateType = HKQuantityType(.heartRate)
    private static let connectedKey = "appleHealthConnected"
    private static let dailyConnectedKey = "appleHealthDailyConnected"

    // The client's day on the home screen: read on the iPhone, shown only
    // to the client, never sent to the server.
    private static let sleepType = HKCategoryType(.sleepAnalysis)
    private static let stepsType = HKQuantityType(.stepCount)
    private static let activeEnergyType = HKQuantityType(.activeEnergyBurned)
    private static let restingHeartRateType = HKQuantityType(.restingHeartRate)

    // Trainings older than this aren't read automatically any more.
    private static let syncedDays = 30

    /// Not on iPad.
    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// The client was asked once; iOS doesn't tell apps whether reading
    /// was allowed, without permission there are just no measurements.
    static var isConnected: Bool {
        UserDefaults.standard.bool(forKey: connectedKey)
    }

    static func connect() async throws {
        try await store.requestAuthorization(toShare: [], read: [heartRateType])
        UserDefaults.standard.set(true, forKey: connectedKey)
    }

    /// The client allowed reading their day (sleep, steps, energy, resting heart rate) once.
    static var isDailyConnected: Bool {
        UserDefaults.standard.bool(forKey: dailyConnectedKey)
    }

    static func connectDaily() async throws {
        try await store.requestAuthorization(
            toShare: [],
            read: [heartRateType, sleepType, stepsType, activeEnergyType, restingHeartRateType]
        )
        UserDefaults.standard.set(true, forKey: dailyConnectedKey)
        UserDefaults.standard.set(true, forKey: connectedKey)
    }

    /// Sleep last night, steps and active energy today, latest resting heart rate.
    struct DailySummary: Equatable {
        var sleepMinutes: Int?
        var steps: Int?
        var activeEnergyKilocalories: Int?
        var restingHeartRate: Int?
        var updatedAt = Date()

        var isEmpty: Bool {
            sleepMinutes == nil && steps == nil && activeEnergyKilocalories == nil && restingHeartRate == nil
        }
    }

    static func dailySummary(now: Date = .now) async -> DailySummary {
        let today = Calendar.current.startOfDay(for: now)
        async let sleepValue = sleepMinutes(endingBefore: now, dayStart: today)
        async let steps = sum(stepsType, unit: .count(), from: today, to: now)
        async let energy = sum(activeEnergyType, unit: .kilocalorie(), from: today, to: now)
        async let resting = latest(restingHeartRateType, unit: HKUnit.count().unitDivided(by: .minute()),
                                   since: Calendar.current.date(byAdding: .day, value: -7, to: now) ?? today)
        return await DailySummary(sleepMinutes: sleepValue, steps: steps, activeEnergyKilocalories: energy,
                                  restingHeartRate: resting, updatedAt: now)
    }

    // Asleep time of the night before (from 18:00 the day before), overlapping
    // samples of several sources (Watch, iPhone, apps) counted once.
    private static func sleepMinutes(endingBefore now: Date, dayStart: Date) async -> Int? {
        let start = Calendar.current.date(byAdding: .hour, value: -6, to: dayStart) ?? dayStart
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType,
                                         predicate: HKQuery.predicateForSamples(withStart: start, end: now))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        guard let samples = try? await descriptor.result(for: store) else { return nil }
        let asleep = samples
            .filter { HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue).contains($0.value) }
            .map { (max($0.startDate, start), min($0.endDate, now)) }
            .filter { $0.0 < $0.1 }
        guard !asleep.isEmpty else { return nil }

        var total: TimeInterval = 0
        var current = asleep[0]
        for interval in asleep.dropFirst() {
            if interval.0 <= current.1 {
                current.1 = max(current.1, interval.1)
            } else {
                total += current.1.timeIntervalSince(current.0)
                current = interval
            }
        }
        total += current.1.timeIntervalSince(current.0)
        return Int((total / 60).rounded())
    }

    // Sum for the period; Health counts steps measured by both the iPhone and the Watch once.
    private static func sum(_ type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async -> Int? {
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
            options: .cumulativeSum
        )
        guard let value = try? await descriptor.result(for: store)?.sumQuantity()?.doubleValue(for: unit) else {
            return nil
        }
        return Int(value.rounded())
    }

    private static func latest(_ type: HKQuantityType, unit: HKUnit, since start: Date) async -> Int? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type,
                                         predicate: HKQuery.predicateForSamples(withStart: start, end: .now))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        guard let sample = try? await descriptor.result(for: store).first else { return nil }
        return Int(sample.quantity.doubleValue(for: unit).rounded())
    }

    /// Lowest, highest and average heart rate between the times, nil without measurements.
    static func heartRate(from start: Date, to end: Date) async throws -> Training.HeartRate? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: heartRateType, predicate: predicate),
            options: [.discreteMin, .discreteMax, .discreteAverage]
        )
        let unit = HKUnit.count().unitDivided(by: .minute())
        guard let statistics = try await descriptor.result(for: store),
              let min = statistics.minimumQuantity()?.doubleValue(for: unit),
              let max = statistics.maximumQuantity()?.doubleValue(for: unit),
              let average = statistics.averageQuantity()?.doubleValue(for: unit) else { return nil }
        return Training.HeartRate(min: Int(min.rounded()), max: Int(max.rounded()), average: Int(average.rounded()))
    }

    /// Whether the training has a start and end but no heart rate yet.
    static func needsHeartRate(_ training: Training) -> Bool {
        training.heartRate == nil && training.startedAt != nil && training.endedAt != nil
    }

    /// Reads the training's heart rate and sends it; nil without measurements.
    @MainActor
    static func send(for training: Training) async throws -> Training.HeartRate? {
        guard needsHeartRate(training), let start = training.startedAt, let end = training.endedAt,
              let measured = try await heartRate(from: start, to: end) else { return nil }
        let url = AppEnvironment.apiURL.appendingPathComponent("trainings/\(training.id.uuidString)/heart-rate")
        let saved: Training.HeartRate = try await APIClient.shared.request(
            url, method: .put, body: JSONEncoder().encode(measured)
        )
        return saved
    }

    /// Sends the heart rate of the client's recent trainings that miss it,
    /// once the client connected Apple Health. Returns the updated trainings.
    @MainActor
    static func sendMissing(in trainings: [Training]) async -> [Training] {
        guard isAvailable, isConnected else { return trainings }
        let oldest = Calendar.current.date(byAdding: .day, value: -syncedDays, to: .now) ?? .now
        var updated = trainings
        for index in updated.indices where needsHeartRate(updated[index]) && (updated[index].endedAt ?? .now) > oldest {
            if let heartRate = try? await send(for: updated[index]) {
                updated[index].heartRate = heartRate
            }
        }
        return updated
    }
}
