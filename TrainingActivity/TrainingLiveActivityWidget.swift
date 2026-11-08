//
//  TrainingLiveActivityWidget.swift
//  TrainingActivity
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Training in progress on the lock screen and in the Dynamic Island:
/// training, client, the time since the start and an "End training"
/// button. An ended training shows its duration for a few minutes.
struct TrainingLiveActivityWidget: Widget {
    // The app's main blue (apexMainColor).
    static let accent = Color(red: 0.24, green: 0.58, blue: 0.88)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainingActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(verbatim: context.attributes.clientName)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "figure.strengthtraining.traditional")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Self.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: context.state)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: context.attributes.trainingName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        EndButton(context: context)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(Self.accent)
            } compactTrailing: {
                ElapsedText(state: context.state)
                    .font(.caption.monospacedDigit())
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(Self.accent)
            }
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<TrainingActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: context.state.endedAt == nil ? "timer" : "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(context.state.endedAt == nil ? TrainingLiveActivityWidget.accent : .green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: context.state.endedAt == nil
                         ? context.attributes.inProgressText
                         : context.attributes.endedText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .textCase(.uppercase)
                    Text(verbatim: context.attributes.clientName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(verbatim: context.attributes.trainingName)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                ElapsedText(state: context.state)
                    .font(.title.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
            }

            EndButton(context: context)
        }
        .padding(16)
    }
}

/// Time since the start, counting up; the duration once ended.
private struct ElapsedText: View {
    let state: TrainingActivityAttributes.ContentState

    var body: some View {
        if let endedAt = state.endedAt {
            Text(Duration.seconds(max(endedAt.timeIntervalSince(state.startedAt), 0)),
                 format: .time(pattern: .hourMinuteSecond))
        } else {
            Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false)
        }
    }
}

private struct EndButton: View {
    let context: ActivityViewContext<TrainingActivityAttributes>

    var body: some View {
        if context.state.endedAt == nil {
            Button(intent: EndTrainingIntent(trainingId: context.attributes.trainingId,
                                             startedAt: context.state.startedAt)) {
                Label {
                    Text(verbatim: context.attributes.endText)
                } icon: {
                    Image(systemName: "stop.fill")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(TrainingLiveActivityWidget.accent)
        }
    }
}
