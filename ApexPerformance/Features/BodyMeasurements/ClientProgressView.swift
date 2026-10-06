//
//  ClientProgressView.swift
//  ApexPerformance
//

import SwiftUI

/// Period the progress charts show.
enum ProgressPeriod: Int, CaseIterable, Identifiable {
    case oneMonth = 1
    case threeMonths = 3
    case sixMonths = 6
    case year = 12
    case all = 0

    var id: Int { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .oneMonth: return "period_one_month"
        case .threeMonths: return "period_three_months"
        case .sixMonths: return "period_six_months"
        case .year: return "period_year"
        case .all: return "period_all"
        }
    }

    func includes(_ date: Date) -> Bool {
        guard rawValue > 0,
              let start = Calendar.current.date(byAdding: .month, value: -rawValue, to: .now)
        else { return true }
        return date >= start
    }
}

/// Client's progress: body (weight and circumferences) and training
/// (charts from completed trainings), opened from home.
struct ClientProgressView: View {
    enum ProgressSection: Hashable {
        case body
        case training
    }

    @EnvironmentObject private var toastManager: ToastManager

    @State private var section: ProgressSection = .body
    @State private var period: ProgressPeriod = .sixMonths

    @State private var measurements: [BodyMeasurement] = []
    @State private var trainings: [Training] = []
    @State private var workouts: [Workout] = []
    @State private var isLoading = false
    @State private var hasLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom) {
                    ApexScreenHeader(title: "progress")

                    Menu {
                        Picker(selection: $period) {
                            ForEach(ProgressPeriod.allCases) { period in
                                Text(period.title).tag(period)
                            }
                        } label: {
                            EmptyView()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(period.title)
                            Image(systemName: "chevron.down")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("progress-period")
                }

                Picker(selection: $section) {
                    Text("body_progress").tag(ProgressSection.body)
                    Text("training_progress").tag(ProgressSection.training)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("progress-section")

                switch section {
                case .body:
                    BodyProgressView(measurements: measurements, period: period, isLoading: isLoading)
                case .training:
                    TrainingProgressView(trainings: trainings, workouts: workouts, period: period, isLoading: isLoading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.apexBackground)
        .refreshable {
            await Task { await load() }.value
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await load()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            measurements = try await BodyMeasurement.loadMine()
            trainings = try await Training.loadCompleted()
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }

        // Only used for muscle groups, so the charts work without it.
        if workouts.isEmpty {
            let url = AppEnvironment.apiURL.appendingPathComponent("workouts")
            if let loaded: [Workout] = try? await APIClient.shared.request(url) {
                workouts = loaded
            }
        }
    }
}

#Preview {
    NavigationStack {
        ClientProgressView()
            .environmentObject(ToastManager())
    }
}
