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

    // Given when this is one client's training of a session of several
    // clients (TrainingSessionFormView), which has the toolbar, the shared
    // time and the Live Activity.
    private var session: TrainingSessionContext? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var toastManager: ToastManager
    @EnvironmentObject private var authManager: AuthManager

    @State private var name: String
    @State private var date: Date
    @State private var note: String
    @State private var isCompleted: Bool
    // Planned trainings are saved without starting; others start on save.
    @State private var isPlanned: Bool
    // When the coach wrote the new training's name: its start, so the time
    // is right even when the form stays open during the training.
    @State private var startedAt: Date?
    // The running new training saved when the app went to the background,
    // so it isn't lost; the form then goes on editing it.
    @State private var autosaved: Training?
    // Live Activity started with the timer, before the training is saved.
    @State private var activityKey: String?
    // Live Activities allowed for the app; a hint tells how to turn them on.
    @State private var activitiesEnabled = true
    // This form's trainings in the save queue (kept on the device when offline).
    @State private var saveKey = UUID()
    // Kept on the device to be saved when the connection is back.
    @State private var isQueued = false
    @ObservedObject private var saveQueue = TrainingSaveQueue.shared

    // The training being edited: the given one or the autosaved new one.
    private var currentTraining: Training? {
        autosaved ?? training
    }
    @State private var exercises: [ExerciseDraft]
    // The client gets a push about a new training, about an edit only when asked.
    @State private var notifyClient: Bool

    @State private var workouts: [Workout] = []
    @State private var isSaving = false
    @State private var isConfirmingDiscard = false

    // Templates a new training can be filled from.
    @State private var templates: [TrainingTemplate] = []
    @State private var selectedTemplateId: UUID?
    // Training "Repeat last training" filled the form from.
    @State private var repeatedFrom: Training?
    // Set, drop set or exercise just removed, until undone or the snackbar goes.
    @State private var lastRemoval: Removal?
    // The set entered last, told to the session for the other client's line.
    @State private var lastSet: TrainingSession.SetActivity?

    init(clientId: UUID, training: Training? = nil, history: [Training], session: TrainingSessionContext? = nil,
         onSaved: ((Training) -> Void)? = nil) {
        self.clientId = clientId
        self.training = training
        self.history = history
        self.session = session
        self.onSaved = onSaved
        isTemplate = false
        template = nil
        _name = State(initialValue: training?.name ?? "")
        _date = State(initialValue: training?.date ?? .now)
        _note = State(initialValue: training?.note ?? "")
        _isCompleted = State(initialValue: training?.isCompleted ?? false)
        _isPlanned = State(initialValue: training.map { !$0.isCompleted && $0.startedAt == nil } ?? false)
        _notifyClient = State(initialValue: training == nil)
        _exercises = State(initialValue: (training?.exercises ?? [])
            .sorted { $0.order < $1.order }
            .map(ExerciseDraft.init))
    }

    /// New training for the same client with the exercises and sets of
    /// the given one ("Copy training"), planned for today.
    init(copying source: Training, history: [Training], session: TrainingSessionContext? = nil,
         onSaved: ((Training) -> Void)? = nil) {
        self.init(clientId: source.client.id, history: history, session: session, onSaved: onSaved)
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
        _isPlanned = State(initialValue: false)
        _notifyClient = State(initialValue: false)
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

    // Asked before closing when the form has unsaved changes.
    private var hasChanges: Bool {
        initialFingerprint.map { $0 != fingerprint } ?? false
    }

    // Everything the form saves, taken when it opens to tell later changes.
    @State private var initialFingerprint: String?

    private var fingerprint: String {
        let exercisesText = exercises.map { exercise in
            let sets = exercise.sets.map {
                "\($0.reps)x\($0.weight)\($0.isDropSet ? "d" : "")\($0.durationSeconds.map { "t\($0)" } ?? "")m\($0.distance)"
            }.joined(separator: ",")
            return "\(exercise.workoutId?.uuidString ?? "")|\(exercise.note)|\(exercise.isSupersetWithPrevious)|\(sets)"
        }.joined(separator: ";")
        let day = Calendar.current.startOfDay(for: date).timeIntervalSince1970
        return [name, note, "\(isCompleted)", "\(isPlanned)", "\(day)", exercisesText].joined(separator: "\n")
    }

    // Closes the form, asking first when there are unsaved changes.
    private func requestClose() {
        if hasChanges {
            isConfirmingDiscard = true
        } else {
            dismiss()
        }
    }

    var body: some View {
        if let session {
            // The session gives the navigation, the toolbar and the banner.
            formContent
                .onChange(of: session.saveRequest) { _, _ in
                    Task { await save() }
                }
                .onChange(of: sessionReport, initial: true) { _, report in
                    session.onReport(report)
                }
                .onChange(of: setsFingerprint) { old, new in
                    noteLastSet(old: old, new: new)
                }
        } else {
            NavigationStack {
                formContent
                    .confirmsDiscardingChanges(hasChanges, isConfirming: $isConfirmingDiscard) {
                        dismiss()
                    }
                    // No connection: saved later; a small banner says so.
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if !isTemplate {
                            TrainingSaveBanner()
                                .padding(.vertical, saveQueue.entries.isEmpty && !saveQueue.showsSaved ? 0 : 6)
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
                                requestClose()
                            } label: {
                                Image(systemName: "chevron.backward")
                                    .foregroundStyle(Color.apexMainColor)
                            }
                            .accessibilityIdentifier("training-form-close")
                        }
                    }
            }
        }
    }

    private var formContent: some View {
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

            if canUseTemplates, let source = trainingToRepeat {
                repeatSection(source)
            }

            Section {
                TextField("name", text: $name)
                    .onChange(of: name) { _, _ in
                        startTimerIfNeeded()
                        if let activityKey {
                            TrainingLiveActivity.renameDraft(activityKey, name: trimmed(name))
                        }
                    }
                // With several clients the session shows the time above them.
                if let startedAt = runningStart, startsOnSave || autosaved != nil, session?.isShared != true {
                    LabeledContent {
                        Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                    } label: {
                        Label("training_in_progress", systemImage: "timer")
                            .foregroundStyle(.orange)
                    }
                }
                if showsActivitiesOffHint {
                    Label("live_activities_off_hint", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("live-activities-off-hint")
                }
                if !isTemplate {
                    DatePicker("date", selection: $date, displayedComponents: .date)
                    Toggle("completed", isOn: $isCompleted)
                        .tint(Color.apexMainColor)
                    // Trainings of several clients all run at the session's time.
                    if canBePlanned && session?.isShared != true {
                        Toggle("planned", isOn: $isPlanned)
                            .tint(Color.apexMainColor)
                    }
                    NotifyClientToggle(isOn: $notifyClient)
                }
                TextField("note", text: $note, axis: .vertical)
                    .lineLimit(1...4)
            } footer: {
                if !isTemplate && canBePlanned {
                    Text(isPlannedNow ? "planned_training_hint" : "starts_on_save_hint")
                }
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
        // A planned training doesn't run: its activity goes away (and comes
        // back when it isn't planned any more).
        .onChange(of: isPlanned) { _, _ in updateDraftActivity() }
        .onDisappear {
            // Closed without saving: nothing runs.
            if let activityKey, autosaved == nil, !isQueued {
                TrainingLiveActivity.endDraft(activityKey)
            }
        }
        // Saved from the queue while the form is open: it goes on editing that training.
        .onChange(of: saveQueue.lastSynced) { _, synced in
            guard let synced, synced.key == saveKey else { return }
            autosaved = synced.training
            isQueued = false
            activityKey = nil
            onSaved?(synced.training)
        }
        // Locking the phone or leaving the app saves the running training.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                Task { await autosave() }
            } else if phase == .active {
                // Its activity may have gone while the phone was locked.
                reconcileActivity(restartsDraft: true)
            }
        }
        .onAppear {
            // A copied training comes with its name.
            startTimerIfNeeded()
            reconcileActivity(restartsDraft: false)
            if initialFingerprint == nil { initialFingerprint = fingerprint }
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
        // "Deleted · Undo" instead of asking before removing.
        .overlay(alignment: .bottom) {
            if let lastRemoval {
                UndoSnackbar {
                    undo(lastRemoval)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: lastRemoval.id) {
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled, self.lastRemoval?.id == lastRemoval.id else { return }
                    withAnimation { self.lastRemoval = nil }
                }
            }
        }
    }

    // MARK: - Repeat last training

    /// The client's latest training with the name typed so far, otherwise
    /// the latest one; nil when the client has no training with exercises.
    private var trainingToRepeat: Training? {
        guard let clientId else { return nil }
        let earlier = history
            .filter { $0.client.id == clientId && $0.id != currentTraining?.id && !$0.exercises.isEmpty }
            .sorted { $0.date > $1.date }
        let typed = trimmed(name)
        if !typed.isEmpty, let sameName = earlier.first(where: {
            trimmed($0.name).compare(typed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            return sameName
        }
        return earlier.first
    }

    // "12.11.2026 · Legs"
    private static func trainingDescription(_ training: Training) -> String {
        "\(DateFormatter.dateWithDots.string(from: training.date)) · \(training.name)"
    }

    private func repeatSection(_ source: Training) -> some View {
        Section {
            Button {
                repeatTraining(source)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("repeat_last_training")
                            .foregroundStyle(Color.apexMainColor)
                        Text(verbatim: Self.trainingDescription(source))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(Color.apexMainColor)
                }
            }
            .accessibilityIdentifier("repeat-last-training")
        } footer: {
            if let repeatedFrom {
                Text("repeated_from \(Self.trainingDescription(repeatedFrom))")
            }
        }
    }

    /// Fills the name and the exercises with their sets, drop sets and notes
    /// from the training; its times and completion are not copied.
    private func repeatTraining(_ source: Training) {
        name = source.name
        selectedTemplateId = nil
        withAnimation {
            exercises = source.exercises
                .sorted { $0.order < $1.order }
                .map(ExerciseDraft.init)
            repeatedFrom = source
        }
    }

    // MARK: - Undo

    struct Removal {
        enum Kind {
            // Exercise at the index; nextWasLinked when the next exercise was
            // in a superset with it (it lost the link when this one went).
            case exercise(index: Int, draft: ExerciseDraft, nextWasLinked: Bool)
            // Sets of an exercise with their indexes, and the set whose drop
            // set mark was cleared because it became the first one.
            case sets(exerciseId: UUID, removed: [(index: Int, set: SetDraft)], clearedDropSetId: UUID?)
        }

        let id = UUID()
        let kind: Kind
    }

    private func undo(_ removal: Removal) {
        withAnimation {
            switch removal.kind {
            case let .exercise(index, draft, nextWasLinked):
                let position = min(index, exercises.count)
                exercises.insert(draft, at: position)
                if nextWasLinked, exercises.indices.contains(position + 1) {
                    exercises[position + 1].isSupersetWithPrevious = true
                }
            case let .sets(exerciseId, removed, clearedDropSetId):
                guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }) else { break }
                if let clearedDropSetId,
                   let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == clearedDropSetId }) {
                    exercises[exerciseIndex].sets[setIndex].isDropSet = true
                }
                for item in removed.sorted(by: { $0.index < $1.index }) {
                    let position = min(item.index, exercises[exerciseIndex].sets.count)
                    exercises[exerciseIndex].sets.insert(item.set, at: position)
                }
            }
            lastRemoval = nil
        }
    }

    private func removeSets(of exerciseId: UUID, atOffsets offsets: IndexSet) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        let sets = exercises[exerciseIndex].sets
        let removed = offsets.filter { sets.indices.contains($0) }.map { (index: $0, set: sets[$0]) }
        guard !removed.isEmpty else { return }
        exercises[exerciseIndex].removeSets(atOffsets: offsets)
        // The first set left can't be a drop set: remembered to restore it.
        let first = exercises[exerciseIndex].sets.first
        let wasDropSet = first.flatMap { first in sets.first { $0.id == first.id } }?.isDropSet == true
        withAnimation {
            lastRemoval = Removal(kind: .sets(exerciseId: exerciseId, removed: removed,
                                              clearedDropSetId: wasDropSet ? first?.id : nil))
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
        // Done over a distance (e.g. rowing): a duration and a distance, and the pace.
        // Other sets have repetitions, weight and a duration, none of them required.
        let paceType = self.paceType(of: exercise.wrappedValue)
        // Width of the previous training's sets on the side, narrower next to three fields.
        let previousWidth: CGFloat = paceType == nil ? 64 : 92

        return Section {
            NavigationLink {
                WorkoutPickerView(workouts: workouts, trainingName: name, selection: exercise.workoutId,
                                  onCreated: canCreateWorkouts ? { addCreatedWorkout($0) } : nil,
                                  onToggleFavorite: { workout in Task { await toggleFavorite(workout) } })
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
                setsHeader(previous: previous, hasDistance: paceType != nil, previousWidth: previousWidth)
            }

            let setNumbers = exercise.wrappedValue.setNumbers
            ForEach(exercise.sets) { set in
                let setIndex = exercise.wrappedValue.sets.firstIndex { $0.id == set.wrappedValue.id } ?? 0
                HStack(spacing: 8) {
                    if let number = setNumbers.indices.contains(setIndex) ? setNumbers[setIndex] : nil {
                        Text(verbatim: "\(number)")
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .leading)
                    } else {
                        // Drop set of the set above.
                        Image(systemName: "arrow.turn.down.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.apexMainColor)
                            .frame(width: 22, alignment: .trailing)
                            .accessibilityLabel(Text("drop_set"))
                    }
                    if paceType != nil {
                        // Walks and rides over a distance can last longer than an hour.
                        DurationWheelField(seconds: set.durationSeconds, title: "time", showsHours: true,
                                           isLarge: true)
                            .frame(maxWidth: .infinity)
                    } else {
                        NumberWheelField(
                            value: set.repsValue,
                            range: 1...100,
                            defaultValue: 10,
                            allowsEmpty: true,
                            title: "reps",
                            // Reps written as text earlier (e.g. "8-10") are kept as they are.
                            displayText: set.wrappedValue.repsValue == nil && !set.wrappedValue.reps.isEmpty
                                ? set.wrappedValue.reps : nil,
                            isLarge: true
                        )
                        .frame(maxWidth: .infinity)
                    }
                    Text(verbatim: paceType == nil ? "×" : "·")
                        .foregroundStyle(.secondary)
                    if let paceType {
                        distanceField(set, paceType: paceType)
                            .frame(maxWidth: .infinity)
                    } else {
                        NumberWheelField(
                            value: set.weightValue,
                            range: 0...300,
                            step: 0.5,
                            unit: "kg",
                            defaultValue: 20,
                            allowsEmpty: true,
                            title: "weight",
                            isLarge: true
                        )
                        .frame(maxWidth: .infinity)
                        // How long the set lasted, optional for every exercise.
                        DurationWheelField(seconds: set.durationSeconds, title: "time", showsHours: false,
                                           isLarge: true)
                            .frame(maxWidth: .infinity)
                    }
                    if let previous {
                        // Same set on the previous training, shown on the side.
                        Text(verbatim: previous.sets.indices.contains(setIndex)
                             ? Self.setDescription(previous.sets[setIndex], paceType: previous.paceType ?? paceType)
                             : "—")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: previousWidth, alignment: .trailing)
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        exercise.wrappedValue.addDropSet(after: setIndex)
                    } label: {
                        Label("add_drop_set", systemImage: "arrow.turn.down.right")
                    }
                    .tint(Color.apexMainColor)
                }
            }
            .onDelete { offsets in
                removeSets(of: exercise.wrappedValue.id, atOffsets: offsets)
            }

            if exercise.wrappedValue.sets.isEmpty {
                Button {
                    exercise.wrappedValue.addSet()
                } label: {
                    Label("add_set", systemImage: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.apexMainColor)
                }
            } else {
                // +1 rep and +2.5 kg change the last set; repeat set adds a copy of
                // the last one that isn't a drop set. Sets over a distance or for
                // a time have no reps and weight to change.
                quickSetButtons(exercise,
                                changesRepsAndWeight: paceType == nil
                                    && workout(exercise.wrappedValue.workoutId)?.isTimed != true)
            }

            // Same exercise right after the last set, with less weight.
            Button {
                exercise.wrappedValue.addDropSet(after: exercise.wrappedValue.sets.count - 1)
            } label: {
                Label("add_drop_set", systemImage: "arrow.turn.down.right")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.apexMainColor)
            }
            .disabled(exercise.wrappedValue.sets.isEmpty
                      || exercise.wrappedValue.sets.count >= ExerciseDraft.maxSets)

            if let previous {
                previousSetsView(previous, currentCount: exercise.wrappedValue.sets.count,
                                 paceType: previous.paceType ?? paceType) {
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
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.apexOnAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.apexAccent))
                }
                Spacer(minLength: 8)
                if let previous, let topSet = Self.topSetDescription(previous, paceType: previous.paceType ?? paceType) {
                    // Best set of the previous training, e.g. "Last time 6 × 70 kg".
                    (Text("last_time") + Text(verbatim: " ") + Text(verbatim: topSet).fontWeight(.semibold))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityIdentifier("last-time")
                }
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
            .font(.subheadline.weight(.semibold))
            .textCase(nil)
        }
    }

    /// +1 rep, +2.5 kg (on the last set) and repeat set, under the sets.
    private func quickSetButtons(_ exercise: Binding<ExerciseDraft>, changesRepsAndWeight: Bool) -> some View {
        let draft = exercise.wrappedValue
        let isFull = draft.sets.count >= ExerciseDraft.maxSets
        return HStack(spacing: 8) {
            if changesRepsAndWeight {
                quickButton("quick_add_rep", systemImage: "plus") {
                    exercise.wrappedValue.addRepToLastSet()
                }
                .disabled(!draft.canAddRepToLastSet)
                .accessibilityIdentifier("quick-add-rep")

                quickButton("quick_add_weight", systemImage: "scalemass") {
                    exercise.wrappedValue.addWeightToLastSet()
                }
                .disabled(!draft.canAddWeightToLastSet)
                .accessibilityIdentifier("quick-add-weight")
            }

            quickButton("repeat_set", systemImage: "arrow.clockwise") {
                exercise.wrappedValue.addSet()
            }
            .disabled(isFull)
            .accessibilityIdentifier("quick-repeat-set")
        }
    }

    private func quickButton(_ title: LocalizedStringKey, systemImage: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleOnly)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.apexMainColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.apexMainColor.opacity(0.12))
                )
                .contentShape(Rectangle())
        }
        // Each button tappable on its own inside the form row.
        .buttonStyle(.borderless)
    }

    /// Distance of a set in metres with its pace shown as it is typed, like the web.
    private func distanceField(_ set: Binding<SetDraft>, paceType: String) -> some View {
        let pace = SetPace.pace(paceType, meters: set.wrappedValue.distanceMeters,
                                seconds: set.wrappedValue.durationSeconds)
        return VStack(spacing: 2) {
            HStack(spacing: 4) {
                TextField("distance_placeholder", text: set.distance)
                    .font(.title3.weight(.semibold))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel(Text("distance"))
                Text(verbatim: "m")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
            )
            if !pace.isEmpty {
                Text(verbatim: pace)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.apexMainColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    /// Column titles of the sets, with the previous training's date.
    private func setsHeader(previous: PreviousSets?, hasDistance: Bool, previousWidth: CGFloat) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: "#")
                .frame(width: 22, alignment: .leading)
            Text(hasDistance ? LocalizedStringKey("time") : LocalizedStringKey("reps"))
                .frame(maxWidth: .infinity)
            Text(verbatim: "×")
                .hidden()
            Text(hasDistance ? LocalizedStringKey("distance") : LocalizedStringKey("kg"))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
            if !hasDistance {
                Text("time")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
            if let previous {
                Text("last_time")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: previousWidth, alignment: .trailing)
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    /// Copies the previous training's sets. Sets the current exercise
    /// doesn't have yet are listed so they aren't missed.
    private func previousSetsView(_ previous: PreviousSets, currentCount: Int, paceType: String?,
                                  onUse: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if previous.sets.count > currentCount {
                ForEach(Array(previous.sets.enumerated()).dropFirst(currentCount), id: \.element.id) { index, set in
                    Text(verbatim: "\(index + 1). \(Self.setDescription(set, paceType: paceType))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onUse) {
                Label("use_previous_sets_from \(DateFormatter.dateWithDots.string(from: previous.date))",
                      systemImage: "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
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
        let nextWasLinked = !isLinked(index) && isLinked(index + 1)
        if nextWasLinked {
            exercises[index + 1].isSupersetWithPrevious = false
        }
        withAnimation {
            let draft = exercises.remove(at: index)
            lastRemoval = Removal(kind: .exercise(index: index, draft: draft, nextWasLinked: nextWasLinked))
        }
    }

    // Like the Workouts tab: everyone but clients can add workouts.
    private var canCreateWorkouts: Bool {
        !authManager.hasRole(role: "Client")
    }

    /// A workout added from the picker goes into the list at its place,
    /// so its exercise shows its name and the next pickers have it.
    private func addCreatedWorkout(_ created: Workout) {
        guard !workouts.contains(where: { $0.id == created.id }) else { return }
        workouts.append(created)
        workouts.sort {
            $0.name.localized.localizedStandardCompare($1.name.localized) == .orderedAscending
        }
    }

    /// Star swiped in the exercise picker: shown at once, put back when the API fails.
    @MainActor
    private func toggleFavorite(_ workout: Workout) async {
        guard let index = workouts.firstIndex(where: { $0.id == workout.id }) else { return }
        let isFavorite = !workouts[index].isFavoriteWorkout
        workouts[index].isFavorite = isFavorite

        do {
            try await Workout.setFavorite(id: workout.id, isFavorite)
        } catch {
            if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
                workouts[index].isFavorite = !isFavorite
            }
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    private func workout(_ id: UUID?) -> Workout? {
        guard let id else { return nil }
        return workouts.first { $0.id == id }
    }

    /// Pace type of the exercise's workout: its sets record a distance and show a pace.
    /// Sets that already have a distance keep it shown (also when the workout was changed since).
    private func paceType(of exercise: ExerciseDraft) -> String? {
        if let paceType = workout(exercise.workoutId)?.paceType, !paceType.isEmpty {
            return paceType
        }
        guard exercise.sets.contains(where: { $0.distanceMeters != nil }) else { return nil }
        return exercise.savedPaceType ?? PaceType.perKm.rawValue
    }

    // MARK: - Previous training

    struct PreviousSets {
        let date: Date
        let sets: [Training.ExerciseSet]
        // Pace type of the workout then, for sets over a distance.
        var paceType: String? = nil
    }

    /// Sets of the same exercise from the client's latest training
    /// before this one, or nil when the client didn't do it yet.
    private func previousSets(for workoutId: UUID?) -> PreviousSets? {
        guard let workoutId, let clientId else { return nil }

        let earlier = history
            .filter { $0.client.id == clientId && $0.id != currentTraining?.id && $0.date <= date }
            .sorted { $0.date > $1.date }

        for previous in earlier {
            if let exercise = previous.exercises.first(where: { $0.workoutId == workoutId && !$0.sets.isEmpty }) {
                return PreviousSets(date: previous.date, sets: exercise.sets.sorted { $0.order < $1.order },
                                    paceType: exercise.paceType)
            }
        }
        return nil
    }

    /// Heaviest set of the previous training (then the one with most
    /// repetitions), e.g. "6 × 70 kg"; the last set when none has a weight.
    static func topSetDescription(_ previous: PreviousSets, paceType: String?) -> String? {
        let sets = previous.sets.filter { !$0.isDropSet }
        let weighted = sets.filter { $0.weight != nil }
        let top = weighted.max { first, second in
            let firstWeight = NSDecimalNumber(decimal: first.weight ?? 0).doubleValue
            let secondWeight = NSDecimalNumber(decimal: second.weight ?? 0).doubleValue
            if firstWeight != secondWeight { return firstWeight < secondWeight }
            return leadingNumber(first.reps) < leadingNumber(second.reps)
        } ?? sets.last ?? previous.sets.last
        guard let top else { return nil }
        let text = setDescription(top, paceType: paceType)
        return text == "—" ? nil : text
    }

    // First number of a repetitions text, e.g. 8 for "8-10", 0 without one.
    private static func leadingNumber(_ reps: String?) -> Int {
        Int(reps?.trimmingCharacters(in: .whitespaces).prefix { $0.isNumber } ?? "") ?? 0
    }

    // For example "10 × 40 kg", "10", "40 kg", "10 × 40 kg · 0:45" with a duration,
    // "1:30 · 10 kg" for a set held for a time or "2 km · 7:30 · 1:52 /500 m" for a
    // set over a distance.
    static func setDescription(_ set: Training.ExerciseSet, paceType: String? = nil) -> String {
        let reps = set.reps?.trimmingCharacters(in: .whitespaces)
        let weight = set.weight.map {
            NSDecimalNumber(decimal: $0).doubleValue.formatted(.number.precision(.fractionLength(0...2))) + " kg"
        }
        if let distance = set.distanceText(paceType: paceType) {
            return [distance, weight].compactMap { $0 }.joined(separator: " · ")
        }
        let hasReps = reps?.isEmpty == false
        if let duration = set.durationSeconds, !hasReps {
            return [SetDuration.text(duration), weight].compactMap { $0 }.joined(separator: " · ")
        }
        let lift: String? = switch (hasReps ? reps : nil, weight) {
        case let (reps?, weight?): "\(reps) × \(weight)"
        case let (reps?, nil): reps
        case let (nil, weight?): weight
        default: nil
        }
        let text = [lift, set.durationSeconds.map(SetDuration.text)].compactMap { $0 }.joined(separator: " · ")
        return text.isEmpty ? "—" : text
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

    // A training not started or completed yet can be marked as planned.
    private var canBePlanned: Bool {
        !isCompleted && currentTraining?.startedAt == nil
    }

    /// A training not marked as planned starts when it is saved, so its
    /// time is measured without another tap.
    private var startsOnSave: Bool {
        !isTemplate && canBePlanned && !isPlannedNow
    }

    // Trainings of several clients aren't planned: they run at the session's time.
    private var isPlannedNow: Bool {
        isPlanned && session?.isShared != true
    }

    // Trainings of several clients are linked by the session's id; a training
    // on its own sends none (an edit keeps the session it has).
    private var sessionIdToSave: UUID? {
        session?.isShared == true ? session?.sessionKey : nil
    }

    // The start of the new training: the session's shared one, or the form's own.
    private var runningStart: Date? {
        if let session { return session.startedAt }
        return startedAt
    }

    // MARK: - Session

    /// What the session shows of this client's training and needs to save it.
    private var sessionReport: TrainingFormReport {
        TrainingFormReport(
            trainingName: trimmed(name),
            enteredSets: exercises.reduce(0) { total, exercise in total + exercise.sets.filter { $0.request != nil }.count },
            lastSet: lastSet,
            hasChanges: hasChanges,
            isValid: isValid,
            startsOnSave: startsOnSave,
            saved: autosaved,
            isQueued: isQueued,
            queueKey: saveKey
        )
    }

    // The sets of every exercise, to tell which one the coach just changed.
    private var setsFingerprint: [String] {
        exercises.map { exercise in
            let sets = exercise.sets.map {
                "\($0.reps)x\($0.weight)t\($0.durationSeconds ?? -1)m\($0.distance)"
            }.joined(separator: ",")
            return "\(exercise.id.uuidString)|\(exercise.workoutId?.uuidString ?? "")|\(sets)"
        }
    }

    /// Remembers the exercise whose sets just changed, e.g. "Squat 3/4",
    /// for the line the other clients' trainings show about this one.
    private func noteLastSet(old: [String], new: [String]) {
        let before = Set(old)
        guard let index = new.firstIndex(where: { !before.contains($0) }),
              exercises.indices.contains(index) else { return }
        let exercise = exercises[index]
        let entered = exercise.sets.filter { $0.request != nil }.count
        guard entered > 0 else { return }
        lastSet = TrainingSession.SetActivity(
            at: .now,
            exerciseName: workout(exercise.workoutId)?.name.localized ?? "",
            enteredSets: entered,
            setCount: exercise.sets.count
        )
    }

    /// Saves the running new training as in progress when the app goes to
    /// the background (locked phone, another app), so nothing is lost if
    /// the app is closed. The form stays open and goes on editing it; a
    /// failed try is repeated the next time.
    @MainActor
    private func autosave() async {
        // An unfinished exercise (no workout picked yet) waits for the next save.
        guard let start = runningStart, let clientId, !isTemplate, !isSaving, !trimmed(name).isEmpty,
              autosaved != nil || startsOnSave else { return }

        // iOS gives the app a little time in the background to finish.
        let app = UIApplication.shared
        var backgroundTask = UIBackgroundTaskIdentifier.invalid
        backgroundTask = app.beginBackgroundTask {
            app.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        defer {
            if backgroundTask != .invalid { app.endBackgroundTask(backgroundTask) }
        }

        let request = SaveTrainingRequest(
            client: clientId,
            name: trimmed(name),
            date: ISO8601DateFormatter().string(from: autosaved?.date ?? start),
            note: trimmed(note).isEmpty ? nil : trimmed(note),
            isCompleted: false,
            exercises: exercises.filter(\.isValid).compactMap(\.request),
            // The client hears about the new training once.
            notifyClient: autosaved == nil && notifyClient,
            sessionId: sessionIdToSave
        )

        // Without a connection it is kept on the device and saved later.
        let outcome = await saveQueue.save(
            key: saveKey, request: request, trainingId: autosaved?.id,
            startedAt: autosaved == nil ? start : nil,
            activityKey: autosaved == nil ? (session?.activityKey ?? activityKey) : nil,
            sessionKey: session?.sessionKey
        )
        switch outcome {
        case .saved(let saved):
            autosaved = saved
            isQueued = false
            notifyClient = false
            // Nothing to discard any more: it is saved.
            initialFingerprint = fingerprint
            onSaved?(saved)
        case .queued:
            isQueued = true
            notifyClient = false
            // Kept on the device, nothing is lost when the form closes.
            initialFingerprint = fingerprint
        case .failed(let error):
            print("Training not autosaved: \(error)")
        }
    }

    /// A new training starts when its name is written, not when it is saved.
    private func startTimerIfNeeded() {
        guard training == nil, !isTemplate, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // The session's time is shared by all its trainings: the first name starts it.
        if let session {
            if session.startedAt == nil { session.onStart() }
            return
        }
        guard startedAt == nil else { return }
        startedAt = .now
        updateDraftActivity()
    }

    /// Shows the running new training on the lock screen and in the Dynamic
    /// Island right away: iOS starts activities only while the app is open.
    private func updateDraftActivity() {
        // The session has one activity for all its trainings.
        guard session == nil, autosaved == nil, let startedAt else { return }
        if startsOnSave, activityKey == nil {
            activityKey = TrainingLiveActivity.startDraft(name: trimmed(name), clientName: draftClientName,
                                                          startedAt: startedAt)
        } else if !startsOnSave, let activityKey {
            TrainingLiveActivity.endDraft(activityKey)
            self.activityKey = nil
        }
    }

    private var draftClientName: String {
        let client = history.first { $0.client.id == clientId }?.client
        return [client?.firstName, client?.lastName].compactMap { $0 }.joined(separator: " ")
    }

    /// The running training has its Live Activity: the form appeared or the
    /// app came back to the foreground, and it went away meanwhile (e.g.
    /// while the phone was locked) or never started. Foreground only.
    /// The draft of a new training is checked when the app comes back (on
    /// appearing it was just started).
    private func reconcileActivity(restartsDraft: Bool) {
        guard !isTemplate else { return }
        activitiesEnabled = TrainingLiveActivity.areEnabled
        // Saved: started again if it was started on this iPhone.
        if let current = currentTraining, current.isRunning {
            TrainingLiveActivity.reconcile(current)
            return
        }
        // Not saved yet: the form's draft (a session's is the session's).
        guard restartsDraft, session == nil, autosaved == nil, let startedAt, startsOnSave else { return }
        activityKey = TrainingLiveActivity.restartDraftIfNeeded(activityKey, isRunning: true, name: trimmed(name),
                                                                clientName: draftClientName, startedAt: startedAt)
    }

    // The training runs (or starts on save) and Live Activities are off.
    private var showsActivitiesOffHint: Bool {
        guard !isTemplate, !activitiesEnabled else { return false }
        return (runningStart != nil && startsOnSave) || currentTraining?.isRunning == true
    }

    /// Saves the training; one not marked as planned is also marked as
    /// started now (in progress).
    @MainActor
    private func save() async {
        let starting = startsOnSave
        let start = runningStart ?? .now
        isSaving = true
        defer { isSaving = false }

        if isTemplate {
            await saveTemplate()
            return
        }
        guard let clientId else { return }
        // An unfinished form answers the session's Save, which waits for every training.
        if let session, !isValid {
            session.onSaveOutcome(.failed(message: String(localized: "training_session_incomplete")))
            return
        }

        let request = SaveTrainingRequest(
            client: clientId,
            name: trimmed(name),
            // A started training happens today.
            date: ISO8601DateFormatter().string(from: starting ? start : date),
            note: trimmed(note).isEmpty ? nil : trimmed(note),
            isCompleted: isCompleted,
            exercises: exercises.compactMap(\.request),
            notifyClient: notifyClient,
            sessionId: sessionIdToSave
        )

        // Without a connection it is kept on the device and saved later.
        let outcome = await saveQueue.save(
            key: saveKey, request: request, trainingId: currentTraining?.id,
            startedAt: starting ? start : nil,
            activityKey: starting ? (session?.activityKey ?? activityKey) : nil,
            sessionKey: session?.sessionKey
        )
        switch outcome {
        case .saved(let saved):
            // Saved: the activity stays with the training.
            activityKey = nil
            onSaved?(saved)
            if let session {
                // The session closes once all its trainings are saved; until
                // then this one is edited, so another try doesn't create it again.
                autosaved = saved
                isQueued = false
                notifyClient = false
                initialFingerprint = fingerprint
                session.onSaveOutcome(.saved)
                return
            }
            toastManager.show(starting ? "training_started_toast" : "training_saved_successfully", type: .success)
            dismiss()
        case .queued:
            // The queue links the activity once the training is saved.
            activityKey = nil
            isQueued = true
            if let session {
                notifyClient = false
                initialFingerprint = fingerprint
                session.onSaveOutcome(.queued)
                return
            }
            toastManager.show("offline_will_save", type: .info)
            dismiss()
        case .failed(let error):
            if let session {
                session.onSaveOutcome(.failed(message: mapError(error)))
                return
            }
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

// MARK: - Session

/// What a training form of a session (TrainingSessionFormView) gets from it.
struct TrainingSessionContext {
    let sessionKey: UUID
    // The shared start of all trainings of the session, nil until a name is written.
    let startedAt: Date?
    // More than one client: the session shows the time and the switcher.
    let isShared: Bool
    // The session's Live Activity: linked to this training when it is saved (first client only).
    let activityKey: String?
    // Changes when the session's Save is tapped: every form saves its training.
    let saveRequest: Int
    // A name was written: the session's time starts.
    let onStart: () -> Void
    let onReport: (TrainingFormReport) -> Void
    let onSaveOutcome: (TrainingSession.SaveOutcome) -> Void
}

/// What a training form of a session tells the session.
struct TrainingFormReport: Equatable {
    var trainingName: String
    var enteredSets: Int
    var lastSet: TrainingSession.SetActivity?
    var hasChanges: Bool
    var isValid: Bool
    var startsOnSave: Bool
    var saved: Training?
    var isQueued: Bool
    var queueKey: UUID
}

// MARK: - Drafts

struct ExerciseDraft: Identifiable {
    static let maxSets = 50

    let id = UUID()
    var workoutId: UUID?
    var note = ""
    // New exercise starts with one empty set.
    var sets = [SetDraft()]
    var isSupersetWithPrevious = false
    // Pace type the exercise was saved with, for sets over a distance.
    var savedPaceType: String?

    init() {}

    init(_ exercise: Training.Exercise) {
        workoutId = exercise.workoutId
        note = exercise.note ?? ""
        isSupersetWithPrevious = exercise.isSupersetWithPrevious
        savedPaceType = exercise.paceType
        sets = exercise.sets.sorted { $0.order < $1.order }.map(SetDraft.init)
    }

    var isValid: Bool {
        workoutId != nil && note.count <= 500 && sets.count <= Self.maxSets && sets.allSatisfy(\.isValid)
    }

    /// Adds a set copying the last one that isn't a drop set, as sets
    /// usually repeat or change only a little.
    mutating func addSet() {
        guard sets.count < Self.maxSets else { return }
        var set = SetDraft()
        if let last = sets.last(where: { !$0.isDropSet }) ?? sets.last {
            set.reps = last.reps
            set.weight = last.weight
            set.durationSeconds = last.durationSeconds
            set.distance = last.distance
        }
        sets.append(set)
    }

    /// The last set's repetitions can go up by one (a number up to 100, or none yet).
    var canAddRepToLastSet: Bool {
        guard let last = sets.last else { return false }
        if last.reps.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        return last.repsValue.map { $0 < 100 } ?? false
    }

    /// One more repetition in the last set.
    mutating func addRepToLastSet() {
        guard canAddRepToLastSet, let index = sets.indices.last else { return }
        sets[index].repsValue = (sets[index].repsValue ?? 0) + 1
    }

    var canAddWeightToLastSet: Bool {
        guard let last = sets.last, last.isWeightValid else { return false }
        return (last.weightValue ?? 0) + Self.weightStep <= 300
    }

    // Weight added by the +2.5 kg button.
    static let weightStep = Decimal(string: "2.5") ?? 2.5

    /// 2.5 kg more in the last set.
    mutating func addWeightToLastSet() {
        guard canAddWeightToLastSet, let index = sets.indices.last else { return }
        sets[index].weightValue = (sets[index].weightValue ?? 0) + Self.weightStep
    }

    /// Adds a drop set after the set at the index and its drop sets:
    /// the same reps with about a fifth less weight.
    mutating func addDropSet(after index: Int) {
        guard sets.indices.contains(index), sets.count < Self.maxSets else { return }
        var end = index + 1
        while end < sets.count && sets[end].isDropSet { end += 1 }
        let previous = sets[end - 1]
        var drop = SetDraft()
        drop.isDropSet = true
        drop.reps = previous.reps
        drop.durationSeconds = previous.durationSeconds
        drop.distance = previous.distance
        drop.weightValue = previous.weightValue.map { weight in
            // Rounded to half a kilogram, like the weight wheel.
            var lighter = weight * Decimal(0.8) * 2
            var rounded = Decimal()
            NSDecimalRound(&rounded, &lighter, 0, .plain)
            return rounded / 2
        }
        sets.insert(drop, at: end)
    }

    /// Removes sets; the first one left can't be a drop set.
    mutating func removeSets(atOffsets offsets: IndexSet) {
        sets.remove(atOffsets: offsets)
        if !sets.isEmpty { sets[0].isDropSet = false }
    }

    /// Numbers of sets, nil for drop sets (like Training.ExerciseSet).
    var setNumbers: [Int?] {
        var number = 0
        return sets.map { set in
            if set.isDropSet && number > 0 { return nil }
            number += 1
            return number
        }
    }

    var request: SaveTrainingRequest.Exercise? {
        guard let workoutId else { return nil }
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return SaveTrainingRequest.Exercise(
            workout: workoutId,
            note: note.isEmpty ? nil : note,
            // Sets without repetitions, weight, duration and distance are not saved.
            sets: sets.compactMap(\.request),
            isSupersetWithPrevious: isSupersetWithPrevious
        )
    }
}

struct SetDraft: Identifiable {
    let id = UUID()
    var reps = ""
    var weight = ""
    // Done right after the previous set with less weight.
    var isDropSet = false
    // How long the set lasted, for timed workouts (e.g. plank).
    var durationSeconds: Int?
    // Metres as typed, for workouts done over a distance (e.g. rowing).
    var distance = ""

    init() {}

    init(_ set: Training.ExerciseSet) {
        isDropSet = set.isDropSet
        durationSeconds = set.durationSeconds
        distance = set.distanceMeters.map { String($0) } ?? ""
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

    private var trimmedDistance: String {
        distance.trimmingCharacters(in: .whitespaces)
    }

    /// Metres, nil when empty or not a whole number above zero.
    var distanceMeters: Int? {
        Int(trimmedDistance).flatMap { $0 > 0 ? $0 : nil }
    }

    // Same limits as the web form and API.
    var isDistanceValid: Bool {
        if trimmedDistance.isEmpty { return true }
        guard let distanceMeters else { return false }
        return distanceMeters <= 500_000
    }

    var isValid: Bool {
        trimmedReps.count <= 50 && isWeightValid && isDistanceValid
    }

    var request: SaveTrainingRequest.ExerciseSet? {
        let reps = trimmedReps
        // A set with only a distance is saved too.
        guard !reps.isEmpty || parsedWeight != nil || durationSeconds != nil || distanceMeters != nil else {
            return nil
        }
        return SaveTrainingRequest.ExerciseSet(reps: reps.isEmpty ? nil : reps, weight: parsedWeight,
                                               isDropSet: isDropSet, durationSeconds: durationSeconds,
                                               distanceMeters: distanceMeters)
    }
}

// MARK: - Undo snackbar

/// "Deleted · Undo" at the bottom of a form for a few seconds.
struct UndoSnackbar: View {
    var message: LocalizedStringKey = "deleted"
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 8)
            Button(action: onUndo) {
                Text("undo")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.apexMainColor)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("undo-button")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.apexBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Workout picker

/// Searchable list of all workouts to choose a training exercise, with the
/// user's favorites on top, then the ones that fit the training's name
/// (GET workouts/suggested). A swipe marks or unmarks a favorite.
/// A coach who can't find the exercise adds it here with just a name and
/// a category; it is picked right away and edited later in Workouts.
private struct WorkoutPickerView: View {
    let workouts: [Workout]
    let trainingName: String
    @Binding var selection: UUID?
    // Given when the user can add workouts: gets the new one.
    var onCreated: ((Workout) -> Void)? = nil
    var onToggleFavorite: ((Workout) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var suggestedIds: [UUID] = []
    @State private var isAddingWorkout = false
    // The workout just added, so the picker closes once its form is gone.
    @State private var createdWorkout: Workout?

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Suggestions while not searching, in the API's order (best first).
    private var suggested: [Workout] {
        guard searchText.isEmpty else { return [] }
        let byId = Dictionary(workouts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return suggestedIds.compactMap { byId[$0] }
    }

    // An API without favorites leaves isFavorite out: no section, no swipe.
    private var supportsFavorites: Bool {
        workouts.contains { $0.isFavorite != nil }
    }

    // The user's favorites the search finds, so the coach picks them fast.
    private var favorites: [Workout] {
        workouts.filter { $0.isFavoriteWorkout && $0.matches(searchText) }
    }

    var body: some View {
        List {
            if !favorites.isEmpty {
                Section {
                    ForEach(favorites) { row($0) }
                } header: {
                    Label("favorites", systemImage: "star.fill")
                }
            }
            if !suggested.isEmpty {
                Section {
                    ForEach(suggested) { row($0) }
                } header: {
                    Label("suggested_for_training", systemImage: "sparkles")
                }
            }
            Section {
                ShowMoreForEach(items: workouts.filter { $0.matches(searchText) }) { row($0) }
            } header: {
                if !suggested.isEmpty || !favorites.isEmpty {
                    Text("all_workouts")
                }
            }
            // At the end of the list, and the only row when the search finds nothing.
            if onCreated != nil {
                Section {
                    Button {
                        isAddingWorkout = true
                    } label: {
                        Label {
                            if trimmedSearch.isEmpty {
                                Text("add_new_exercise")
                            } else {
                                Text("add_new_exercise_named \(trimmedSearch)")
                            }
                        } icon: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .foregroundStyle(Color.apexMainColor)
                    }
                } footer: {
                    if !trimmedSearch.isEmpty && !workouts.isEmpty && !workouts.contains(where: { $0.matches(searchText) }) {
                        Text("no_exercise_found_add_hint")
                    }
                }
            }
        }
        .task {
            await loadSuggestions()
        }
        .sheet(isPresented: $isAddingWorkout, onDismiss: {
            if createdWorkout != nil {
                dismiss()
            }
        }) {
            QuickWorkoutForm(name: trimmedSearch) { created in
                onCreated?(created)
                selection = created.id
                createdWorkout = created
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

    private func row(_ workout: Workout) -> some View {
        Button {
            selection = workout.id
            dismiss()
        } label: {
            HStack {
                Text(verbatim: workout.name.localized)
                    .foregroundStyle(Color.primary)
                Spacer()
                if workout.isFavoriteWorkout {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Color.yellow)
                        .accessibilityLabel(Text("favorites"))
                }
                if workout.id == selection {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.apexMainColor)
                }
            }
        }
        .swipeActions(edge: .leading) {
            if supportsFavorites, let onToggleFavorite {
                Button {
                    onToggleFavorite(workout)
                } label: {
                    if workout.isFavoriteWorkout {
                        Label("remove_from_favorites", systemImage: "star.slash")
                    } else {
                        Label("add_to_favorites", systemImage: "star")
                    }
                }
                .tint(.yellow)
            }
        }
    }

    // Without suggestions (no name, or an API without them) the list is as before.
    @MainActor
    private func loadSuggestions() async {
        let name = trainingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              var components = URLComponents(url: AppEnvironment.apiURL.appendingPathComponent("workouts/suggested"),
                                             resolvingAgainstBaseURL: false) else { return }
        components.queryItems = [URLQueryItem(name: "name", value: name)]
        guard let url = components.url else { return }
        let ids: [UUID]? = try? await APIClient.shared.request(url)
        suggestedIds = ids ?? []
    }
}

// MARK: - Quick new workout

/// Short form to add a workout from the training form: only the name
/// (from the search) and the category. The API needs a description, so
/// the name stands in for it; muscles are guessed from the name. The rest
/// (description, video, types, muscles) is edited later in Workouts.
private struct QuickWorkoutForm: View {
    var onCreated: (Workout) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var name: String
    @State private var category: WorkoutCategory = .strengthConditioning
    @State private var isSaving = false
    @FocusState private var isNameFocused: Bool

    // Same limit as the workout form and the API.
    private static let maxNameLength = 60
    // ErrorCodes.AlreadyExists on the API.
    private static let duplicateErrorCode = "1300"

    init(name: String, onCreated: @escaping (Workout) -> Void) {
        self.onCreated = onCreated
        _name = State(initialValue: String(name.prefix(Self.maxNameLength)))
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && trimmedName.count <= Self.maxNameLength
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("name", text: $name)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if isValid && !isSaving {
                                Task { await save() }
                            }
                        }
                } header: {
                    Text("name")
                }

                Section {
                    Picker("category", selection: $category) {
                        ForEach(WorkoutCategory.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("category")
                } footer: {
                    Text("quick_new_exercise_hint")
                }
            }
            .navigationTitle("new_exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("add_to_training") {
                            Task { await save() }
                        }
                        .disabled(!isValid)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear {
                isNameFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    @MainActor
    private func save() async {
        guard isValid, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let text = LocalizedText(translations: ["HR": trimmedName])
        let request = UpdateWorkoutRequest(
            name: text,
            description: text,
            thumbnailUrl: "",
            videoUrl: "",
            workoutTypes: [],
            // Guessed from the name on the API.
            muscles: nil,
            secondaryMuscles: nil,
            isTimed: false,
            category: category.rawValue
        )

        do {
            let created: Workout = try await APIClient.shared.request(
                AppEnvironment.apiURL.appendingPathComponent("workouts"),
                method: .post,
                body: JSONEncoder().encode(request)
            )
            onCreated(created)
            toastManager.show("exercise_added_to_training", type: .success)
            dismiss()
        } catch ApiError.validation(let response)
                    where response.errors?["generalErrors"]?.contains(Self.duplicateErrorCode) == true {
            toastManager.show("workout_duplicate", type: .error)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

#Preview {
    TrainingFormView(clientId: UUID(), history: [])
        .environmentObject(ToastManager())
        .environmentObject(AuthManager())
}
