//
//  TrainingActivityAttributes.swift
//  ApexPerformance
//
//  Shared with the TrainingActivity widget extension.
//

import ActivityKit
import Foundation

/// Live Activity of a training in progress: on the lock screen and in the
/// Dynamic Island, with the time since its start. Started by the coach's
/// iPhone that marks the times, or by the backend through push on the
/// client's and the coach's other iPhones (docs/LIVE_ACTIVITY_PUSH.md of
/// the backend, which encodes this JSON: dates as seconds since 2001-01-01,
/// the default of Swift's JSONEncoder/JSONDecoder that ActivityKit uses).
/// Texts come already translated to the app's language, which the
/// extension doesn't know.
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
    // False on the client's iPhone: clients can't end trainings. Nil (shown)
    // for activities the app starts itself and those of older versions.
    var showsEndButton: Bool?
}
