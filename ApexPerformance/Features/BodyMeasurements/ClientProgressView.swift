//
//  ClientProgressView.swift
//  ApexPerformance
//

import SwiftUI
import Charts

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

/// Menu to pick the period of the progress charts, e.g. "6 MJESECI ▾".
struct ProgressPeriodMenu: View {
    @Binding var period: ProgressPeriod

    var body: some View {
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
}

/// Client's progress for a month: the coach's monthly review, body mass
/// with the change since the previous month, main circumferences and a
/// link to training progress. Opened from home.
struct ClientProgressView: View {
    @EnvironmentObject private var toastManager: ToastManager

    // First day of the chosen month.
    @State private var month = Self.startOfMonth(.now)

    @State private var measurements: [BodyMeasurement] = []
    @State private var reviews: [MonthlyReview] = []
    @State private var trainings: [Training] = []
    @State private var isLoading = false
    @State private var hasLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .lastTextBaseline) {
                    Text("progress")
                        .apexTitle()
                    Spacer()
                    monthMenu
                }

                reviewCard

                bodyMassCard

                circumferencesCard

                NavigationLink {
                    ClientTrainingProgressView(clientName: "", trainings: trainings)
                } label: {
                    HStack {
                        Text("training_progress_title")
                            .apexSectionTitle()
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .apexCardBackground()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("training-progress-row")
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                ApexTitleBar()
            }
        }
    }

    // MARK: - Month

    private static func startOfMonth(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
    }

    private static func month(_ offset: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: offset, to: date) ?? date
    }

    // This month and the 11 before it.
    private var months: [Date] {
        let current = Self.startOfMonth(.now)
        return (0..<12).map { Self.month(-$0, from: current) }
    }

    private var monthMenu: some View {
        Menu {
            Picker(selection: $month) {
                ForEach(months, id: \.self) { month in
                    MonthTitle(date: month).tag(month)
                }
            } label: {
                EmptyView()
            }
        } label: {
            HStack(spacing: 4) {
                MonthTitle(date: month)
                Image(systemName: "chevron.down")
            }
            .font(.system(size: 11, weight: .semibold))
            .tracking(1)
            .foregroundStyle(.secondary)
            .padding(.bottom, 2)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.apexBorder).frame(height: 1)
            }
        }
        .accessibilityIdentifier("progress-month")
    }

    private var monthEnd: Date {
        Self.month(1, from: month)
    }

    // MARK: - Monthly review

    /// Review of the chosen month, or the latest one written before it.
    private var review: MonthlyReview? {
        reviews.first { $0.monthDate < monthEnd }
    }

    private var reviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("coach_monthly_review")
                .apexSectionTitle()

            if let review {
                MonthTitle(date: review.monthDate)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)

                Text(verbatim: review.content)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !isLoading {
                Text("no_monthly_reviews")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if reviews.count > 1 {
                Divider().overlay(Color.apexBorder)
                NavigationLink {
                    MonthlyReviewsView(reviews: reviews)
                } label: {
                    HStack {
                        Text("previous_reviews")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.apexAccent)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .apexCardBackground()
        .accessibilityIdentifier("monthly-review-card")
    }

    // MARK: - Body mass

    // Newest first, measured before the end of the chosen month.
    private var measurementsUpToMonth: [BodyMeasurement] {
        measurements.filter { $0.measuredAt < monthEnd }
    }

    /// Latest measurement before the chosen month, to compare with.
    private var previousMonthMeasurement: BodyMeasurement? {
        measurements.first { $0.measuredAt < month }
    }

    private var bodyMassCard: some View {
        let latest = measurementsUpToMonth.first
        let previous = previousMonthMeasurement
        let points = measurementsUpToMonth
            .filter { $0.measuredAt >= Self.month(-2, from: month) && $0.weight > 0 }
            .sorted { $0.measuredAt < $1.measuredAt }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("body_mass")
                        .apexSectionTitle()
                    if let latest {
                        Text(verbatim: "\(BodyProgressView.format(BodyProgressView.double(latest.weight))) KG")
                            .font(.system(size: 28, weight: .bold))
                            .tracking(1)
                    } else {
                        Text("no_measurements")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let latest, let previous, previous.id != latest.id {
                    let change = BodyProgressView.double(latest.weight) - BodyProgressView.double(previous.weight)
                    VStack(alignment: .trailing, spacing: 2) {
                        changeLabel(change, unit: "kg")
                            .font(.system(size: 13, weight: .bold))
                        Text("compared_to_month \(previous.measuredAt.formatted(.dateTime.month(.wide)))")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if points.count > 1 {
                WeightLineChart(points: points)
                    .frame(height: 130)
            }
        }
        .padding(16)
        .apexCardBackground()
    }

    @ViewBuilder
    private func changeLabel(_ change: Double, unit: String) -> some View {
        let rounded = (change * 10).rounded() / 10
        HStack(spacing: 2) {
            if rounded != 0 {
                Image(systemName: rounded < 0 ? "arrow.down" : "arrow.up")
            }
            Text(verbatim: "\(abs(rounded).formatted(.number.precision(.fractionLength(1)))) \(unit)")
        }
        .foregroundStyle(Color.apexAccent)
    }

    // MARK: - Circumferences

    private var circumferencesCard: some View {
        let latest = measurementsUpToMonth.first
        let previous = measurementsUpToMonth.dropFirst().first
        let rows: [(LocalizedStringKey, KeyPath<BodyMeasurement, Decimal>)] = [
            ("waist", \.waist),
            ("upper_arm", \.upperArm),
            ("thigh", \.thigh)
        ]

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("body_circumferences")
                    .apexSectionTitle()
                Spacer()
                Text(verbatim: "CM")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            if let latest {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    let value = BodyProgressView.double(latest[keyPath: row.1])
                    Divider().overlay(Color.apexBorder)
                    HStack {
                        Text(row.0)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: value > 0 ? BodyProgressView.format(value) : "—")
                            .frame(width: 56, alignment: .trailing)
                        Group {
                            if let previous {
                                changeLabel(value - BodyProgressView.double(previous[keyPath: row.1]), unit: "")
                            } else {
                                Text(verbatim: "—").foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 64, alignment: .trailing)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.vertical, 9)
                }

                NavigationLink {
                    AllMeasurementsView(measurements: measurements)
                } label: {
                    HStack(spacing: 4) {
                        Text("show_all_measurements")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.apexAccent)
                    .padding(.top, 8)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("all-measurements-link")
            } else {
                Text("no_measurements")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .apexCardBackground()
    }

    // MARK: - Data

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

        // Reviews are an extra, progress works without them.
        if let loaded = try? await MonthlyReview.load() {
            reviews = loaded
        }
    }
}

/// Weight line over a short time, used on the progress screen.
struct WeightLineChart: View {
    // Oldest first.
    let points: [BodyMeasurement]

    var body: some View {
        let weights = points.map { BodyProgressView.double($0.weight) }
        let padding = max(0.5, ((weights.max() ?? 0) - (weights.min() ?? 0)) * 0.2)
        let domain = ((weights.min() ?? 0) - padding)...((weights.max() ?? 0) + padding)
        let lastId = points.last?.id

        Chart(points) { point in
            LineMark(
                x: .value("date", point.measuredAt),
                y: .value("weight", BodyProgressView.double(point.weight))
            )
            .foregroundStyle(Color.apexAccent)
            .lineStyle(StrokeStyle(lineWidth: 2))

            PointMark(
                x: .value("date", point.measuredAt),
                y: .value("weight", BodyProgressView.double(point.weight))
            )
            .foregroundStyle(Color.apexAccent)
            .symbolSize(point.id == lastId ? CGFloat(40) : CGFloat(18))
        }
        .chartYScale(domain: domain)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.apexBorder)
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
            }
        }
        .accessibilityLabel(Text("weight_progress"))
    }
}

/// All body measurements with the period charts and history.
struct AllMeasurementsView: View {
    let measurements: [BodyMeasurement]

    @State private var period: ProgressPeriod = .sixMonths

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .lastTextBaseline) {
                    Text("body_measurements")
                        .apexTitle()
                    Spacer()
                    ProgressPeriodMenu(period: $period)
                }

                BodyProgressView(measurements: measurements, period: period)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.apexBackground)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ClientProgressView()
            .environmentObject(ToastManager())
    }
}
