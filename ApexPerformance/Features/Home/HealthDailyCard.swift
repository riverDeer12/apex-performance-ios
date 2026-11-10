//
//  HealthDailyCard.swift
//  ApexPerformance
//

import SwiftUI

/// The client's day from Apple Health on home: sleep last night, steps,
/// latest resting heart rate and active energy today. Read on the iPhone
/// and shown only here; nothing is sent to the server.
struct HealthDailyCard: View {
    // Changes when home reloads (pull to refresh), the card reads Health again.
    var refreshID: UUID

    @State private var isConnected = AppleHealth.isDailyConnected
    @State private var summary: AppleHealth.DailySummary?
    @State private var isConnecting = false

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        if AppleHealth.isAvailable {
            VStack(alignment: .leading, spacing: 14) {
                header
                if isConnected {
                    values
                } else {
                    connect
                }
            }
            .padding(16)
            .apexCardBackground()
            .task(id: refreshID) {
                guard isConnected else { return }
                summary = await AppleHealth.dailySummary()
            }
        }
    }

    private var header: some View {
        Link(destination: URL(string: "x-apple-health://")!) {
            HStack(spacing: 14) {
                Image(systemName: "heart")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Color.apexAccent)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "Apple Health")
                        .apexSectionTitle()
                    Text("health_daily_subtitle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var values: some View {
        HStack(alignment: .top, spacing: 0) {
            tile(icon: "bed.double.fill", title: "health_sleep",
                 value: summary?.sleepMinutes.map(Self.sleepText) ?? "–", caption: "health_last_night")
            Divider()
            tile(icon: "shoeprints.fill", title: "health_steps",
                 value: summary?.steps.map { $0.formatted() } ?? "–", caption: "health_today")
            Divider()
            tile(icon: "heart.text.square", title: "health_resting_heart_rate",
                 value: summary?.restingHeartRate.map { "\($0) bpm" } ?? "–", caption: "health_latest")
        }
        .fixedSize(horizontal: false, vertical: true)

        Divider()

        HStack {
            Label {
                Text("health_active_energy")
            } icon: {
                Image(systemName: "flame")
                    .foregroundStyle(Color.apexAccent)
            }
            .font(.subheadline)
            Spacer()
            Text(verbatim: summary?.activeEnergyKilocalories.map { "\($0.formatted()) kcal" } ?? "–")
                .font(.title3.weight(.semibold))
        }

        if let summary {
            Text(summary.isEmpty
                 ? LocalizedStringKey("health_no_data")
                 : LocalizedStringKey("health_updated_at \(Self.timeFormatter.string(from: summary.updatedAt))"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var connect: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("health_daily_connect_hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                Task {
                    isConnecting = true
                    defer { isConnecting = false }
                    try? await AppleHealth.connectDaily()
                    isConnected = AppleHealth.isDailyConnected
                    if isConnected {
                        summary = await AppleHealth.dailySummary()
                    }
                }
            } label: {
                if isConnecting {
                    ProgressView()
                } else {
                    Text("health_connect")
                }
            }
            .buttonStyle(ApexPrimaryButtonStyle(systemImage: "heart.fill"))
            .disabled(isConnecting)
        }
    }

    private func tile(icon: String, title: LocalizedStringKey, value: String, caption: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(Color.apexAccent)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    // For example "7 h 42 min".
    private static func sleepText(_ minutes: Int) -> String {
        "\(minutes / 60) h \(minutes % 60) min"
    }
}
