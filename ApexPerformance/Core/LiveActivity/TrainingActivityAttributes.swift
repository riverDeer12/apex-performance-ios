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
    }

    let trainingId: String
    let trainingName: String
    let clientName: String
    // "Training in progress", "Training ended" and "End training".
    let inProgressText: String
    let endedText: String
    let endText: String
}
