//
//  TrainingLiveActivity.swift
//  ApexPerformance
//

import ActivityKit
import FirebaseCrashlytics
import SwiftUI
import UIKit

/// Starts, updates and ends the Live Activity of a training in progress
/// on the coach's iPhone that marks the times. The backend starts, updates
/// and ends it by push on the client's and the coach's other iPhones
/// (`LiveActivityPushService` registers the tokens for that).
///
/// iOS starts an activity only while the app is in the foreground, so the
/// new training form starts a draft one as soon as the name is written and
/// links it to the training once it is saved and started, also from the
/// background (locked phone), where only updates are allowed: the draft is
/// updated, never ended and started again.
///
/// Trainings started on this iPhone are remembered until they end
/// (`LiveActivityLogic.LocalRun`): when their activity went away, it is
/// started again the next time the app is in the foreground (`reconcile`).
@MainActor
enum TrainingLiveActivity {
    private typealias TrainingActivity = Activity<TrainingActivityAttributes>
    private typealias State = TrainingActivityAttributes.ContentState

    /// Live Activities are allowed for the app (Settings › Apex › Live Activities).
    static var areEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - New training form

    /// Starts the activity of a new training that isn't saved yet; returns
    /// its key for the calls below, nil when activities are off.
    static func startDraft(name: String, clientName: String, startedAt: Date) -> String? {
        let key = UUID().uuidString
        let state = State(startedAt: startedAt, endedAt: nil, trainingId: nil, trainingName: name)
        return request(key: key, clientName: clientName, state: state) ? key : nil
    }

    /// Starts the draft of a running new training again when its activity
    /// went away (or never started, e.g. Live Activities were off): only in
    /// the foreground. Returns the key to use from now on; the old key leads
    /// to the new draft, also for a save already on its way.
    static func restartDraftIfNeeded(_ key: String?, isRunning: Bool, name: String, clientName: String,
                                     startedAt: Date) -> String? {
        guard LiveActivityLogic.draftNeedsRestart(key: key.map(resolve), isRunning: isRunning, shownKeys: shownKeys,
                                                  isForeground: isForeground, activitiesEnabled: areEnabled)
        else { return key.map(resolve) }
        Crashlytics.crashlytics().log("Live Activity draft started again")
        guard let new = startDraft(name: name, clientName: clientName, startedAt: startedAt) else { return key }
        if let key {
            replacements[resolve(key)] = new
            TrainingSaveQueue.shared.replaceActivityKey(key, with: new)
        }
        return new
    }

    /// Keys of the activities on the lock screen.
    static var shownKeys: Set<String> {
        Set(TrainingActivity.activities.filter(isShown).map(\.attributes.key))
    }

    /// The name changes while the coach writes it.
    static func renameDraft(_ key: String, name: String) {
        for activity in activities(key: resolve(key)) where activity.content.state.trainingName != name {
            var state = activity.content.state
            state.trainingName = name
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        }
    }

