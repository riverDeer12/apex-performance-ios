//
//  TrainingActivityAttributes.swift
//  ApexPerformance
//
//  Shared with the TrainingActivity widget extension.
//

import ActivityKit
import Foundation

/// Live Activity of a training in progress on the coach's iPhone: on the
/// lock screen and in the Dynamic Island, with the time since its start.
/// Texts come from the app already translated to the app's language,
/// which the extension doesn't know.
struct TrainingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        // Set when the training ended; the activity then shows its duration.
        var endedAt: Date?
        // Nil while the new training isn't saved yet: the form starts the
        // activity when the name is written (iOS starts activities only in
        // the foreground) and links it to the training once it is saved.
        var trainingId: String?
        var trainingName: String
    }

    // Tells the activities apart, also before the training is saved.
    let key: String
    // Empty when the form doesn't know the client's name.
    let clientName: String
    // "Training in progress", "Training ended" and "End training".
    let inProgressText: String
    let endedText: String
    let endText: String
}
