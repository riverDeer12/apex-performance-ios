//
//  BodyProgressView.swift
//  ApexPerformance
//

import SwiftUI
import Charts

/// Client's body progress: weight over the chosen period, latest body
/// circumferences with the change since the previous measurement, and
/// the measurement history.
struct BodyProgressView: View {
    // Newest first.
    let measurements: [BodyMeasurement]
    let period: ProgressPeriod
    var isLoading = false

    private struct Point: Identifiable {
        let id: UUID
        let date: Date
        let weight: Double
    }

    var body: some View {
        VStack(spacing: 16) {
            if measurements.isEmpty {
                CardView {
                    Group {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("no_measurements")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                bodyMassCard
                circumferencesCard
                historyCard
            }
        }
    }

    // MARK: - Body mass

    private var points: [Point] {
        measurements
            .filter { period.includes($0.measuredAt) }
            .map { Point(id: $0.id, date: $0.measuredAt, weight: Self.double($0.weight)) }
            .filter { $0.weight > 0 }
            .sorted { $0.date < $1.date }
    }

    private var bodyMassCard: some View {
        let points = points
        let latest = measurements.first.map { Self.double($0.weight) } ?? 0

        return CardView(title: "body_mass") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "\(Self.format(latest)) KG")
                        .font(.system(size: 30, weight: .bold))
                        .tracking(1)

                    Spacer()

                    if let first = points.first, let last = points.last, points.count > 1 {
                        let change = last.weight - first.weight
                        Text(verbatim: "\(Self.signed(change)) kg")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(change < 0 ? Color.green : change > 0 ? Color.orange : Color.secondary)
                    }
                }

                if points.count > 1 {
                    weightChart(points)
                } else {
                    Text("not_enough_for_chart")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func weightChart(_ points: [Point]) -> some View {
        let weights = points.map(\.weight)
        let padding = max(1, ((weights.max() ?? 0) - (weights.min() ?? 0)) * 0.15)
        let lower = (weights.min() ?? 0) - padding
        let domain = lower...((weights.max() ?? 0) + padding)

        return Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("date", point.date),
                    yStart: .value("weight", lower),
                    yEnd: .value("weight", point.weight)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(colors: [Color.apexAccent.opacity(0.25), Color.apexAccent.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                )

                LineMark(
                    x: .value("date", point.date),
                    y: .value("weight", point.weight)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.apexAccent)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("date", point.date),
                    y: .value("weight", point.weight)
                )
                .foregroundStyle(Color.apexAccent)
                .symbolSize(point.id == points.last?.id ? 60 : 24)
                .annotation(position: .top, alignment: .trailing) {
                    if point.id == points.last?.id {
                        Text(verbatim: Self.format(point.weight))
                            .font(.caption2.weight(.semibold))
                    }
                }
            }
        }
        .chartYScale(domain: domain)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Color.apexBorder)
                AxisValueLabel {
                    if let weight = value.as(Double.self) {
                        Text(verbatim: Self.format(weight))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
            }
        }
        .frame(height: 170)
        .accessibilityLabel(Text("weight_progress"))
    }

    // MARK: - Circumferences

    private var circumferencesCard: some View {
        let latest = measurements[0]
        let previous = measurements.count > 1 ? measurements[1] : nil

        let rows: [(LocalizedStringKey, KeyPath<BodyMeasurement, Decimal>)] = [
            ("shoulders", \.shoulders),
            ("chest", \.chest),
            ("waist", \.waist),
            ("upper_arm", \.upperArm),
            ("glutes", \.glutes),
            ("thigh", \.thigh),
            ("calves", \.calves)
        ]

        return CardView {
            VStack(spacing: 0) {
                HStack {
                    Text("body_circumferences")
                        .apexLabel()
                    Spacer()
                    Text(verbatim: DateFormatter.dateWithDots.string(from: latest.measuredAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 10)

                tableRow(label: Text(verbatim: ""), value: Text(verbatim: "CM"), change: Text(verbatim: "Δ"), isHeader: true)

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    let value = Self.double(latest[keyPath: row.1])
                    let change = previous.map { value - Self.double($0[keyPath: row.1]) }

                    Divider().overlay(Color.apexBorder)
                    tableRow(
                        label: Text(row.0),
                        value: Text(verbatim: value > 0 ? Self.format(value) : "—"),
                        change: Text(verbatim: change.map(Self.signed) ?? "—"),
                        changeColor: change.map { $0 < 0 ? Color.green : $0 > 0 ? Color.orange : Color.secondary } ?? .secondary
                    )
                }
            }
        }
    }

    private func tableRow(label: Text, value: Text, change: Text, isHeader: Bool = false,
                          changeColor: Color = .secondary) -> some View {
        HStack {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
            value
                .frame(width: 64, alignment: .trailing)
            change
                .foregroundStyle(isHeader ? Color.secondary : changeColor)
                .frame(width: 56, alignment: .trailing)
        }
        .font(isHeader ? .system(size: 11, weight: .semibold) : .subheadline)
        .foregroundStyle(isHeader ? Color.secondary : Color.primary)
        .textCase(.uppercase)
        .padding(.vertical, isHeader ? 6 : 10)
    }

    // MARK: - History

    private var historyCard: some View {
        CardView(title: "measurement_history") {
            VStack(spacing: 0) {
                ForEach(Array(measurements.enumerated()), id: \.element.id) { index, measurement in
                    let previous = measurements.indices.contains(index + 1) ? measurements[index + 1] : nil

                    NavigationLink {
                        BodyMeasurementDetailsView(bodyMeasurement: measurement, isEditable: false)
                    } label: {
                        historyRow(measurement, previous: previous)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("measurement-row")

                    if measurement.id != measurements.last?.id {
                        Divider().overlay(Color.apexBorder)
                    }
                }
            }
        }
    }

    private func historyRow(_ measurement: BodyMeasurement, previous: BodyMeasurement?) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: DateFormatter.dateWithDots.string(from: measurement.measuredAt))
                .font(.subheadline)

            Spacer()

            Text(verbatim: "\(Self.format(Self.double(measurement.weight))) kg")
                .font(.subheadline.weight(.semibold))

            if let previous {
                Text(verbatim: Self.signed(Self.double(measurement.weight) - Self.double(previous.weight)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Formatting

    static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    // For example "+1,0" or "−0,8".
    static func signed(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        let number = abs(rounded).formatted(.number.precision(.fractionLength(1)))
        if rounded > 0 { return "+\(number)" }
        if rounded < 0 { return "−\(number)" }
        return number
    }
}

extension BodyMeasurement {
    /// Logged client's own measurements, newest first.
    @MainActor
    static func loadMine() async throws -> [BodyMeasurement] {
        // GET body-measurements returns only the logged-in client's own
        // measurements, with the measurement date sent as createdAt.
        struct BodyMeasurementResponse: Decodable {
            let id: UUID
            let height, weight, shoulders, chest, upperArm, waist, thigh, calves, glutes: Decimal
            let createdAt: Date
        }

        let url = AppEnvironment.apiURL.appendingPathComponent("body-measurements")
        let response: [BodyMeasurementResponse] = try await APIClient.shared.request(url)

        return response
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
    }
}

#Preview {
    let weights: [Decimal] = [84.5, 83.2, 82.8, 81.0, 80.4]
    let measurements = weights.enumerated().map { index, weight in
        BodyMeasurement(
            id: UUID(), height: 180, weight: weight, shoulders: 118, chest: 102, upperArm: 35,
            waist: 82 + Decimal(index), thigh: 58, calves: 38, glutes: 99,
            measuredAt: Calendar.current.date(byAdding: .day, value: index * 21 - 90, to: .now)!,
            client: nil
        )
    }
    .sorted { $0.measuredAt > $1.measuredAt }

    return NavigationStack {
        ScrollView {
            BodyProgressView(measurements: measurements, period: .sixMonths)
                .padding(20)
        }
        .background(Color.apexBackground)
    }
}