    /// Links the draft to the saved, started training, so its button can end
    /// it and later changes find it. Only updates the activity (allowed in the
    /// background, e.g. when locking the phone saved the training).
    /// Awaited, so changes right after find the linked activity instead of
    /// starting another one.
    static func link(_ key: String, to training: Training) async {
        let key = resolve(key)
        let id = training.id.uuidString
        linkedIds[key] = id
        touch(training.id)
        let drafts = activities(key: key)
        if training.isRunning {
            remember(training, clientName: drafts.first?.attributes.clientName ?? clientName(of: training))
        }
        for activity in drafts {
            var state = activity.content.state
            state.trainingId = id
            state.trainingName = training.name
            if let startedAt = training.startedAt { state.startedAt = startedAt }
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        if drafts.isEmpty && training.isRunning {
            // The draft went away: started again now (foreground) or when
            // the app is opened next (reconcile).
            Crashlytics.crashlytics().log("Live Activity draft gone when linking training \(id)")
            update(for: training)
        }
        // Its push token now belongs to the training on the backend.
        LiveActivityPushService.shared.activitiesChanged()
    }

    /// The form closed without saving, or the training is planned after all.
    static func endDraft(_ key: String) {
        end(activities(key: resolve(key)), final: nil)
    }

    // MARK: - Saved trainings

    /// Shows the training while it runs (started, not ended) and ends the
    /// activity once it ended or its times were cleared.
    static func update(for training: Training) {
        touch(training.id)
        let existing = activities(of: training.id)

        guard let startedAt = training.startedAt, training.isRunning else {
            forget(training.id.uuidString)
            let final = training.startedAt.map {
                State(startedAt: $0, endedAt: training.endedAt, trainingId: training.id.uuidString,
                      trainingName: training.name)
            }
            end(existing, final: training.endedAt == nil ? nil : final)
            return
        }

        let shown = existing.filter(isShown)
        let client = shown.first?.attributes.clientName ?? clientName(of: training)
        remember(training, clientName: client)
        let state = State(startedAt: startedAt, endedAt: nil, trainingId: training.id.uuidString,
                          trainingName: training.name)
        if shown.isEmpty {
            // iOS starts activities only in the foreground; in the background
            // it is started when the app is opened next (reconcile).
            guard isForeground else {
                Crashlytics.crashlytics().log("Live Activity of training \(training.id) waits for the foreground")
                return
            }
            _ = request(key: training.id.uuidString, clientName: client, state: state)
        } else {
            for activity in shown {
                Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            }
        }
    }

    /// Ends the activity after the training was ended from its button.
    static func ended(_ id: UUID, startedAt: Date, endedAt: Date) {
        touch(id)
        forget(id.uuidString)
        let existing = activities(of: id)
        let name = existing.first?.content.state.trainingName ?? ""
        end(existing, final: State(startedAt: startedAt, endedAt: endedAt, trainingId: id.uuidString, trainingName: name))
    }

    /// Ends activities of trainings that are no longer running, e.g.
    /// ended on another device or on the web, and starts again those of
    /// running trainings started here that went away.
    /// `fetchedAt`: when the list was asked for; what this iPhone changed
    /// after that is newer than the list (e.g. the training was just
    /// started here and the list still has it without a start).
    static func sync(with trainings: [Training], fetchedAt: Date) {
        let byId = Dictionary(trainings.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { first, _ in first })
        for activity in TrainingActivity.activities {
            guard let id = trainingId(of: activity), let training = byId[id], !training.isRunning,
                  LiveActivityLogic.mayEnd(fetchedAt: fetchedAt, lastLocalChange: lastLocalChange[id]) else { continue }
            update(for: training)
        }
        // Ended, deleted or long over: not started again.
        for run in localRuns where byId[run.trainingId]?.isRunning != true || run.isOutdated(at: fetchedAt) {
            guard LiveActivityLogic.mayEnd(fetchedAt: fetchedAt, lastLocalChange: lastLocalChange[run.trainingId])
            else { continue }
            forget(run.trainingId)
        }
        reconcile(runningOnServer: Set(trainings.filter(\.isRunning).map(\.id.uuidString)))
    }

    /// Starts the activity of a running training started on this iPhone
    /// when it has none (its training form appeared). Foreground only.
    static func reconcile(_ training: Training) {
        guard training.isRunning else { return }
        reconcile(runningOnServer: [training.id.uuidString])
    }

    /// Whether any training is shown or runs from this iPhone, so the app
    /// can check it is still running (and its activity still shown).
    static var hasActivities: Bool {
        !TrainingActivity.activities.isEmpty || !localRuns.isEmpty
    }

    /// On logout nothing of the coach's trainings stays on the lock screen.
    static func endAll() {
        localRuns = []
        end(TrainingActivity.activities, final: nil)
    }

    // MARK: - Duplicates (LiveActivityPushService)

    /// Ends the other activities of trainings that have two on this iPhone
    /// (a push start crossed the training being started here); returns the
    /// ids of the ended ones.
    @discardableResult
    static func endDuplicates() -> [String] {
        let shown = TrainingActivity.activities.filter(isShown)
        let ids = Set(LiveActivityLogic.duplicates(shown.map(describe)))
        let duplicates = shown.filter { ids.contains($0.id) }
        for activity in duplicates {
            Crashlytics.crashlytics().log("Live Activity duplicate of training \(trainingId(of: activity) ?? "-") ended")
        }
        end(duplicates, final: nil)
        return duplicates.map(\.id)
    }

    /// The activity of each training on this iPhone: training id -> activity id.
    static func survivors() -> [String: String] {
        LiveActivityLogic.survivors(TrainingActivity.activities.filter(isShown).map(describe))
    }

    // MARK: - Diagnostics

    /// An activity ended or was dismissed. When the app didn't end it, the
    /// reason goes to Crashlytics (non-fatal), so real causes can be seen.
    /// One the coach removed from the lock screen isn't started again.
    static func stateChanged(_ activity: Activity<TrainingActivityAttributes>, to state: ActivityState) {
        guard state == .ended || state == .dismissed, !expectedEnds.contains(activity.id) else { return }
        // Ended by the backend's push after the training ended elsewhere.
        if activity.content.state.endedAt != nil { return }
        let id = trainingId(of: activity)
        if state == .dismissed, let id {
            var runs = localRuns
            if let index = runs.firstIndex(where: { $0.trainingId == id }) {
                runs[index].dismissedByUser = true
                localRuns = runs
            }
        }
        report("unexpected_end", code: 2, info: [
            "state": String(describing: state),
            "trainingId": id ?? "draft",
            "byPush": activity.attributes.showsEndButton != nil,
            "appState": appStateName
        ])
    }

    // MARK: - Private

    // Drafts linked in this run (key -> training id): found also before
    // ActivityKit reports the updated content.
    private static var linkedIds: [String: String] = [:]
    // Drafts started again: old key -> new key.
    private static var replacements: [String: String] = [:]
    // When this iPhone last changed a training's times (training id).
    private static var lastLocalChange: [String: Date] = [:]
    // Activities the app ends itself.
    private static var expectedEnds: Set<String> = []

    private static let localRunsKey = "liveActivityLocalRuns"

    private static var localRuns: [LiveActivityLogic.LocalRun] {
        get {
            guard let data = UserDefaults.standard.data(forKey: localRunsKey) else { return [] }
            return (try? JSONDecoder().decode([LiveActivityLogic.LocalRun].self, from: data)) ?? []
        }
        set {
            if newValue.isEmpty {
                UserDefaults.standard.removeObject(forKey: localRunsKey)
            } else if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: localRunsKey)
            }
        }
    }

    private static func remember(_ training: Training, clientName: String) {
        guard let startedAt = training.startedAt else { return }
        var runs = localRuns
        let id = training.id.uuidString
        if let index = runs.firstIndex(where: { $0.trainingId == id }) {
            // Started again (a new start): shown again.
            if runs[index].startedAt != startedAt { runs[index].dismissedByUser = false }
            runs[index].startedAt = startedAt
            runs[index].name = training.name
        } else {
            runs.append(LiveActivityLogic.LocalRun(trainingId: id, startedAt: startedAt, name: training.name,
                                                   clientName: clientName, userId: currentUserId))
        }
        localRuns = runs
    }

    private static func forget(_ trainingId: String) {
        let runs = localRuns
        guard runs.contains(where: { $0.trainingId == trainingId }) else { return }
        localRuns = runs.filter { $0.trainingId != trainingId }
    }

    private static func resolve(_ key: String) -> String {
        var key = key
        var seen: Set<String> = [key]
        while let next = replacements[key], seen.insert(next).inserted { key = next }
        return key
    }

    private static func touch(_ id: UUID) {
        lastLocalChange[id.uuidString] = .now
    }

    private static func reconcile(runningOnServer: Set<String>) {
        let runs = LiveActivityLogic.toStart(
            runs: localRuns, runningOnServer: runningOnServer,
            shown: TrainingActivity.activities.filter(isShown).map(describe),
            userId: currentUserId, isForeground: isForeground, activitiesEnabled: areEnabled)
        for run in runs {
            Crashlytics.crashlytics().log("Live Activity of training \(run.trainingId) started again")
            let state = State(startedAt: run.startedAt, endedAt: nil, trainingId: run.trainingId, trainingName: run.name)
            _ = request(key: run.trainingId, clientName: run.clientName, state: state)
        }
        if !runs.isEmpty {
            LiveActivityPushService.shared.activitiesChanged()
        }
    }

    private static var currentUserId: String? {
        KeychainService.shared.getToken().flatMap { JWTDecoder.getUserId(token: $0) }?.uuidString
    }

    private static var isForeground: Bool {
        UIApplication.shared.applicationState == .active
    }

    private static var appStateName: String {
        switch UIApplication.shared.applicationState {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown"
        }
    }

    private static func isShown(_ activity: TrainingActivity) -> Bool {
        activity.activityState == .active || activity.activityState == .stale
    }

    private static func trainingId(of activity: TrainingActivity) -> String? {
        activity.content.state.trainingId ?? linkedIds[activity.attributes.key]
    }

    private static func describe(_ activity: TrainingActivity) -> LiveActivityLogic.Shown {
        LiveActivityLogic.Shown(id: activity.id, trainingId: trainingId(of: activity),
                                startedByApp: activity.attributes.showsEndButton == nil)
    }

    private static func activities(of id: UUID) -> [TrainingActivity] {
        TrainingActivity.activities.filter { trainingId(of: $0) == id.uuidString }
    }

    private static func activities(key: String) -> [TrainingActivity] {
        TrainingActivity.activities.filter { $0.attributes.key == key && isShown($0) }
    }

    private static func clientName(of training: Training) -> String {
        [training.client.firstName, training.client.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private static func request(key: String, clientName: String, state: State) -> Bool {
        guard areEnabled else {
            Crashlytics.crashlytics().log("Live Activity not started: turned off for the app")
            return false
        }

        let attributes = TrainingActivityAttributes(
            key: key,
            clientName: clientName,
            inProgressText: String(localized: "training_in_progress"),
            endedText: String(localized: "training_ended"),
            endText: String(localized: "end_training")
        )

        let content = ActivityContent(state: state, staleDate: nil)
        do {
            // With a push token, so the backend can end it when the training
            // ends on the web or on another device.
            _ = try TrainingActivity.request(attributes: attributes, content: content, pushType: .token)
            return true
        } catch {
            reportRequestFailure(error, withPush: true, trainingId: state.trainingId)
        }
        do {
            _ = try TrainingActivity.request(attributes: attributes, content: content)
            return true
        } catch {
            reportRequestFailure(error, withPush: false, trainingId: state.trainingId)
            return false
        }
    }

    private static func reportRequestFailure(_ error: Error, withPush: Bool, trainingId: String?) {
        let reason = (error as? ActivityAuthorizationError).map { String(describing: $0) } ?? String(describing: error)
        report("request_failed", code: 1, info: [
            "reason": reason,
            "withPush": withPush,
            "trainingId": trainingId ?? "draft",
            "appState": appStateName,
            "enabled": areEnabled
        ])
    }

    /// A Crashlytics non-fatal with the reason (Crashlytics is off in Debug).
    private static func report(_ what: String, code: Int, info: [String: Any]) {
        let description = "Live Activity \(what): " +
            info.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        var userInfo = info
        userInfo[NSLocalizedDescriptionKey] = description
        print(description)
        Crashlytics.crashlytics().record(error: NSError(domain: "LiveActivity.\(what)", code: code, userInfo: userInfo))
    }

    // An ended training stays visible for a few minutes with its duration;
    // cleared times remove it right away.
    private static func end(_ activities: [TrainingActivity], final: State?) {
        for activity in activities {
            expectedEnds.insert(activity.id)
            Task {
                await activity.end(
                    final.map { ActivityContent(state: $0, staleDate: nil) },
                    dismissalPolicy: final == nil ? .immediate : .after(.now + 15 * 60)
                )
            }
        }
    }
}

extension Training {
    /// Started, not ended and not completed: shown on the lock screen.
    var isRunning: Bool {
        startedAt != nil && endedAt == nil && !isCompleted
    }
}
