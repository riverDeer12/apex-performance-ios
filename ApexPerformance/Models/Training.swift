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
    /// Completed trainings the logged user can see, newest first.
    @MainActor
    static func loadCompleted() async throws -> [Training] {
        let url = AppEnvironment.apiURL.appendingPathComponent("trainings")
        let trainings: [Training] = try await APIClient.shared.request(url)
        return trainings
            .filter(\.isCompleted)
            .sorted { $0.date > $1.date }
    }
}
