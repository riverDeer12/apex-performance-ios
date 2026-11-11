//
//  TrainingLiveActivity.swift
//  ApexPerformance
//

import ActivityKit
import SwiftUI

/// Starts, updates and ends the Live Activity of a training in progress
/// on the coach's iPhone that marks the times. The backend starts, updates
/// and ends it by push on the client's and the coach's other iPhones
/// (`LiveActivityPushService` registers the tokens for that).
///
/// iOS starts an activity only while the app is in the foreground, so the
/// new training form starts a draft one as soon as the name is written and
/// links it to the training when it is saved, also from the background
/// (locked phone), where only updates are allowed.
@MainActor
enum TrainingLiveActivity {
    private typealias TrainingActivity = Activity<TrainingActivityAttributes>
    private typealias State = TrainingActivityAttributes.ContentState

    // MARK: - New training form

    /// Starts the activity of a new training that isn't saved yet; returns
    /// its key for the calls below, nil when activities are off.
    static func startDraft(name: String, clientName: String, startedAt: Date) -> String? {
        let key = UUID().uuidString
        let state = State(startedAt: startedAt, endedAt: nil, trainingId: nil, trainingName: name)
        return request(key: key, clientName: clientName, state: state) ? key : nil
    }

    /// The name changes while the coach writes it.
    static func renameDraft(_ key: String, name: String) {
        for activity in activities(key: key) where activity.content.state.trainingName != name {
            var state = activity.content.state
            state.trainingName = name
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        }
    }

    /// Links the draft to the saved training, so its button can end it and
    /// later changes find it.
    /// Awaited, so saving the times right after finds the linked activity
    /// instead of starting another one.
    static func link(_ key: String, to training: Training) async {
        for activity in activities(key: key) {
            var state = activity.content.state
            state.trainingId = training.id.uuidString
            state.trainingName = training.name
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        // Its push token now belongs to the training on the backend.
        LiveActivityPushService.shared.activitiesChanged()
    }

    /// The form closed without saving, or the training is planned after all.
    static func endDraft(_ key: String) {
        end(activities(key: key), final: nil)
    }

    // MARK: - Saved trainings

    /// Shows the training while it runs (started, not ended) and ends the
    /// activity once it ended or its times were cleared.
    static func update(for training: Training) {
        let existing = activities(of: training.id)

        guard let startedAt = training.startedAt, training.endedAt == nil, !training.isCompleted else {
            let final = training.startedAt.map {
                State(startedAt: $0, endedAt: training.endedAt, trainingId: training.id.uuidString,
                      trainingName: training.name)
            }
            end(existing, final: training.endedAt == nil ? nil : final)
            return
        }

        let state = State(startedAt: startedAt, endedAt: nil, trainingId: training.id.uuidString,
                          trainingName: training.name)
        if existing.isEmpty {
            _ = request(key: training.id.uuidString, clientName: clientName(of: training), state: state)
        } else {
            for activity in existing {
                Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            }
        }
    }

    /// Ends the activity after the training was ended from its button.
    static func ended(_ id: UUID, startedAt: Date, endedAt: Date) {
        let existing = activities(of: id)
        let name = existing.first?.content.state.trainingName ?? ""
        end(existing, final: State(startedAt: startedAt, endedAt: endedAt, trainingId: id.uuidString, trainingName: name))
    }

    /// Ends activities of trainings that are no longer running, e.g.
    /// ended on another device or on the web.
    static func sync(with trainings: [Training]) {
        for activity in TrainingActivity.activities {
            guard let id = activity.content.state.trainingId,
                  let training = trainings.first(where: { $0.id.uuidString == id }) else { continue }
            if training.startedAt == nil || training.endedAt != nil || training.isCompleted {
                update(for: training)
            }
        }
    }

    /// Whether any training is shown, so the app can check it is still running.
    static var hasActivities: Bool {
        !TrainingActivity.activities.isEmpty
    }

    /// On logout nothing of the coach's trainings stays on the lock screen.
    static func endAll() {
        end(TrainingActivity.activities, final: nil)
    }

    // MARK: - Private

    private static func activities(of id: UUID) -> [TrainingActivity] {
        TrainingActivity.activities.filter { $0.content.state.trainingId == id.uuidString }
    }

    private static func activities(key: String) -> [TrainingActivity] {
        TrainingActivity.activities.filter { $0.attributes.key == key }
    }

    private static func clientName(of training: Training) -> String {
        [training.client.firstName, training.client.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private static func request(key: String, clientName: String, state: State) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }

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
            print("Live Activity with push not started: \(error)")
        }
        do {
            _ = try TrainingActivity.request(attributes: attributes, content: content)
            return true
        } catch {
            print("Live Activity not started: \(error)")
            return false
        }
    }

    // An ended training stays visible for a few minutes with its duration;
    // cleared times remove it right away.
    private static func end(_ activities: [TrainingActivity], final: State?) {
        for activity in activities {
            Task {
                await activity.end(
                    final.map { ActivityContent(state: $0, staleDate: nil) },
                    dismissalPolicy: final == nil ? .immediate : .after(.now + 15 * 60)
                )
            }
        }
    }
}
