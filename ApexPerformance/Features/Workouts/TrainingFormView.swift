//
//  TrainingFormView.swift
//  ApexPerformance
//

import SwiftUI

/// Creates or edits a client's training (staff only). Next to every
/// exercise it shows the sets the client did in the same exercise on
/// the previous training, same as the web form. The same form creates
/// and edits training templates, which have no client, date or state.
struct TrainingFormView: View {
    let clientId: UUID?
    // Training being edited, nil for a new one.
    let training: Training?
    // Client's other trainings, used for the "last time" sets.
    let history: [Training]
    var onSaved: ((Training) -> Void)? = nil

    // Template form: the template being edited, nil for a new one.
    private let isTemplate: Bool
    private let template: TrainingTemplate?
    private var onTemplateSaved: ((TrainingTemplate) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var name: String
    @State private var date: Date
    @State private var note: String
    @State private var isCompleted: Bool
    @State private var exercises: [ExerciseDraft]

    @State private var workouts: [Workout] = []
    @State private var isSaving = false

    // Templates a new training can be filled from.
    @State private var templates: [TrainingTemplate] = []
    @State private var selectedTemplateId: UUID?

    init(clientId: UUID, training: Training? = nil, history: [Training], onSaved: ((Training) -> Void)? = nil) {
        self.clientId = clientId
        self.training = training
        self.history = history
        self.onSaved = onSaved
        isTemplate = false
        template = nil
        _name = State(initialValue: training?.name ?? "")
        _date = State(initialValue: training?.date ?? .now)
        _note = State(initialValue: training?.note ?? "")
        _isCompleted = State(initialValue: training?.isCompleted ?? false)
        _exercises = State(initialValue: (training?.exercises ?? [])
            .sorted { $0.order < $1.order }
            .map(ExerciseDraft.init))
    }

    /// New training for the same client with the exercises and sets of
    /// the given one ("Copy training"), planned for today.
    init(copying source: Training, history: [Training], onSaved: ((Training) -> Void)? = nil) {
        self.init(clientId: source.client.id, history: history, onSaved: onSaved)
        _name = State(initialValue: source.name)
        _note = State(initialValue: source.note ?? "")
        _exercises = State(initialValue: source.exercises
            .sorted { $0.order < $1.order }
            .map(ExerciseDraft.init))
    }

    /// Form of a new template, or of the given one to edit it.
    init(template: TrainingTemplate?, onSaved: ((TrainingTemplate) -> Void)? = nil) {
        clientId = nil
        training = nil
        history = []
        isTemplate = true
        self.template = template
        onTemplateSaved = onSaved
        _name = State(initialValue: template?.name ?? "")
        _date = State(initialValue: .now)
        _note = State(initialValue: template?.note ?? "")
        _isCompleted = State(initialValue: false)
        _exercises = State(initialValue: (template?.exercises ?? [])
            .sorted { $0.order < $1.order }
            .map(ExerciseDraft.init))
    }

    // Only a new training can be filled from a template.
    private var canUseTemplates: Bool {
        !isTemplate && training == nil
    }

    private var title: LocalizedStringKey {
        if isTemplate {
            return template == nil ? "new_template" : "edit_template"
        }
        return training == nil ? "new_training" : "edit_training"
    }

    private var isValid: Bool {
        !trimmed(name).isEmpty && exercises.allSatisfy(\.isValid)
    }

    var body: some View {
        NavigationStack {
            Form {
                if canUseTemplates && !templates.isEmpty {
                    Section {
                        Picker("from_template", selection: $selectedTemplateId) {
                            Text("no_template").tag(UUID?.none)
                            ForEach(templates) { template in
                                Text(verbatim: template.name).tag(UUID?.some(template.id))
                            }
                        }
                        .tint(Color.apexMainColor)
                    } footer: {
                        Text("from_template_hint")
                    }
                }

                Section {
                    TextField("name", text: $name)
                    if !isTemplate {
                        DatePicker("date", selection: $date, displayedComponents: .date)
                        Toggle("completed", isOn: $isCompleted)
                            .tint(Color.apexMainColor)
                    }
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
            .navigationTitle(title)
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
            .task {
                await loadTemplates()
            }
            .onChange(of: selectedTemplateId) {
                applySelectedTemplate()
            }
        }
    }

    /// Fills the name, note and exercises from the chosen template, like the web.
    private func applySelectedTemplate() {
        guard let template = templates.first(where: { $0.id == selectedTemplateId }) else { return }
        name = template.name
        note = template.note ?? ""
        withAnimation {
            exercises = template.exercises
                .sorted { $0.order < $1.order }
                .map(ExerciseDraft.init)
        }
    }

    // MARK: - Exercise

    private func exerciseSection(_ exercise: Binding<ExerciseDraft>) -> some View {
        let index = exercises.firstIndex { $0.id == exercise.wrappedValue.id } ?? 0
        let previous = previousSets(for: exercise.wrappedValue.workoutId)

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

            if !exercise.wrappedValue.sets.isEmpty {
                setsHeader(previous: previous)
            }

            ForEach(exercise.sets) { set in
                let setIndex = exercise.wrappedValue.sets.firstIndex { $0.id == set.wrappedValue.id } ?? 0
                HStack(spacing: 8) {
                    Text(verbatim: "\(setIndex + 1)")
                        .foregroundStyle(.secondary)
                        .frame(width: 22, alignment: .leading)
                    NumberWheelField(
                        value: set.repsValue,
                        range: 1...100,
                        defaultValue: 10,
                        allowsEmpty: true,
                        title: "reps",
                        // Reps written as text earlier (e.g. "8-10") are kept as they are.
                        displayText: set.wrappedValue.repsValue == nil && !set.wrappedValue.reps.isEmpty
                            ? set.wrappedValue.reps : nil
                    )
                    .frame(maxWidth: .infinity)
                    Text(verbatim: "×")
                        .foregroundStyle(.secondary)
                    NumberWheelField(
                        value: set.weightValue,
                        range: 0...300,
                        step: 0.5,
                        unit: "kg",
                        defaultValue: 20,
                        allowsEmpty: true,
                        title: "weight"
                    )
                    .frame(maxWidth: .infinity)
                    if let previous {
                        // Same set on the previous training, shown on the side.
                        Text(verbatim: previous.sets.indices.contains(setIndex)
                             ? Self.setDescription(previous.sets[setIndex]) : "—")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: 92, alignment: .trailing)
                    }
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

            if let previous {
                previousSetsView(previous, currentCount: exercise.wrappedValue.sets.count) {
                    exercise.wrappedValue.sets = previous.sets.map(SetDraft.init)
                }
            }

            TextField("note", text: exercise.note)
        } header: {
            HStack(spacing: 8) {
                Text(verbatim: exerciseLabels.indices.contains(index) ? exerciseLabels[index] : "\(index + 1).")
                Text("exercise")
                if isInSuperset(index) {
                    Text("superset")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.apexOnAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.apexAccent))
                }
                Spacer()
                Menu {
                    if index > 0 {
                        // Done right after the previous exercise without rest.
                        Toggle(isOn: exercise.isSupersetWithPrevious) {
                            Label("superset_with_previous", systemImage: "link")
                        }
                    }

                    Button {
                        addSupersetExercise(after: index)
                    } label: {
                        Label("add_superset_exercise", systemImage: "plus.square.on.square")
                    }

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
                        removeExercise(at: index)
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

    /// Column titles of the sets, with the previous training's date.
    private func setsHeader(previous: PreviousSets?) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: "#")
                .frame(width: 22, alignment: .leading)
            Text("reps")
                .frame(maxWidth: .infinity)
            Text(verbatim: "×")
                .hidden()
            Text("kg")
                .frame(maxWidth: .infinity)
            if let previous {
                Text("last_time")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 92, alignment: .trailing)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .textCase(.uppercase)
        .foregroundStyle(.secondary)
    }

    /// Copies the previous training's sets. Sets the current exercise
    /// doesn't have yet are listed so they aren't missed.
    private func previousSetsView(_ previous: PreviousSets, currentCount: Int,
                                  onUse: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if previous.sets.count > currentCount {
                ForEach(Array(previous.sets.enumerated()).dropFirst(currentCount), id: \.element.id) { index, set in
                    Text(verbatim: "\(index + 1). \(Self.setDescription(set))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onUse) {
                Label("use_previous_sets_from \(DateFormatter.dateWithDots.string(from: previous.date))",
                      systemImage: "doc.on.doc")
                    .font(.subheadline)
                    .foregroundStyle(Color.apexMainColor)
            }
            .buttonStyle(.borderless)
        }
    }

    private func moveExercise(at index: Int, by offset: Int) {
        let target = index + offset
        guard exercises.indices.contains(index), exercises.indices.contains(target) else { return }
        withAnimation {
            exercises.swapAt(index, target)
            // The first exercise can't be in a superset with a previous one.
            exercises[0].isSupersetWithPrevious = false
        }
    }

    // MARK: - Supersets

    // "1.", "2a", "2b"... same as the web form.
    private var exerciseLabels: [String] {
        SupersetLabels.labels(linked: exercises.map(\.isSupersetWithPrevious))
    }

    private func isLinked(_ index: Int) -> Bool {
        index > 0 && exercises.indices.contains(index) && exercises[index].isSupersetWithPrevious
    }

    private func isInSuperset(_ index: Int) -> Bool {
        isLinked(index) || isLinked(index + 1)
    }

    /// Adds an exercise done right after this one without rest. It goes after
    /// the last exercise of the superset and gets the same number of sets.
    private func addSupersetExercise(after index: Int) {
        guard exercises.indices.contains(index) else { return }
        var last = index
        while isLinked(last + 1) { last += 1 }

        var draft = ExerciseDraft()
        draft.isSupersetWithPrevious = true
        draft.sets = (0..<max(exercises[index].sets.count, 1)).map { _ in SetDraft() }

        withAnimation {
            exercises.insert(draft, at: last + 1)
        }
    }

    private func removeExercise(at index: Int) {
        guard exercises.indices.contains(index) else { return }
        // When the first exercise of a superset is removed,
        // the next one starts the superset instead.
        if !isLinked(index) && isLinked(index + 1) {
            exercises[index + 1].isSupersetWithPrevious = false
        }
        withAnimation {
            _ = exercises.remove(at: index)
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
        guard let workoutId, let clientId else { return nil }

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
    private func loadTemplates() async {
        guard canUseTemplates, templates.isEmpty else { return }
        // Optional, the form works without templates.
        templates = (try? await TrainingTemplate.loadAll()) ?? []
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        if isTemplate {
            await saveTemplate()
            return
        }
        guard let clientId else { return }

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

    @MainActor
    private func saveTemplate() async {
        let request = SaveTrainingTemplateRequest(
            name: trimmed(name),
            note: trimmed(note).isEmpty ? nil : trimmed(note),
            exercises: exercises.compactMap(\.request)
        )

        do {
            let saved = try await TrainingTemplate.save(request, id: template?.id)
            onTemplateSaved?(saved)
            toastManager.show(template == nil ? "template_created" : "template_updated", type: .success)
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
    var isSupersetWithPrevious = false

    init() {}

    init(_ exercise: Training.Exercise) {
        workoutId = exercise.workoutId
        note = exercise.note ?? ""
        isSupersetWithPrevious = exercise.isSupersetWithPrevious
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
            sets: sets.compactMap(\.request),
            isSupersetWithPrevious: isSupersetWithPrevious
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

    /// Reps for the wheel, nil when empty or not a single number.
    var repsValue: Decimal? {
        get { Int(trimmedReps).map { Decimal($0) } }
        set { reps = newValue.map { "\(NSDecimalNumber(decimal: $0).intValue)" } ?? "" }
    }

    /// Weight for the wheel.
    var weightValue: Decimal? {
        get { parsedWeight }
        set { weight = newValue.map { NSDecimalNumber(decimal: $0).description(withLocale: Locale.current) } ?? "" }
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
