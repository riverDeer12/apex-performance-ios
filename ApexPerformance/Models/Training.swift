//
//  Training.swift
//  ApexPerformance
//

import Foundation

/// Training a coach prepared for a client (GET trainings). Clients get
/// their own trainings, coaches the trainings of their clients.
struct Training: Identifiable, Decodable, Hashable {
    let id: UUID
    let name: String
    let date: Date
    let note: String?
    let isCompleted: Bool
    let completedAt: Date?
    let client: Person
    let exercises: [Exercise]

    struct Person: Decodable, Hashable {
        let id: UUID
        let firstName: String?
        let lastName: String?
    }

    struct Exercise: Identifiable, Decodable, Hashable {
        let id: UUID
        let workoutId: UUID
        // Persisted JSON with the workout name translations.
        let workoutName: LocalizedText
        let order: Int
        let note: String?
        let sets: [ExerciseSet]
    }

    struct ExerciseSet: Identifiable, Decodable, Hashable {
        let id: UUID
        let order: Int
        let reps: String?
        let weight: Decimal?
    }
}

extension Training {
    /// All trainings the logged user can see, newest first.
    @MainActor
    static func loadAll() async throws -> [Training] {
        let url = AppEnvironment.apiURL.appendingPathComponent("trainings")
        let trainings: [Training] = try await APIClient.shared.request(url)
        return trainings.sorted { $0.date > $1.date }
    }

    /// Completed trainings the logged user can see, newest first.
    @MainActor
    static func loadCompleted() async throws -> [Training] {
        try await loadAll().filter(\.isCompleted)
    }

    /// Creates a training, or updates it when an id is given (staff only).
    @MainActor
    static func save(_ request: SaveTrainingRequest, id: UUID? = nil) async throws -> Training {
        var url = AppEnvironment.apiURL.appendingPathComponent("trainings")
        if let id {
            url = url.appendingPathComponent(id.uuidString)
        }
        return try await APIClient.shared.request(
            url,
            method: id == nil ? .post : .put,
            body: JSONEncoder().encode(request)
        )
    }
}

/// Body of POST trainings and PUT trainings/{id}.
struct SaveTrainingRequest: Encodable {
    let client: UUID
    let name: String
    // ISO 8601, as the API expects a DateTimeOffset.
    let date: String
    let note: String?
    let isCompleted: Bool
    let exercises: [Exercise]

    struct Exercise: Encodable {
        let workout: UUID
        let note: String?
        let sets: [ExerciseSet]
    }

    struct ExerciseSet: Encodable {
        let reps: String?
        let weight: Decimal?
    }
}
