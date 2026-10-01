//
//  WeightProgressChartView.swift
//  ApexPerformance
//

import SwiftUI
import Charts

// Client's weight over time, with latest weight and change
// since the first measurement. Same as the chart on the web.
struct WeightProgressChartView: View {
    let measurements: [BodyMeasurement]

    private struct Point: Identifiable {
        let id: UUID
        let date: Date
        let weight: Double
    }

    private var points: [Point] {
        measurements
            .map { Point(id: $0.id, date: $0.measuredAt, weight: NSDecimalNumber(decimal: $0.weight).doubleValue) }
            .filter { $0.weight > 0 }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        let points = points

        CardView(title: "weight_progress") {
            VStack(alignment: .leading, spacing: 16) {
                if let latest = points.last {
                    HStack(alignment: .top, spacing: 24) {
                        stat(
                            label: "latest_weight",
                            value: "\(format(latest.weight)) kg",
                            hint: Text(DateFormatter.dateWithDots.string(from: latest.date))
                        )

                        if let first = points.first, points.count > 1 {
                            let change = latest.weight - first.weight
                            stat(
                                label: "weight_change",
                                value: "\(change > 0 ? "+" : "")\(format(change)) kg",
                                hint: Text("since_first_measurement")
                            )
                        }

                        stat(label: "measurements_count", value: "\(points.count)", hint: nil)
                    }
                }

                if points.count > 1 {
                    chart(points)
                } else {
                    Text("not_enough_for_chart")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func chart(_ points: [Point]) -> some View {
        let weights = points.map(\.weight)
        // Some room above and below so the line isn't glued to the edges.
        let padding = max(1, ((weights.max() ?? 0) - (weights.min() ?? 0)) * 0.1)
        let domain = ((weights.min() ?? 0) - padding)...((weights.max() ?? 0) + padding)

        return Chart(points) { point in
            LineMark(
                x: .value("date", point.date),
                y: .value("weight", point.weight)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.apexMainColor)

            PointMark(
                x: .value("date", point.date),
                y: .value("weight", point.weight)
            )
            .foregroundStyle(Color.apexMainColor)
        }
        .chartYScale(domain: domain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let weight = value.as(Double.self) {
                        Text(verbatim: "\(format(weight)) kg")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.twoDigits))
            }
        }
        .frame(height: 200)
        .accessibilityLabel(Text("weight_progress"))
    }

    private func stat(label: LocalizedStringKey, value: String, hint: Text?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
            if let hint {
                hint
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

#Preview {
    let weights: [Decimal] = [84.5, 83.2, 82.8, 81.0, 80.4]
    let measurements = weights.enumerated().map { index, weight in
        BodyMeasurement(
            id: UUID(), height: 180, weight: weight, shoulders: 0, chest: 0, upperArm: 0,
            waist: 0, thigh: 0, calves: 0, glutes: 0,
            measuredAt: Calendar.current.date(byAdding: .day, value: index * 21 - 90, to: .now)!,
            client: nil
        )
    }

    return ScrollView {
        WeightProgressChartView(measurements: measurements)
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}
