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
        return chartCard(title: "volume_per_training") {
            barChart(points)
        }
    }

    private func totalRepsCard(_ sessions: [Session]) -> some View {
        let points = sessions.map { ChartPoint(id: $0.id, date: $0.date, value: Double($0.reps)) }
        return chartCard(title: "total_reps_per_training") {
            lineChart(points)
        }
    }

    private func averageRepsCard(_ sessions: [Session]) -> some View {
        let points = sessions
            .filter { $0.repSets > 0 }
            .map { ChartPoint(id: $0.id, date: $0.date, value: Double($0.reps) / Double($0.repSets)) }
        return chartCard(title: "average_reps_per_set") {
            lineChart(points)
        }
    }

    private func weeklyCard(_ sessions: [Session]) -> some View {
        let weeks: [WeekCount] = trainingsPerWeek(sessions)
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
                let volume = sets.reduce(0.0) { total, set in
                    guard let reps = Self.reps(set.reps), let weight = set.weight else { return total }
                    return total + Double(reps) * Self.double(weight)
                }
                return Session(
                    id: training.id,
                    date: training.date,
                    training: training,
                    volume: volume,
                    reps: reps.reduce(0, +),
                    sets: sets.count,
                    repSets: reps.count
                )
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
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1)
                            .textCase(.uppercase)
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

    /// Logged sets per workout type. Exercises without a type count as other.
    private func muscleGroups(_ sessions: [Session]) -> [MuscleGroup] {
        let workoutsById = Dictionary(workouts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let other = String(localized: "other")

        var sets: [String: Int] = [:]
        for exercise in sessions.flatMap(\.training.exercises) where !exercise.sets.isEmpty {
            let types = workoutsById[exercise.workoutId]?.workoutTypes.map(\.name.localized) ?? []
            for type in types.isEmpty ? [other] : types {
                sets[type, default: 0] += exercise.sets.count
            }
        }

        let sorted = sets
            .map { MuscleGroup(id: $0.key, name: $0.key, sets: $0.value) }
            .sorted { $0.sets > $1.sets }

        // At most six slices, the rest is grouped as other.
        guard sorted.count > 6 else { return sorted }
        let rest = sorted.dropFirst(5).reduce(0) { $0 + $1.sets }
        return Array(sorted.prefix(5)) + [MuscleGroup(id: "__other", name: other, sets: rest)]
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
                                .font(.caption)
                                .textCase(.uppercase)
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

    private func chartCard<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        CardView(title: title) {
            content()
                .frame(height: 140)
        }
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
