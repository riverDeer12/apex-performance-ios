//
//  TrainingTemplate.swift
//  ApexPerformance
//

import Foundation

/// Training prepared once and reused (staff only). Coaches see and change
/// their own templates, administrators the templates of all coaches.
struct TrainingTemplate: Identifiable, Decodable, Hashable {
    let id: UUID
    let name: String
    let note: String?
    // Same exercises and sets as a training's.
    let exercises: [Training.Exercise]
    let authorName: String?
    let canEdit: Bool
    let createdAt: Date
    let updatedAt: Date
}

extension TrainingTemplate {
    /// Templates the logged coach or administrator can see, by name.
    @MainActor
    static func loadAll() async throws -> [TrainingTemplate] {
        let templates: [TrainingTemplate] = try await APIClient.shared.request(baseURL)
        return templates.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Creates a template, or updates it when an id is given.
    @MainActor
    static func save(_ request: SaveTrainingTemplateRequest, id: UUID? = nil) async throws -> TrainingTemplate {
        var url = baseURL
        if let id {
            url = url.appendingPathComponent(id.uuidString)
        }
        return try await APIClient.shared.request(
            url,
            method: id == nil ? .post : .put,
            body: JSONEncoder().encode(request)
        )
    }

    /// Deletes the template (soft delete on the API).
    @MainActor
    static func delete(id: UUID) async throws {
        try await APIClient.shared.requestData(baseURL.appendingPathComponent(id.uuidString), method: .delete)
    }

    /// Creates a planned training from the template for each client.
    /// Returns how many trainings were created.
    @MainActor
    func assign(to clients: [UUID], date: Date) async throws -> Int {
        struct Request: Encodable {
            let clients: [UUID]
            // ISO 8601, as the API expects a DateTimeOffset.
            let date: String
        }
        struct Response: Decodable {
            let trainingIds: [UUID]
        }

        let url = Self.baseURL
            .appendingPathComponent(id.uuidString)
            .appendingPathComponent("assign")
        let response: Response = try await APIClient.shared.request(
            url,
            method: .post,
            body: JSONEncoder().encode(Request(clients: clients, date: ISO8601DateFormatter().string(from: date)))
        )
        return response.trainingIds.count
    }

    private static var baseURL: URL {
        AppEnvironment.apiURL.appendingPathComponent("training-templates")
    }
}

/// Body of POST training-templates and PUT training-templates/{id}.
struct SaveTrainingTemplateRequest: Encodable {
    let name: String
    let note: String?
    let exercises: [SaveTrainingRequest.Exercise]
}

extension SaveTrainingTemplateRequest {
    /// Template with the exercises and sets of a training ("Save as template").
    init(name: String, training: Training) {
        self.name = name
        note = training.note
        exercises = training.exercises
            .sorted { $0.order < $1.order }
            .map { exercise in
                SaveTrainingRequest.Exercise(
                    workout: exercise.workoutId,
                    note: exercise.note,
                    sets: exercise.sets
                        .sorted { $0.order < $1.order }
                        .map { SaveTrainingRequest.ExerciseSet(reps: $0.reps, weight: $0.weight) },
                    isSupersetWithPrevious: exercise.isSupersetWithPrevious
                )
            }
    }
}
