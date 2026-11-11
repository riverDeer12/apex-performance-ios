//
//  TrainingProgressView.swift
//  ApexPerformance
//

import SwiftUI
import Charts

/// Charts from the client's completed trainings in the chosen period:
/// summary, max weight per exercise, volume, repetitions, trainings per
/// week and the share of sets per muscle group.
struct TrainingProgressView: View {
    let trainings: [Training]
    let workouts: [Workout]
    let period: ProgressPeriod
    var isLoading = false

    // Exercise for the max weight chart, nil picks the most frequent one.
    @State private var selectedWorkoutId: UUID?

    var body: some View {
        let sessions = sessions

        VStack(spacing: 16) {
            if !recentCompleted.isEmpty {
                recentCard
            }

            if sessions.isEmpty {
                CardView {
                    Group {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("no_completed_trainings_in_period")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                summaryCard(sessions)
                maxWeightCard(sessions)
                volumeCard(sessions)
                totalRepsCard(sessions)
                averageRepsCard(sessions)
                weeklyCard(sessions)
                muscleGroupsCard(sessions)
            }
        }
    }

    // MARK: - Charts

    // Each chart is its own function to keep type checking fast.

    private func volumeCard(_ sessions: [Session]) -> some View {
        let points = sessions.map { ChartPoint(id: $0.id, date: $0.date, value: $0.volume) }
        return chartCard(title: "volume_per_training", points: points, caption: Self.lastAndFirstKg(points)) {
            barChart(points)
        }
    }

    private func totalRepsCard(_ sessions: [Session]) -> some View {
        let points = sessions.map { ChartPoint(id: $0.id, date: $0.date, value: Double($0.reps)) }
        return chartCard(title: "total_reps_per_training", points: points) {
            lineChart(points)
        }
    }

    private func averageRepsCard(_ sessions: [Session]) -> some View {
        let points = sessions
            .filter { $0.repSets > 0 }
            .map { ChartPoint(id: $0.id, date: $0.date, value: Double($0.reps) / Double($0.repSets)) }
        return chartCard(title: "average_reps_per_set", points: points) {
            lineChart(points)
        }
    }

    private func weeklyCard(_ sessions: [Session]) -> some View {
        let weeks: [WeekCount] = trainingsPerWeek(sessions)
        // No change shown: the current week isn't over yet.
        return chartCard(title: "trainings_per_week") {
            Chart(weeks, id: \.week) { item in
                BarMark(
                    x: .value("week", item.week, unit: .weekOfYear),
                    y: .value("trainings", item.count)
                )
                .foregroundStyle(Color.apexAccent)
                .cornerRadius(2)
            }
            .chartXAxis { dateAxis }
            .chartYAxis { numberAxis }
        }
    }

    private func barChart(_ points: [ChartPoint]) -> some View {
        Chart(points) { point in
            BarMark(
                x: .value("date", point.date, unit: .day),
                y: .value("value", point.value)
            )
            .foregroundStyle(Color.apexAccent)
            .cornerRadius(2)
        }
        .chartXAxis { dateAxis }
        .chartYAxis { numberAxis }
    }

    // MARK: - Data

    private struct ChartPoint: Identifiable {
        let id: UUID
        let date: Date
        let value: Double
    }

    private struct Session: Identifiable {
        let id: UUID
        let date: Date
        let training: Training
        // Sum of repetitions × weight.
        let volume: Double
        let reps: Int
        let sets: Int
        // Sets with a number of repetitions, for the average.
        let repSets: Int
    }

    private var sessions: [Session] {
        trainings
            .filter { $0.isCompleted && period.includes($0.date) }
            .sorted { $0.date < $1.date }
            .map { training in
                let sets = training.exercises.flatMap(\.sets)
                let reps = sets.compactMap { Self.reps($0.reps) }
                return Session(
                    id: training.id,
                    date: training.date,
                    training: training,
                    volume: Self.volume(of: training),
                    reps: reps.reduce(0, +),
                    sets: sets.filter { !$0.isDropSet }.count,
                    repSets: reps.count
                )
            }
    }

    /// Sum of repetitions × weight of a training's sets.
    private static func volume(of training: Training) -> Double {
        training.exercises.flatMap(\.sets).reduce(0.0) { total, set in
            guard let reps = Self.reps(set.reps), let weight = set.weight else { return total }
            return total + Double(reps) * Self.double(weight)
        }
    }

    /// First number in the repetitions text, e.g. 8 for "8-10".
    private static func reps(_ value: String?) -> Int? {
        guard let value else { return nil }
        let digits = value.trimmingCharacters(in: .whitespaces).prefix { $0.isNumber }
        return Int(digits)
    }

    private static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    // MARK: - Last 30 days

    private static let day: TimeInterval = 86_400

    // Completed trainings of the last 30 days, whatever the period.
    private var recentCompleted: [Training] {
        let now = Date()
        return trainings.filter { $0.isCompleted && $0.date <= now && $0.date > now - 30 * Self.day }
    }

    /// Volume of the last 30 days against the 30 days before, or the number
    /// of trainings when there is nothing to compare; under it the weeks in
    /// a row with a training, or the trainings of the last 30 days.
    private var recentCard: some View {
        let now = Date()
        let recent = recentCompleted
        let before = trainings.filter {
            $0.isCompleted && $0.date <= now - 30 * Self.day && $0.date > now - 60 * Self.day
        }
        let recentVolume = recent.reduce(0) { $0 + Self.volume(of: $1) }
        let beforeVolume = before.reduce(0) { $0 + Self.volume(of: $1) }
        let streak = weeksInARow(now: now)

        return VStack(alignment: .leading, spacing: 6) {
            Text("last_30_days")
                .font(.system(size: 15, weight: .semibold))
                .opacity(0.8)

            Group {
                if recentVolume > 0, beforeVolume > 0 {
                    let change = (recentVolume / beforeVolume - 1)
                        .formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always(includingZero: false)))
                    Text("volume_change_headline \(change)")
                } else {
                    Text("trainings_count \(recent.count)")
                }
            }
            .font(.system(size: 28, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Group {
                if streak >= 2 {
                    Text("weeks_in_a_row \(streak)")
                } else {
                    Text("trainings_last_30_days \(recent.count)")
                }
            }
            .font(.system(size: 15, weight: .medium))
        }
        .foregroundStyle(Color.apexOnAccent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.apexAccent)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("progress-recent-card")
    }

    /// Weeks in a row with a completed training up to now. The current
    /// week counts once it has one, it isn't over yet.
    private func weeksInARow(now: Date) -> Int {
        let calendar = Calendar.current
        let weeks = Set(trainings.filter { $0.isCompleted && $0.date <= now }.compactMap {
            calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start
        })
        guard var week = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        if !weeks.contains(week) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { return 0 }
            week = previous
        }
        var count = 0
        while weeks.contains(week), count < 520 {
            count += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { break }
            week = previous
        }
        return count
    }

    // MARK: - Summary

    private func summaryCard(_ sessions: [Session]) -> some View {
        let volume = sessions.reduce(0) { $0 + $1.volume }
        let sets = sessions.reduce(0) { $0 + $1.sets }

        return CardView(title: "progress_summary") {
            HStack(spacing: 12) {
                summaryValue("\(sessions.count)", label: "trainings")
                summaryValue("\(sets)", label: "sets")
                summaryValue("\(volume.formatted(.number.precision(.fractionLength(0)))) kg", label: "volume")
            }
        }
    }

    private func summaryValue(_ value: String, label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: value)
                .font(.system(size: 20, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .apexLabel()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Max weight

    private struct ExerciseOption: Identifiable {
        let id: UUID
        let name: String
        let count: Int
    }

    /// Exercises with a weight, most frequent first.
    private func exerciseOptions(_ sessions: [Session]) -> [ExerciseOption] {
        var names: [UUID: String] = [:]
        var counts: [UUID: Int] = [:]
        for exercise in sessions.flatMap(\.training.exercises) where exercise.sets.contains(where: { $0.weight != nil }) {
            names[exercise.workoutId] = exercise.workoutName.localized
            counts[exercise.workoutId, default: 0] += 1
        }
        return counts
            .map { ExerciseOption(id: $0.key, name: names[$0.key] ?? "", count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    private func maxWeightCard(_ sessions: [Session]) -> some View {
        let options = exerciseOptions(sessions)
        let selected = options.first { $0.id == selectedWorkoutId } ?? options.first

        // Heaviest set of the exercise on every training it was done.
        var points: [ChartPoint] = []
        if let selected {
            for session in sessions {
                let weights = session.training.exercises
                    .filter { $0.workoutId == selected.id }
                    .flatMap(\.sets)
                    .compactMap(\.weight)
                    .map(Self.double)
                if let max = weights.max() {
                    points.append(ChartPoint(id: session.id, date: session.date, value: max))
                }
            }
        }

        return CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("max_weight")
                        .apexLabel()
                    ChangeBadge(points: points.map(\.value))
                    Spacer()
                    if let selected {
                        Menu {
                            Picker(selection: Binding(
                                get: { selected.id },
                                set: { selectedWorkoutId = $0 }
                            )) {
                                ForEach(options) { option in
                                    Text(verbatim: option.name).tag(option.id)
                                }
                            } label: {
                                EmptyView()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(verbatim: selected.name)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.apexAccent)
                        }
                    }
                }

                if points.isEmpty {
                    Text("no_weights_logged")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    barChart(points)
                        .frame(height: 150)
                    if let caption = Self.lastAndFirstKg(points) {
                        Text(caption)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Trainings per week

    private struct WeekCount {
        let week: Date
        let count: Int
    }

    /// Trainings per week, including weeks without trainings.
    private func trainingsPerWeek(_ sessions: [Session]) -> [WeekCount] {
        let calendar = Calendar.current
        guard let first = sessions.first?.date,
              var week = calendar.dateInterval(of: .weekOfYear, for: first)?.start
        else { return [] }

        let counts = Dictionary(grouping: sessions) {
            calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start ?? $0.date
        }

        var result: [WeekCount] = []
        let end = Date()
        while week <= end, result.count < 60 {
            result.append(WeekCount(week: week, count: counts[week]?.count ?? 0))
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: week) else { break }
            week = next
        }
        return result
    }

    // MARK: - Muscle groups

    private struct MuscleGroup: Identifiable {
        let id: String
        let name: String
        let sets: Int
    }

    /// Logged sets per primary muscle of the exercise's workout. Exercises
    /// whose workout has no muscles count as other.
    private func muscleGroups(_ sessions: [Session]) -> [MuscleGroup] {
        let workoutsById = Dictionary(workouts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let otherId = "__other"
        let other = String(localized: "other")

        var sets: [String: Int] = [:]
        for exercise in sessions.flatMap(\.training.exercises) where !exercise.sets.isEmpty {
            let muscles = Array(Set(workoutsById[exercise.workoutId]?.muscles ?? []))
            for muscle in muscles.isEmpty ? [otherId] : muscles {
                sets[muscle, default: 0] += exercise.sets.sorted { $0.order < $1.order }.mainSetCount
            }
        }

        let sorted = sets
            .map { code, count in
                MuscleGroup(
                    id: code,
                    name: code == otherId ? other : String(localized: String.LocalizationValue("muscle_" + code)),
                    sets: count
                )
            }
            .sorted { $0.sets != $1.sets ? $0.sets > $1.sets : $0.name < $1.name }

        // At most six slices: five muscles, the rest is grouped as other.
        guard sorted.count > 6 else { return sorted }
        let muscles = sorted.filter { $0.id != otherId }
        let rest = muscles.dropFirst(5).reduce(0) { $0 + $1.sets }
            + (sorted.first { $0.id == otherId }?.sets ?? 0)
        return Array(muscles.prefix(5)) + [MuscleGroup(id: otherId, name: other, sets: rest)]
    }

    private static let sliceColors: [Color] = [.apexAccent, .teal, .indigo, .orange, .pink, .gray]

    private func muscleGroupsCard(_ sessions: [Session]) -> some View {
        let groups = muscleGroups(sessions)
        let total = max(groups.reduce(0) { $0 + $1.sets }, 1)

        return CardView(title: "muscle_group_distribution") {
            if groups.isEmpty {
                Text("no_sets_logged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 20) {
                        Chart(groups) { group in
                            SectorMark(
                                angle: .value("sets", group.sets),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .foregroundStyle(by: .value("group", group.id))
                        }
                        .chartForegroundStyleScale(
                            domain: groups.map(\.id),
                            range: Array(Self.sliceColors.prefix(groups.count))
                        )
                        .chartLegend(.hidden)
                        .frame(width: 120, height: 120)

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Self.sliceColors[index % Self.sliceColors.count])
                                        .frame(width: 8, height: 8)
                                    Text(verbatim: group.name)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text(Double(group.sets) / Double(total), format: .percent.precision(.fractionLength(0)))
                                        .foregroundStyle(.secondary)
                                }
                                .font(.footnote)
                            }
                        }
                    }

                    Text("share_of_logged_sets")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Chart helpers

    /// Card with a chart, the change from the first to the last value on
    /// the right of the title and an optional line under the chart.
    private func chartCard<Content: View>(title: LocalizedStringKey, points: [ChartPoint] = [],
                                          caption: LocalizedStringKey? = nil,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .apexLabel()
                Spacer(minLength: 8)
                ChangeBadge(points: points.map(\.value))
            }
            .padding(.top, 2)

            content()
                .frame(height: 140)

            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .apexCardBackground()
    }

    /// "Last 6,700 kg · first 5,200 kg", nil with fewer than two values.
    private static func lastAndFirstKg(_ points: [ChartPoint]) -> LocalizedStringKey? {
        guard points.count >= 2, let first = points.first, let last = points.last else { return nil }
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1))
        return "last_and_first_kg \(last.value.formatted(format)) \(first.value.formatted(format))"
    }

    private func lineChart(_ points: [ChartPoint]) -> some View {
        Chart(points) { point in
            LineMark(
                x: .value("date", point.date),
                y: .value("value", point.value)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.apexAccent)

            PointMark(
                x: .value("date", point.date),
                y: .value("value", point.value)
            )
            .foregroundStyle(Color.apexAccent)
            .symbolSize(20)
        }
        .chartXAxis { dateAxis }
        .chartYAxis { numberAxis }
    }

    private var dateAxis: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
            AxisValueLabel(format: .dateTime.day().month(.twoDigits))
        }
    }

    private var numberAxis: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
            AxisGridLine().foregroundStyle(Color.apexBorder)
            AxisValueLabel()
        }
    }
}

/// Change from the first to the last value of a chart, e.g. "↑ 29%" in
/// green or "↓ 8%" in orange; nothing with fewer than two values.
struct ChangeBadge: View {
    let points: [Double]

