//
//  EndTrainingIntent.swift
//  ApexPerformance
//
//  Shared with the TrainingActivity widget extension: the extension shows
//  the button, iOS runs the intent in the app.
//

import AppIntents
import Foundation

/// "End training" button of the training's Live Activity.
struct EndTrainingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "end_training"
    static var isDiscoverable = false

    @Parameter(title: "trainings")
    var trainingId: String

    @Parameter(title: "training_started")
    var startedAt: Date

    init() {}

    init(trainingId: String, startedAt: Date) {
        self.trainingId = trainingId
        self.startedAt = startedAt
    }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        if let id = UUID(uuidString: trainingId) {
            try await Training.endFromLiveActivity(id: id, startedAt: startedAt)
        }
        #endif
        return .result()
    }
}
