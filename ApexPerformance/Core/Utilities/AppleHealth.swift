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