    var body: some View {
        if points.count >= 2, let first = points.first, let last = points.last, first > 0 {
            let change = last / first - 1
            let rounded = (change * 100).rounded()
            let color: Color = rounded > 0 ? .green : (rounded < 0 ? .orange : .secondary)
            let arrow = rounded > 0 ? "↑" : (rounded < 0 ? "↓" : "→")
            Text(verbatim: "\(arrow) \(abs(change).formatted(.percent.precision(.fractionLength(0))))")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
                .accessibilityIdentifier("chart-change")
        }
    }
}

/// Training progress of one client, opened by staff from client details.
struct ClientTrainingProgressView: View {
    let clientName: String
    // Client's trainings, only completed ones are used.
    let trainings: [Training]

    @State private var period: ProgressPeriod = .sixMonths
    @State private var workouts: [Workout] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: clientName)
                            .apexLabel()
                        Text("training_progress_title")
                            .apexTitle()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ProgressPeriodMenu(period: $period)
                }

                TrainingProgressView(trainings: trainings, workouts: workouts, period: period)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Color.apexBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Only used for muscle groups, so the charts work without it.
            guard workouts.isEmpty else { return }
            let url = AppEnvironment.apiURL.appendingPathComponent("workouts")
            if let loaded: [Workout] = try? await APIClient.shared.request(url) {
                workouts = loaded
            }
        }
    }
}

#Preview {
    let names = ["Back squat", "Bench press", "Romanian deadlift"]
    let trainings = (0..<10).map { index in
        Training(
            id: UUID(), name: "Training \(index + 1)",
            date: Calendar.current.date(byAdding: .day, value: index * 7 - 70, to: .now)!,
            note: nil, isCompleted: true, completedAt: .now,
            client: .init(id: UUID(), firstName: "Ana", lastName: "Horvat"),
            exercises: names.enumerated().map { order, name in
                .init(id: UUID(), workoutId: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(order)")!,
                      workoutName: LocalizedText(translations: ["EN": name]), order: order, note: nil,
                      sets: (0..<3).map { .init(id: UUID(), order: $0, reps: "8", weight: Decimal(40 + index * 2 + order * 10)) })
            }
        )
    }

    return ScrollView {
        TrainingProgressView(trainings: trainings, workouts: [], period: .sixMonths)
            .padding(20)
    }
    .background(Color.apexBackground)
}
