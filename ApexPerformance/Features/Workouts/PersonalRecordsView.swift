//
//  PersonalRecordsView.swift
//  ApexPerformance
//

import SwiftUI

/// Client's personal records per exercise, calculated by the API from
/// completed trainings, same as the web page. Staff open a client's
/// records, clients their own (no client id) from progress.
struct PersonalRecordsView: View {
    var clientId: UUID? = nil
    var clientName: String? = nil

    @EnvironmentObject private var toastManager: ToastManager

    @State private var exercises: [ExerciseRecords] = []
    @State private var searchText = ""
    @State private var isLoading = false

    private var filteredExercises: [ExerciseRecords] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedStandardContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ApexScreenHeader(title: "personal_records", subtitle: "personal_records_hint", showsWordmark: false)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if exercises.count > 5 {
                    searchField
                        .padding(.horizontal, 20)
                }

                if filteredExercises.isEmpty, !isLoading {
                    CardView {
                        (searchText.isEmpty ? Text("no_personal_records") : Text("no_workouts_found"))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 20)
                }

                LazyVStack(spacing: 12) {
                    ShowMoreForEach(items: filteredExercises) { exercise in
                        NavigationLink {
                            PersonalRecordHistoryView(exercise: exercise)
                        } label: {
                            card(exercise)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
        .background(Color.apexBackground)
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            if isLoading && exercises.isEmpty {
                ProgressView()
            }
        }
        .refreshable {
            await Task { await load() }.value
        }
        // Fresh data every time the screen is shown, not only after pulling
        // to refresh. Own task, so leaving the screen doesn't cancel it.
        .task {
            await Task { await load() }.value
        }
        .navigationTitle(clientName.map { Text(verbatim: $0) } ?? Text("personal_records"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(_ exercise: ExerciseRecords) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(verbatim: exercise.name)
                    .font(.system(size: 15, weight: .bold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .lineLimit(2)
                if exercise.isRecent {
                    Text("new_record")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.apexOnAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.apexAccent))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 0) {
                if exercise.longestDistance != nil || exercise.fastestPace != nil {
                    // A workout done over a distance (e.g. rowing) has no weight records.
                    stat(label: "longest_distance", record: exercise.longestDistance)
                    Divider().overlay(Color.apexBorder)
                    stat(label: "fastest_pace", record: exercise.fastestPace)
                } else if let longestDuration = exercise.longestDuration {
                    // A workout done for a time has no weight records.
                    stat(label: "longest_duration", record: longestDuration)
                } else {
                    stat(label: "max_weight", record: exercise.maxWeight)
                    Divider().overlay(Color.apexBorder)
                    stat(label: "estimated_one_rep_max", record: exercise.oneRepMax)
                }
            }
            .frame(height: 64)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.apexBorder, lineWidth: 1)
            )

            Text("last_record \(DateFormatter.dateWithDots.string(from: exercise.lastAchievedAt))")
                .apexLabel()
        }
        .padding(16)
        .apexCardBackground()
        .contentShape(Rectangle())
    }

    private func stat(label: LocalizedStringKey, record: PersonalRecord?) -> some View {
        VStack(spacing: 4) {
            Text(verbatim: record.map(PersonalRecordFormat.value) ?? "—")
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
                // A pace like "1:52 /500 m" is longer than a weight.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let record, record.isMaxWeight, let reps = record.reps {
                Text(verbatim: "× \(PersonalRecordFormat.number(reps))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let record, record.isLongestDuration, record.weight > 0 {
                Text(verbatim: "· \(PersonalRecordFormat.kilograms(record.weight))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("search_workouts", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .frame(height: 44)
        .apexCardBackground(cornerRadius: 10)
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            exercises = ExerciseRecords.group(try await PersonalRecord.load(clientId: clientId))
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

/// All records of one exercise, newest first.
struct PersonalRecordHistoryView: View {
    let exercise: ExerciseRecords

    var body: some View {
        List {
            Section {
                ShowMoreForEach(items: exercise.history) { record in
                    HStack(spacing: 12) {
                        Image(systemName: PersonalRecordFormat.systemImage(record))
                            .foregroundStyle(Color.apexAccent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(PersonalRecordFormat.label(record))
                                .font(.subheadline.weight(.semibold))
                            Text(verbatim: DateFormatter.dateWithDots.string(from: record.achievedAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(verbatim: PersonalRecordFormat.value(record))
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                            // The set the record comes from; distance and pace records are the whole set.
                            if !record.isLongestDistance && !record.isFastestPace {
                                Text(verbatim: record.isLongestDuration
                                     ? (record.weight > 0 ? PersonalRecordFormat.kilograms(record.weight) : "—")
                                     : PersonalRecordFormat.set(weight: record.weight, reps: record.reps))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("record_history")
            }
        }
        .navigationTitle(Text(verbatim: exercise.name))
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum PersonalRecordFormat {
    static func number(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).doubleValue.formatted(.number.precision(.fractionLength(0...1)))
    }

    static func kilograms(_ value: Decimal) -> String {
        "\(number(value)) kg"
    }

    // Kilograms, minutes and seconds for the longest duration, metres or
    // kilometres for the longest distance and the workout's pace for the fastest pace.
    static func value(_ record: PersonalRecord) -> String {
        if record.isLongestDuration {
            return SetDuration.text(NSDecimalNumber(decimal: record.value).intValue)
        }
        if record.isLongestDistance {
            return SetPace.distance(NSDecimalNumber(decimal: record.value).intValue)
        }
        if record.isFastestPace {
            return SetPace.speed(record.paceType, metersPerMinute: NSDecimalNumber(decimal: record.value).doubleValue)
        }
        return kilograms(record.value)
    }

    static func label(_ record: PersonalRecord) -> LocalizedStringKey {
        if record.isLongestDuration { return "longest_duration" }
        if record.isLongestDistance { return "longest_distance" }
        if record.isFastestPace { return "fastest_pace" }
        return record.isMaxWeight ? "max_weight" : "estimated_one_rep_max"
    }

    static func systemImage(_ record: PersonalRecord) -> String {
        if record.isLongestDuration { return "stopwatch" }
        if record.isLongestDistance { return "ruler" }
        if record.isFastestPace { return "speedometer" }
        return record.isMaxWeight ? "scalemass" : "function"
    }

    // "10 × 40 kg" or "40 kg".
    static func set(weight: Decimal, reps: Decimal?) -> String {
        guard let reps else { return kilograms(weight) }
        return "\(number(reps)) × \(kilograms(weight))"
    }
}
