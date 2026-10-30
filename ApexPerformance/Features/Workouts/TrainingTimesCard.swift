//
//  TrainingTimesCard.swift
//  ApexPerformance
//

import SwiftUI

/// Start, end and the client's heart rate of a training. Staff mark the
/// start and end; the client's iPhone adds the heart rate from Apple Health.
struct TrainingTimesCard: View {
    @Binding var training: Training
    let isStaff: Bool
    var onChanged: ((Training) -> Void)? = nil

    @EnvironmentObject private var toastManager: ToastManager

    @State private var isSaving = false
    @State private var isReadingHealth = false
    @State private var hasNoMeasurements = false

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    // Clients see the card once the coach marked the training.
    private var isShown: Bool {
        isStaff || training.startedAt != nil || training.heartRate != nil
    }

    var body: some View {
        if isShown {
            CardView(title: "training_time") {
                VStack(alignment: .leading, spacing: 14) {
                    times
                    if isStaff {
                        staffButtons
                    }
                    heartRate
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var times: some View {
        if let start = training.startedAt {
            HStack(spacing: 0) {
                value("training_started", Self.timeFormatter.string(from: start))
                if let end = training.endedAt {
                    value("training_ended", Self.timeFormatter.string(from: end))
                    let minutes = Int((end.timeIntervalSince(start) / 60).rounded())
                    value("training_duration", String(localized: "duration_minutes \(minutes)"))
                } else {
                    Label("training_in_progress", systemImage: "timer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                }
            }
        } else if isStaff {
            Text("training_time_hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var staffButtons: some View {
        if training.startedAt == nil {
            Button {
                Task { await save(startedAt: .now, endedAt: nil) }
            } label: {
                Text("start_training")
            }
            .buttonStyle(ApexPrimaryButtonStyle(systemImage: "play.fill"))
            .disabled(isSaving)
        } else if training.endedAt == nil {
            Button {
                Task { await save(startedAt: training.startedAt, endedAt: .now) }
            } label: {
                Text("end_training")
            }
            .buttonStyle(ApexPrimaryButtonStyle(systemImage: "stop.fill"))
            .disabled(isSaving)
        }
        if training.startedAt != nil {
            Button(role: .destructive) {
                Task { await save(startedAt: nil, endedAt: nil) }
            } label: {
                Text("clear_training_times")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .disabled(isSaving)
        }
    }

    @ViewBuilder
    private var heartRate: some View {
        if let heartRate = training.heartRate {
            VStack(alignment: .leading, spacing: 8) {
                Label("heart_rate", systemImage: "heart.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                HStack(spacing: 0) {
                    value("heart_rate_min", "\(heartRate.min)", unit: "bpm")
                    value("heart_rate_average", "\(heartRate.average)", unit: "bpm")
                    value("heart_rate_max", "\(heartRate.max)", unit: "bpm")
                }
            }
        } else if training.endedAt != nil {
            if isStaff {
                Text("heart_rate_from_client_hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if AppleHealth.isAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    if hasNoMeasurements {
                        Text("no_heart_rate_measurements")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    Button {
                        Task { await readHealth() }
                    } label: {
                        if isReadingHealth {
                            ProgressView()
                        } else {
                            Text("read_heart_rate_apple_health")
                        }
                    }
                    .buttonStyle(ApexPrimaryButtonStyle(systemImage: "heart.fill"))
                    .disabled(isReadingHealth)
                    Text("apple_health_hint")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func value(_ title: LocalizedStringKey, _ text: String, unit: LocalizedStringKey? = nil) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(verbatim: text)
                    .font(.title3.weight(.semibold))
                if let unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private struct TimesRequest: Encodable {
        let startedAt: String?
        let endedAt: String?
    }

    private struct TimesResponse: Decodable {
        let startedAt: Date?
        let endedAt: Date?
        let heartRate: Training.HeartRate?
        // Ending a training also completes it.
        let isCompleted: Bool
        let completedAt: Date?
    }

    @MainActor
    private func save(startedAt: Date?, endedAt: Date?) async {
        isSaving = true
        defer { isSaving = false }

        let formatter = ISO8601DateFormatter()
        let request = TimesRequest(startedAt: startedAt.map(formatter.string(from:)),
                                   endedAt: endedAt.map(formatter.string(from:)))
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("trainings/\(training.id.uuidString)/times")
            let response: TimesResponse = try await APIClient.shared.request(
                url, method: .put, body: JSONEncoder().encode(request)
            )
            training.startedAt = response.startedAt
            training.endedAt = response.endedAt
            training.heartRate = response.heartRate
            training.isCompleted = response.isCompleted
            training.completedAt = response.completedAt
            onChanged?(training)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func readHealth() async {
        isReadingHealth = true
        defer { isReadingHealth = false }

        do {
            try await AppleHealth.connect()
            if let heartRate = try await AppleHealth.send(for: training) {
                training.heartRate = heartRate
                hasNoMeasurements = false
                onChanged?(training)
            } else {
                hasNoMeasurements = true
            }
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

extension Training {
    /// Icon of the status in lists: planned, in progress or completed.
    var statusIcon: String {
        isCompleted ? "checkmark.circle" : (isInProgress ? "timer" : "calendar")
    }

    var statusTint: Color {
        isCompleted ? .green : (isInProgress ? .blue : .orange)
    }
}
