//
//  LiveActivityLogic.swift
//  ApexPerformance
//

import Foundation

/// The decisions about training Live Activities, without ActivityKit, so
/// they can be unit tested: which of two activities of the same training
/// stays, whether a list of trainings from the server may end an activity,
/// and which running trainings need their activity started again.
enum LiveActivityLogic {

    /// An activity on the lock screen (active or stale).
    struct Shown: Equatable {
        let id: String
        // Nil while it is the draft of a training that isn't saved yet.
        let trainingId: String?
        // Started by the app itself (no `showsEndButton`), not by push.
        let startedByApp: Bool
    }

    /// A training started on this iPhone, kept until it ends, so its activity
    /// can be started again when it went away (e.g. ended by iOS while the
    /// phone was locked).
    struct LocalRun: Codable, Equatable {
        let trainingId: String
        var startedAt: Date
        var name: String
        var clientName: String
        // The coach who started it; others' trainings are never shown.
        var userId: String?
        // The coach removed it from the lock screen: not shown again.
        var dismissedByUser = false

        /// iOS shows an activity for at most 12 hours: an older training
        /// was forgotten to be ended and isn't shown again.
        func isOutdated(at date: Date) -> Bool {
            date.timeIntervalSince(startedAt) > 12 * 60 * 60
        }
    }

    // MARK: - Duplicates

    /// The activity that stays for each training. A push start can cross
    /// the training being started here: the one the app started itself
    /// stays, otherwise the first one.
    static func survivors(_ shown: [Shown]) -> [String: String] {
        var result: [String: Shown] = [:]
        for activity in shown {
            guard let trainingId = activity.trainingId else { continue }
            if let kept = result[trainingId], kept.startedByApp || !activity.startedByApp {
                continue
            }
            result[trainingId] = activity
        }
        return result.mapValues(\.id)
    }

    /// The activities to end: the others of a training that has two. Drafts
    /// (not linked to a training yet) are never ended here.
    static func duplicates(_ shown: [Shown]) -> [String] {
        let kept = survivors(shown)
        return shown.compactMap { activity in
            guard let trainingId = activity.trainingId, let survivor = kept[trainingId],
                  survivor != activity.id else { return nil }
            return activity.id
        }
    }

    // MARK: - Sync with the server

    /// Whether a training the server says isn't running may end its activity.
    /// Not when this iPhone changed the training after the list was asked
    /// for: e.g. it was just started here (saved when the phone was locked)
    /// and the list still has it without a start.
    static func mayEnd(fetchedAt: Date, lastLocalChange: Date?) -> Bool {
        guard let lastLocalChange else { return true }
        return lastLocalChange < fetchedAt
    }

    // MARK: - Reconcile

    /// Running trainings started on this iPhone by this coach that have no
    /// activity (it never started, or went away while the phone was locked):
    /// started again, only while the app is in the foreground (iOS allows it
    /// only then) and only for trainings the server confirmed are running.
    static func toStart(runs: [LocalRun], runningOnServer: Set<String>, shown: [Shown], userId: String?,
                        isForeground: Bool, activitiesEnabled: Bool, now: Date = .now) -> [LocalRun] {
        guard isForeground, activitiesEnabled else { return [] }
        let shownIds = Set(shown.compactMap(\.trainingId))
        return runs.filter { run in
            !run.dismissedByUser && !run.isOutdated(at: now) && run.userId == userId && runningOnServer.contains(run.trainingId) &&
                !shownIds.contains(run.trainingId)
        }
    }

    /// Whether the draft activity of a training form (not saved yet) has to be
    /// started again: the form runs the training, but its activity is gone.
    static func draftNeedsRestart(key: String?, isRunning: Bool, shownKeys: Set<String>, isForeground: Bool,
                                  activitiesEnabled: Bool) -> Bool {
        guard isRunning, isForeground, activitiesEnabled else { return false }
        guard let key else { return true }
        return !shownKeys.contains(key)
    }
}
