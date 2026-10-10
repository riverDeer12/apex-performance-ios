//
//  PersonalRecord.swift
//  ApexPerformance
//

import Foundation

/// Record of a client in an exercise, calculated by the API from
/// completed trainings (GET personal-records).
struct PersonalRecord: Identifiable, Decodable, Hashable {
    let id: UUID
    let clientId: UUID
    let workoutId: UUID
    // Persisted JSON with the workout name translations.
    let workoutName: LocalizedText
    let trainingId: UUID
    // "MaxWeight" or "EstimatedOneRepMax".
    let type: String
    let value: Decimal
    let weight: Decimal
    let reps: Decimal?
    let achievedAt: Date

    var isMaxWeight: Bool { type == "MaxWeight" }
}

extension PersonalRecord {
    /// Record history of the client, newest first (staff only).
    @MainActor
    static func load(clientId: UUID) async throws -> [PersonalRecord] {
        var components = URLComponents(
            url: AppEnvironment.apiURL.appendingPathComponent("personal-records"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "clientId", value: clientId.uuidString)]
        guard let url = components?.url else { return [] }

        let records: [PersonalRecord] = try await APIClient.shared.request(url)
        return records.sorted { $0.achievedAt > $1.achievedAt }
    }
}

/// Current records of one exercise with its whole record history.
struct ExerciseRecords: Identifiable {
    // Records set in this many days are marked as new, like the web.
    static let recentDays = 14

    let workoutId: UUID
    let name: String
    let maxWeight: PersonalRecord?
    let oneRepMax: PersonalRecord?
    // Newest first.
    let history: [PersonalRecord]

    var id: UUID { workoutId }
    var lastAchievedAt: Date { history.first?.achievedAt ?? .distantPast }

    var isRecent: Bool {
        guard let from = Calendar.current.date(byAdding: .day, value: -Self.recentDays, to: .now) else { return false }
        return lastAchievedAt >= from
    }

    /// Records grouped by exercise, the latest records first.
    static func group(_ records: [PersonalRecord]) -> [ExerciseRecords] {
        Dictionary(grouping: records, by: \.workoutId)
            .map { workoutId, records in
                let history = records.sorted { $0.achievedAt > $1.achievedAt }
                return ExerciseRecords(
                    workoutId: workoutId,
                    name: history[0].workoutName.localized,
                    // History is newest first, so the first record of a type is the current one.
                    maxWeight: history.first(where: \.isMaxWeight),
                    oneRepMax: history.first { !$0.isMaxWeight },
                    history: history
                )
            }
            .sorted { $0.lastAchievedAt > $1.lastAchievedAt }
    }
}
