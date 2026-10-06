//
//  CompletedTrainingsView.swift
//  ApexPerformance
//

import SwiftUI

/// Client's tab with all trainings their coach marked as completed.
struct CompletedTrainingsView: View {

    @State private var trainings: [Training] = []
    @State private var isLoading = false
    @State private var hasLoaded = false

    @EnvironmentObject private var toastManager: ToastManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("completed_trainings")
                            .font(.title.bold())
                        Text("completed_trainings_subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    CardView {
                        if trainings.isEmpty, !isLoading {
                            Text("no_completed_trainings")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            TrainingRowsView(trainings: trainings)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .overlay {
                if isLoading && trainings.isEmpty {
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
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            trainings = try await Training.loadCompleted()
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

/// Rows of trainings that open their details, used on the client's
/// tab and on client details for coaches.
struct TrainingRowsView: View {
    let trainings: [Training]
    // Set for staff, trainings can then be edited from their details.
    var onSaved: ((Training) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            ForEach(trainings) { training in
                NavigationLink {
                    TrainingDetailView(training: training, history: trainings, onSaved: onSaved)
                } label: {
                    SettingsRowView(
                        icon: training.isCompleted ? "checkmark.circle" : "calendar",
                        iconTint: training.isCompleted ? .green : .orange,
                        title: Text(verbatim: training.name),
                        subtitle: Text(verbatim: DateFormatter.dateWithDots.string(from: training.date))
                            + Text(verbatim: " · ")
                            + Text("exercises_count \(training.exercises.count)"),
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)

                if training.id != trainings.last?.id {
                    Divider().padding(.leading, 52)
                }
            }
        }
    }
}

/// Exercises and sets of one training. Staff can edit it.
struct TrainingDetailView: View {
    @State private var training: Training
    // Client's trainings, for the "last time" sets while editing.
    private let history: [Training]
    private let onSaved: ((Training) -> Void)?

    @State private var showEditSheet = false

    init(training: Training, history: [Training] = [], onSaved: ((Training) -> Void)? = nil) {
        _training = State(initialValue: training)
        self.history = history
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: training.name)
                        .font(.title2.bold())
                    Text(verbatim: DateFormatter.dateWithDots.string(from: training.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let completedAt = training.completedAt {
                        Label {
                            Text("completed_at \(DateFormatter.dateAndTimeWithDots.string(from: completedAt))")
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.green)
                    } else {
                        Label("planned", systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if let note = training.note, !note.isEmpty {
                    CardView(title: "note") {
                        Text(verbatim: note)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                }

                if training.exercises.isEmpty {
                    CardView {
                        Text("no_exercises")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                }

                ForEach(training.exercises.sorted { $0.order < $1.order }) { exercise in
                    exerciseCard(exercise)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Text(verbatim: training.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onSaved != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(Color.apexMainColor)
                    }
                    .accessibilityLabel(Text("edit_training"))
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            TrainingFormView(clientId: training.client.id, training: training, history: history) { saved in
                training = saved
                onSaved?(saved)
            }
        }
    }

    private func exerciseCard(_ exercise: Training.Exercise) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: exercise.workoutName.localized)
                    .font(.headline)

                let sets = exercise.sets.sorted { $0.order < $1.order }
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    HStack {
                        Text("set_number \(index + 1)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(verbatim: setDescription(set))
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }

                if let note = exercise.note, !note.isEmpty {
                    Text(verbatim: note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // For example "10 × 40 kg", "10" or "40 kg".
    private func setDescription(_ set: Training.ExerciseSet) -> String {
        let reps = set.reps?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        let weight = set.weight.map {
            NSDecimalNumber(decimal: $0).doubleValue.formatted(.number.precision(.fractionLength(0...2))) + " kg"
        }
        switch (reps, weight) {
        case let (reps?, weight?): return "\(reps) × \(weight)"
        case let (reps?, nil): return reps
        case let (nil, weight?): return weight
        default: return "—"
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

#Preview {
    NavigationStack {
        TrainingDetailView(training: Training(
            id: UUID(), name: "Upper body", date: .now, note: "Felt strong today.",
            isCompleted: true, completedAt: .now,
            client: .init(id: UUID(), firstName: "Ana", lastName: "Horvat"),
            exercises: [
                .init(id: UUID(), workoutId: UUID(),
                      workoutName: LocalizedText(translations: ["HR": "Bench press", "EN": "Bench press"]),
                      order: 0, note: "Slow eccentric",
                      sets: [.init(id: UUID(), order: 0, reps: "10", weight: 40),
                             .init(id: UUID(), order: 1, reps: "8", weight: 45)])
            ]))
    }
}
