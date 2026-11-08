//
//  TrainingLiveActivity.swift
//  ApexPerformance
//

import ActivityKit
import SwiftUI

/// Starts, updates and ends the Live Activity of a training in progress.
/// Only the coach's iPhone that marks the times shows it.
@MainActor
enum TrainingLiveActivity {
    private typealias TrainingActivity = Activity<TrainingActivityAttributes>

    /// Shows the training while it runs (started, not ended) and ends the
    /// activity once it ended or its times were cleared.
    static func update(for training: Training) {
        let existing = activities(of: training.id)

        guard let startedAt = training.startedAt, training.endedAt == nil, !training.isCompleted else {
            let final = training.startedAt.map {
                TrainingActivityAttributes.ContentState(startedAt: $0, endedAt: training.endedAt)
            }
            end(existing, final: training.endedAt == nil ? nil : final)
            return
        }

        let state = TrainingActivityAttributes.ContentState(startedAt: startedAt, endedAt: nil)
        if existing.isEmpty {
            start(training, state: state)
        } else {
            for activity in existing {
                Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            }
        }
    }

    /// Ends the activity after the training was ended from its button.
    static func ended(_ id: UUID, startedAt: Date, endedAt: Date) {
        end(activities(of: id), final: .init(startedAt: startedAt, endedAt: endedAt))
    }

    /// Ends activities of trainings that are no longer running, e.g.
    /// ended on another device or on the web.
    static func sync(with trainings: [Training]) {
        for activity in TrainingActivity.activities {
            guard let training = trainings.first(where: { $0.id.uuidString == activity.attributes.trainingId }) else {
                continue
            }
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
        TrainingActivity.activities.filter { $0.attributes.trainingId == id.uuidString }
    }

    private static func start(_ training: Training, state: TrainingActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let clientName = [training.client.firstName, training.client.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
        let attributes = TrainingActivityAttributes(
            trainingId: training.id.uuidString,
            trainingName: training.name,
            clientName: clientName,
            inProgressText: String(localized: "training_in_progress"),
            endedText: String(localized: "training_ended"),
            endText: String(localized: "end_training")
        )

        do {
            _ = try TrainingActivity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
        } catch {
            print("Live Activity not started: \(error)")
        }
    }

    // An ended training stays visible for a few minutes with its duration;
    // cleared times remove it right away.
    private static func end(_ activities: [TrainingActivity], final: TrainingActivityAttributes.ContentState?) {
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
