//
//  Workout.swift
//  ApexPerformance
//

import Foundation

struct Workout: Identifiable, Decodable, Hashable {
    let id: UUID
    let name: LocalizedText
    let description: LocalizedText
    let thumbnailUrl: String?
    let videoUrl: String?
    let workoutTypes: [WorkoutType]
    // Codes of the muscles it works (WorkoutMuscle): primary ones doing most
    // of the work and secondary ones helping. Nil from an API without them.
    let muscles: [String]?
    var secondaryMuscles: [String]? = nil
    // Done for a time (e.g. plank): sets record a duration instead of repetitions.
    var isTimed: Bool? = nil

    // Every translation is searched, so the query language does not matter.
    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let searchableValues = name.allValues
            + description.allValues
            + workoutTypes.flatMap { $0.name.allValues }

        return searchableValues.contains { $0.localizedStandardContains(query) }
    }
}

struct WorkoutType: Identifiable, Decodable, Hashable {
    let id: UUID
    let name: LocalizedText
}

struct ImportWorkoutsResponse: Decodable {
    let id: UUID
    let status: Bool
    let queuedWorkoutsCount: Int
}

struct UpdateWorkoutRequest: Encodable {
    let name: LocalizedText
    let description: LocalizedText
    let thumbnailUrl: String
    let videoUrl: String
    let workoutTypes: [UUID]
    // Nil for a new workout lets the API guess them from the name.
    let muscles: [String]?
    let secondaryMuscles: [String]?
    let isTimed: Bool
}

/// POST workouts/guess-muscles: muscles guessed from the name, with the
/// whole body ones when a type is for the full body.
struct GuessMusclesRequest: Encodable {
    let name: LocalizedText
    let workoutTypes: [UUID]
}

struct GuessMusclesResponse: Decodable {
    let isFullBody: Bool
    let muscles: [String]
    let secondaryMuscles: [String]
}

/// Mirrors the API's LocalizedProperty, translations keyed by language code (HR, EN, IT).
struct LocalizedText: Codable, Hashable {
    var translations: [String: String]

    init(translations: [String: String]) {
        self.translations = translations
    }

    private struct TranslationsObject: Codable {
        let translations: [String: String]?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let object = try? container.decode(TranslationsObject.self) {
            translations = object.translations ?? [:]
        } else if let string = try? container.decode(String.self) {
            // Workout types nested in a workout come back as the persisted JSON string.
            if let data = string.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
                translations = decoded
            } else {
                translations = ["HR": string]
            }
        } else {
            translations = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(TranslationsObject(translations: translations))
    }

    func value(for languageCode: String) -> String? {
        translations.first { $0.key.uppercased() == languageCode.uppercased() && !$0.value.isEmpty }?.value
    }

    // Uses the same localization iOS picked for the app's own strings.
    var localized: String {
        value(for: AppLanguage.current)
            ?? value(for: "HR")
            ?? translations.values.first { !$0.isEmpty }
            ?? ""
    }

    var allValues: [String] {
        Array(translations.values)
    }
}

extension Workout {
    /// One workout, e.g. of an exercise in a training. Clients also
    /// get the workouts of their trainings outside their plan.
    @MainActor
    static func load(id: UUID) async throws -> Workout {
        let url = AppEnvironment.apiURL
            .appendingPathComponent("workouts")
            .appendingPathComponent(id.uuidString)
        return try await APIClient.shared.request(url)
    }

    /// Deletes the workout (soft delete on the API, staff only).
    @MainActor
    static func delete(id: UUID) async throws {
        let url = AppEnvironment.apiURL
            .appendingPathComponent("workouts")
            .appendingPathComponent(id.uuidString)
        try await APIClient.shared.requestData(url, method: .delete)
    }
}
