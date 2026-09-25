//
//  MyBodyMeasurementsView.swift
//  ApexPerformance
//

import SwiftUI

struct MyBodyMeasurementsView: View {

    @State private var measurements: [BodyMeasurement] = []
    @State private var isLoading = false
    @State private var hasLoaded = false

    @EnvironmentObject private var toastManager: ToastManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text("body_measurements")
                            .font(.title.bold())
                        Text("my_measurements_subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    if let latest = measurements.first {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("latest_measurement")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)

                            HStack(spacing: 12) {
                                StatTileView(value: formatted(latest.weight, unit: "kg"), label: "weight")
                                StatTileView(value: formatted(latest.waist, unit: "cm"), label: "waist")
                                StatTileView(value: formatted(latest.chest, unit: "cm"), label: "chest")
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("measurement_history")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)

                        CardView {
                            if measurements.isEmpty, !isLoading {
                                Text("no_measurements")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(measurements.enumerated()), id: \.element.id) { index, measurement in
                                        let previous = measurements.indices.contains(index + 1) ? measurements[index + 1] : nil

                                        NavigationLink {
                                            BodyMeasurementDetailsView(bodyMeasurement: measurement, isEditable: false)
                                        } label: {
                                            measurementRow(measurement, previous: previous)
                                        }
                                        .buttonStyle(.plain)

                                        if measurement.id != measurements.last?.id {
                                            Divider().padding(.leading, 52)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .overlay {
                if isLoading && measurements.isEmpty {
                    ProgressView()
                }
            }
            .refreshable {
                await loadMeasurements()
            }
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                await loadMeasurements()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func measurementRow(_ measurement: BodyMeasurement, previous: BodyMeasurement?) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.apexMainColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "ruler")
                    .foregroundStyle(Color.apexMainColor)
                    .font(.system(size: 16))
            }

            Text(DateFormatter.dateWithDots.string(from: measurement.measuredAt))
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatted(measurement.weight, unit: "kg"))
                    .font(.body.bold())

                if let previous {
                    Text(weightChange(from: previous.weight, to: measurement.weight))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    private func formatted(_ value: Decimal, unit: String) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unit)"
    }

    private func weightChange(from previous: Decimal, to current: Decimal) -> String {
        let change = current - previous
        let formattedChange = change.formatted(.number.precision(.fractionLength(0...1)).sign(strategy: .always(includingZero: false)))
        return "\(formattedChange) kg"
    }

    @MainActor
    private func loadMeasurements() async {
        isLoading = true
        defer { isLoading = false }

        // GET body-measurements returns only the logged-in client's own
        // measurements, with the measurement date sent as createdAt.
        struct BodyMeasurementResponse: Decodable {
            let id: UUID
            let height, weight, shoulders, chest, upperArm, waist, thigh, calves, glutes: Decimal
            let createdAt: Date
        }

        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("body-measurements")
            let response: [BodyMeasurementResponse] = try await APIClient.shared.request(url)

            measurements = response
                .map {
                    BodyMeasurement(
                        id: $0.id,
                        height: $0.height,
                        weight: $0.weight,
                        shoulders: $0.shoulders,
                        chest: $0.chest,
                        upperArm: $0.upperArm,
                        waist: $0.waist,
                        thigh: $0.thigh,
                        calves: $0.calves,
                        glutes: $0.glutes,
                        measuredAt: $0.createdAt,
                        client: nil
                    )
                }
                .sorted { $0.measuredAt > $1.measuredAt }
        } catch is CancellationError {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

#Preview {
    MyBodyMeasurementsView()
        .environmentObject(ToastManager())
}
