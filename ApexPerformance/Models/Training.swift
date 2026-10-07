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
        // Done right after the previous exercise without rest (superset).
        var isSupersetWithPrevious = false
    }

    struct ExerciseSet: Identifiable, Decodable, Hashable {
        let id: UUID
        let order: Int
        let reps: String?
        let weight: Decimal?
    }
}

extension Training.Exercise {
    private enum CodingKeys: String, CodingKey {
        case id, workoutId, workoutName, order, note, sets, isSupersetWithPrevious
    }

    // In an extension so the memberwise initializer stays available.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        workoutId = try container.decode(UUID.self, forKey: .workoutId)
        workoutName = try container.decode(LocalizedText.self, forKey: .workoutName)
        order = try container.decode(Int.self, forKey: .order)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        sets = try container.decode([Training.ExerciseSet].self, forKey: .sets)
        isSupersetWithPrevious = try container.decodeIfPresent(Bool.self, forKey: .isSupersetWithPrevious) ?? false
    }
}

enum SupersetLabels {
    /// Labels of exercises in order: "1.", "2." for single exercises and
    /// "3a", "3b" for exercises done together in a superset, like the web.
    /// `linked` tells for each exercise if it is in a superset with the previous one.
    static func labels(linked: [Bool]) -> [String] {
        let isLinked = linked.indices.map { $0 > 0 && linked[$0] }

        var numbers: [Int] = []
        var number = 0
        for index in linked.indices {
            if !isLinked[index] { number += 1 }
            numbers.append(number)
        }

        return linked.indices.map { index -> String in
            let startsSuperset = index + 1 < linked.count && isLinked[index + 1]
            guard isLinked[index] || startsSuperset else { return "\(numbers[index])." }

            // Letter by position in the superset: a, b, c...
            var first = index
            while isLinked[first] { first -= 1 }
            let letter = Character(UnicodeScalar(UInt8(97 + min(index - first, 25))))
            return "\(numbers[index])\(letter)"
        }
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

extension Training {
    /// Marks the training as completed or planned (staff only).
    /// Returns the training with the new state.
    @MainActor
    func settingCompletion(_ isCompleted: Bool) async throws -> Training {
        struct Request: Encodable { let isCompleted: Bool }
        struct Response: Decodable {
            let isCompleted: Bool
            let completedAt: Date?
        }

        let url = AppEnvironment.apiURL
            .appendingPathComponent("trainings")
            .appendingPathComponent(id.uuidString)
            .appendingPathComponent("completion")
        let response: Response = try await APIClient.shared.request(
            url,
            method: .put,
            body: JSONEncoder().encode(Request(isCompleted: isCompleted))
        )

        return Training(
            id: id, name: name, date: date, note: note,
            isCompleted: response.isCompleted, completedAt: response.completedAt,
            client: client, exercises: exercises
        )
    }

    /// Deletes the training (soft delete on the API, staff only).
    @MainActor
    static func delete(id: UUID) async throws {
        let url = AppEnvironment.apiURL
            .appendingPathComponent("trainings")
            .appendingPathComponent(id.uuidString)
        try await APIClient.shared.requestData(url, method: .delete)
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
        let isSupersetWithPrevious: Bool
    }

    struct ExerciseSet: Encodable {
        let reps: String?
        let weight: Decimal?
    }
}
