//
//  TrainingFormView.swift
//  ApexPerformance
//

import SwiftUI

/// Creates or edits a client's training (staff only). Next to every
/// exercise it shows the sets the client did in the same exercise on
/// the previous training, same as the web form.
struct TrainingFormView: View {
    let clientId: UUID
    // Training being edited, nil for a new one.
    let training: Training?
    // Client's other trainings, used for the "last time" sets.
    let history: [Training]
    var onSaved: ((Training) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var name: String
    @State private var date: Date
    @State private var note: String
    @State private var isCompleted: Bool
    @State private var exercises: [ExerciseDraft]

    @State private var workouts: [Workout] = []
    @State private var isSaving = false

    init(clientId: UUID, training: Training? = nil, history: [Training], onSaved: ((Training) -> Void)? = nil) {
        self.clientId = clientId
        self.training = training
        self.history = history
        self.onSaved = onSaved
        _name = State(initialValue: training?.name ?? "")
        _date = State(initialValue: training?.date ?? .now)
        _note = State(initialValue: training?.note ?? "")
        _isCompleted = State(initialValue: training?.isCompleted ?? false)
        _exercises = State(initialValue: (training?.exercises ?? [])
            .sorted { $0.order < $1.order }
            .map(ExerciseDraft.init))
    }

    private var isValid: Bool {
        !trimmed(name).isEmpty && exercises.allSatisfy(\.isValid)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("name", text: $name)
                    DatePicker("date", selection: $date, displayedComponents: .date)
                    Toggle("completed", isOn: $isCompleted)
                        .tint(Color.apexMainColor)
                    TextField("note", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                ForEach($exercises) { $exercise in
                    exerciseSection($exercise)
                }

                Section {
                    Button {
                        exercises.append(ExerciseDraft())
                    } label: {
                        Label("add_exercise", systemImage: "plus")
                            .foregroundStyle(Color.apexMainColor)
                    }
                } footer: {
                    if exercises.isEmpty {
                        Text("no_exercises_yet")
                    }
                }
            }
            .navigationTitle(training == nil ? LocalizedStringKey("new_training") : LocalizedStringKey("edit_training"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        ZStack {
                            if isSaving {
                                ProgressView().scaleEffect(0.9)
                            } else {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.apexMainColor)
                            }
                        }
                    }
                    .disabled(isSaving || !isValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .foregroundStyle(Color.apexMainColor)
                    }
                }
            }
            .task {
                await loadWorkouts()
            }
        }
    }

    // MARK: - Exercise

    private func exerciseSection(_ exercise: Binding<ExerciseDraft>) -> some View {
        let index = exercises.firstIndex { $0.id == exercise.wrappedValue.id } ?? 0

        return Section {
            NavigationLink {
                WorkoutPickerView(workouts: workouts, selection: exercise.workoutId)
            } label: {
                HStack {
                    Text("exercise")
                    Spacer()
                    if let workout = workout(exercise.wrappedValue.workoutId) {
                        Text(verbatim: workout.name.localized)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text("select_exercise")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(exercise.sets) { set in
                let setIndex = exercise.wrappedValue.sets.firstIndex { $0.id == set.wrappedValue.id } ?? 0
                HStack(spacing: 8) {
                    Text("set_number \(setIndex + 1)")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 70, alignment: .leading)
                    TextField("reps", text: set.reps)
                        .multilineTextAlignment(.trailing)
                    Text(verbatim: "×")
                        .foregroundStyle(.secondary)
                    TextField("kg", text: set.weight)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 70)
                        .foregroundStyle(set.wrappedValue.isWeightValid ? Color.primary : Color.red)
                    Text("kg")
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                exercise.wrappedValue.sets.remove(atOffsets: offsets)
            }

            Button {
                exercise.wrappedValue.addSet()
            } label: {
                Label("add_set", systemImage: "plus")
                    .foregroundStyle(Color.apexMainColor)
            }
            .disabled(exercise.wrappedValue.sets.count >= ExerciseDraft.maxSets)

            if let previous = previousSets(for: exercise.wrappedValue.workoutId) {
                previousSetsView(previous) {
                    exercise.wrappedValue.sets = previous.sets.map(SetDraft.init)
                }
            }

            TextField("note", text: exercise.note)
        } header: {
            HStack {
                Text("exercise_number \(index + 1)")
                Spacer()
                Menu {
                    Button {
                        moveExercise(at: index, by: -1)
                    } label: {
                        Label("move_up", systemImage: "arrow.up")
                    }
                    .disabled(index == 0)

                    Button {
                        moveExercise(at: index, by: 1)
                    } label: {
                        Label("move_down", systemImage: "arrow.down")
                    }
                    .disabled(index == exercises.count - 1)

                    Button(role: .destructive) {
                        exercises.removeAll { $0.id == exercise.wrappedValue.id }
                    } label: {
                        Label("remove_exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(Color.apexMainColor)
                }
            }
        }
    }

    private func previousSetsView(_ previous: PreviousSets, onUse: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text("last_time \(DateFormatter.dateWithDots.string(from: previous.date))")
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .font(.subheadline.weight(.semibold))

            ForEach(Array(previous.sets.enumerated()), id: \.element.id) { index, set in
                Text(verbatim: "\(index + 1). \(Self.setDescription(set))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(action: onUse) {
                Label("use_previous_sets", systemImage: "doc.on.doc")
                    .font(.subheadline)
                    .foregroundStyle(Color.apexMainColor)
            }
            .buttonStyle(.borderless)
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    private func moveExercise(at index: Int, by offset: Int) {
        let target = index + offset
        guard exercises.indices.contains(index), exercises.indices.contains(target) else { return }
        withAnimation {
            exercises.swapAt(index, target)
        }
    }

    private func workout(_ id: UUID?) -> Workout? {
        guard let id else { return nil }
        return workouts.first { $0.id == id }
    }

    // MARK: - Previous training

    struct PreviousSets {
        let date: Date
        let sets: [Training.ExerciseSet]
    }

    /// Sets of the same exercise from the client's latest training
    /// before this one, or nil when the client didn't do it yet.
    private func previousSets(for workoutId: UUID?) -> PreviousSets? {
        guard let workoutId else { return nil }

        let earlier = history
            .filter { $0.client.id == clientId && $0.id != training?.id && $0.date <= date }
            .sorted { $0.date > $1.date }

        for previous in earlier {
            if let exercise = previous.exercises.first(where: { $0.workoutId == workoutId && !$0.sets.isEmpty }) {
                return PreviousSets(date: previous.date, sets: exercise.sets.sorted { $0.order < $1.order })
            }
        }
        return nil
    }

    // For example "10 × 40 kg", "10" or "40 kg".
    static func setDescription(_ set: Training.ExerciseSet) -> String {
        let reps = set.reps?.trimmingCharacters(in: .whitespaces)
        let weight = set.weight.map {
            NSDecimalNumber(decimal: $0).doubleValue.formatted(.number.precision(.fractionLength(0...2))) + " kg"
        }
        switch (reps?.isEmpty == false ? reps : nil, weight) {
        case let (reps?, weight?): return "\(reps) × \(weight)"
        case let (reps?, nil): return reps
        case let (nil, weight?): return weight
        default: return "—"
        }
    }

    // MARK: - API

    @MainActor
    private func loadWorkouts() async {
        guard workouts.isEmpty else { return }

        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("workouts")
            let response: [Workout] = try await APIClient.shared.request(url)
            workouts = response.sorted {
                $0.name.localized.localizedStandardCompare($1.name.localized) == .orderedAscending
            }
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let request = SaveTrainingRequest(
            client: clientId,
            name: trimmed(name),
            date: ISO8601DateFormatter().string(from: date),
            note: trimmed(note).isEmpty ? nil : trimmed(note),
            isCompleted: isCompleted,
            exercises: exercises.compactMap(\.request)
        )

        do {
            let saved = try await Training.save(request, id: training?.id)
            onSaved?(saved)
            toastManager.show("training_saved_successfully", type: .success)
            dismiss()
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Drafts

private struct ExerciseDraft: Identifiable {
    static let maxSets = 50

    let id = UUID()
    var workoutId: UUID?
    var note = ""
    // New exercise starts with one empty set.
    var sets = [SetDraft()]

    init() {}

    init(_ exercise: Training.Exercise) {
        workoutId = exercise.workoutId
        note = exercise.note ?? ""
        sets = exercise.sets.sorted { $0.order < $1.order }.map(SetDraft.init)
    }

    var isValid: Bool {
        workoutId != nil && note.count <= 500 && sets.count <= Self.maxSets && sets.allSatisfy(\.isValid)
    }

    /// Adds a set copying the last one, as sets usually repeat
    /// or change only a little.
    mutating func addSet() {
        guard sets.count < Self.maxSets else { return }
        var set = SetDraft()
        if let last = sets.last {
            set.reps = last.reps
            set.weight = last.weight
        }
        sets.append(set)
    }

    var request: SaveTrainingRequest.Exercise? {
        guard let workoutId else { return nil }
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return SaveTrainingRequest.Exercise(
            workout: workoutId,
            note: note.isEmpty ? nil : note,
            // Sets without repetitions and weight are not saved.
            sets: sets.compactMap(\.request)
        )
    }
}

private struct SetDraft: Identifiable {
    let id = UUID()
    var reps = ""
    var weight = ""

    init() {}

    init(_ set: Training.ExerciseSet) {
        reps = set.reps ?? ""
        weight = set.weight.map { NSDecimalNumber(decimal: $0).description(withLocale: Locale.current) } ?? ""
    }

    private var trimmedReps: String {
        reps.trimmingCharacters(in: .whitespaces)
    }

    // Accepts both "40,5" and "40.5".
    private var parsedWeight: Decimal? {
        let value = weight.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return value.isEmpty ? nil : Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    var isWeightValid: Bool {
        if weight.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        guard let parsedWeight else { return false }
        return parsedWeight >= 0 && parsedWeight <= 9999
    }

    var isValid: Bool {
        trimmedReps.count <= 50 && isWeightValid
    }

    var request: SaveTrainingRequest.ExerciseSet? {
        let reps = trimmedReps
        guard !reps.isEmpty || parsedWeight != nil else { return nil }
        return SaveTrainingRequest.ExerciseSet(reps: reps.isEmpty ? nil : reps, weight: parsedWeight)
    }
}

// MARK: - Workout picker

/// Searchable list of all workouts to choose a training exercise.
private struct WorkoutPickerView: View {
    let workouts: [Workout]
    @Binding var selection: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        List(workouts.filter { $0.matches(searchText) }) { workout in
            Button {
                selection = workout.id
                dismiss()
            } label: {
                HStack {
                    Text(verbatim: workout.name.localized)
                        .foregroundStyle(Color.primary)
                    Spacer()
                    if workout.id == selection {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.apexMainColor)
                    }
                }
            }
        }
        .overlay {
            if workouts.isEmpty {
                ProgressView()
            }
        }
        .searchable(text: $searchText, prompt: Text("search_workouts"))
        .navigationTitle("select_exercise")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    TrainingFormView(clientId: UUID(), history: [])
        .environmentObject(ToastManager())
}
