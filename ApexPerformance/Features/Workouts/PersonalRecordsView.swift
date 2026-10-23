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
    @State private var hasLoaded = false

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
                    ForEach(filteredExercises) { exercise in
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
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await load()
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
                if let longestDuration = exercise.longestDuration {
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
                ForEach(exercise.history) { record in
                    HStack(spacing: 12) {
                        Image(systemName: record.isLongestDuration ? "stopwatch"
                              : record.isMaxWeight ? "scalemass" : "function")
                            .foregroundStyle(Color.apexAccent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.isLongestDuration ? "longest_duration"
                                 : record.isMaxWeight ? "max_weight" : "estimated_one_rep_max")
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
                            // The set the record comes from.
                            Text(verbatim: record.isLongestDuration
                                 ? (record.weight > 0 ? PersonalRecordFormat.kilograms(record.weight) : "—")
                                 : PersonalRecordFormat.set(weight: record.weight, reps: record.reps))
                                .font(.caption)
                                .foregroundStyle(.secondary)
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

    // Kilograms, or minutes and seconds for the longest duration.
    static func value(_ record: PersonalRecord) -> String {
        record.isLongestDuration
            ? SetDuration.text(NSDecimalNumber(decimal: record.value).intValue)
            : kilograms(record.value)
    }

    // "10 × 40 kg" or "40 kg".
    static func set(weight: Decimal, reps: Decimal?) -> String {
        guard let reps else { return kilograms(weight) }
        return "\(number(reps)) × \(kilograms(weight))"
    }
}
