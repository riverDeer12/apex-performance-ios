//
//  CompletedTrainingsView.swift
//  ApexPerformance
//

import SwiftUI

/// Client's tab with the trainings their coach marked as completed.
struct CompletedTrainingsView: View {

    @State private var trainings: [Training] = []
    // Used for the exercise pictures.
    @State private var workouts: [UUID: Workout] = [:]
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var hasLoaded = false

    @EnvironmentObject private var toastManager: ToastManager

    private var filteredTrainings: [Training] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return trainings }
        return trainings.filter { training in
            training.name.localizedStandardContains(query)
                || training.exercises.contains { $0.workoutName.allValues.contains { $0.localizedStandardContains(query) } }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ApexScreenHeader(title: "my_trainings")
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    searchField
                        .padding(.horizontal, 20)

                    if filteredTrainings.isEmpty, !isLoading {
                        CardView {
                            (searchText.isEmpty ? Text("no_client_trainings") : Text("no_trainings_found"))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        }
                        .padding(.horizontal, 20)
                    } else {
                        // Planned trainings are for the coach, the API only returns completed ones.
                        trainingsSection(title: "completed_trainings", trainings: completedTrainings)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color.apexBackground)
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

    private var completedTrainings: [Training] {
        filteredTrainings.filter(\.isCompleted)
    }

    @ViewBuilder
    private func trainingsSection(title: LocalizedStringKey, trainings: [Training]) -> some View {
        if !trainings.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .apexLabel()

                LazyVStack(spacing: 12) {
                    ForEach(trainings) { training in
                        NavigationLink {
                            TrainingDetailView(training: training, heroImageURL: imageURL(for: training))
                        } label: {
                            TrainingCardView(training: training, imageURL: imageURL(for: training))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("training-row")
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("search_trainings", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(Text("clear"))
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .frame(height: 44)
        .apexCardBackground(cornerRadius: 10)
    }

    /// Picture of the training's first exercise, when the workout has one.
    private func imageURL(for training: Training) -> URL? {
        training.exercises
            .sorted { $0.order < $1.order }
            .lazy
            .compactMap { self.workouts[$0.workoutId]?.thumbnailUrl }
            .compactMap { URL(string: $0) }
            .first
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

        // Only pictures, the list works without them.
        if workouts.isEmpty {
            let url = AppEnvironment.apiURL.appendingPathComponent("workouts")
            if let loaded: [Workout] = try? await APIClient.shared.request(url) {
                workouts = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            }
        }
    }
}

/// Training card with a picture, date and its exercises.
struct TrainingCardView: View {
    let training: Training
    var imageURL: URL? = nil

    private var exerciseNames: [String] {
        training.exercises
            .sorted { $0.order < $1.order }
            .map(\.workoutName.localized)
    }

    var body: some View {
        HStack(spacing: 14) {
            ApexPictureBackground(imageURL: imageURL)
                .frame(width: 96, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(verbatim: DateFormatter.dateWithDots.string(from: training.date))
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1)

                    if !training.isCompleted {
                        Text("planned")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                    }
                }

                Text(verbatim: training.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(exerciseNames.prefix(3).enumerated()), id: \.offset) { _, name in
                        Text(verbatim: name)
                            .lineLimit(1)
                    }
                    if exerciseNames.count > 3 {
                        Text(verbatim: "+\(exerciseNames.count - 3)")
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.apexAccent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .apexCardBackground()
        .contentShape(Rectangle())
    }
}

/// Rows of trainings that open their details, used on the client's
/// tab and on client details for coaches.
struct TrainingRowsView: View {
    let trainings: [Training]
    // Set for staff: trainings can then be edited, marked as completed
    // or deleted. Long press a row for the quick actions.
    var onSaved: ((Training) -> Void)? = nil
    var onDeleted: ((UUID) -> Void)? = nil

    @EnvironmentObject private var toastManager: ToastManager
    @State private var trainingToDelete: Training?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(trainings) { training in
                NavigationLink {
                    TrainingDetailView(training: training, history: trainings, onSaved: onSaved, onDeleted: onDeleted)
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
                .contextMenu {
                    if onSaved != nil {
                        Button {
                            Task { await toggleCompletion(training) }
                        } label: {
                            completionLabel(isCompleted: training.isCompleted)
                        }

                        Button(role: .destructive) {
                            trainingToDelete = training
                        } label: {
                            Label("delete_training", systemImage: "trash")
                        }
                    }
                }

                if training.id != trainings.last?.id {
                    Divider().padding(.leading, 52)
                }
            }
        }
        .confirmationDialog(
            "delete_training_question",
            isPresented: Binding(
                get: { trainingToDelete != nil },
                set: { if !$0 { trainingToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: trainingToDelete
        ) { training in
            Button("delete", role: .destructive) {
                Task { await delete(training) }
            }
            Button("cancel", role: .cancel) {}
        }
    }

    @MainActor
    private func toggleCompletion(_ training: Training) async {
        do {
            let updated = try await training.settingCompletion(!training.isCompleted)
            onSaved?(updated)
            toastManager.show(
                updated.isCompleted ? "training_marked_completed" : "training_marked_planned",
                type: .success
            )
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func delete(_ training: Training) async {
        do {
            try await Training.delete(id: training.id)
            onDeleted?(training.id)
            toastManager.show("training_deleted_successfully", type: .success)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

/// "Mark as completed" or "Mark as planned", depending on the current state.
@ViewBuilder
func completionLabel(isCompleted: Bool) -> some View {
    if isCompleted {
        Label("mark_as_planned", systemImage: "arrow.uturn.backward.circle")
    } else {
        Label("mark_as_completed", systemImage: "checkmark.circle")
    }
}

/// Exercises and sets of one training. Staff can edit it.
struct TrainingDetailView: View {
    @State private var training: Training
    private let heroImageURL: URL?
    // Client's trainings, for the "last time" sets while editing.
    private let history: [Training]
    private let onSaved: ((Training) -> Void)?
    private let onDeleted: ((UUID) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var showEditSheet = false
    @State private var showCopySheet = false
    @State private var showDeleteDialog = false
    @State private var isUpdating = false
    // "Save as template" asks for the template's name.
    @State private var showSaveAsTemplate = false
    @State private var templateName = ""

    init(training: Training, heroImageURL: URL? = nil, history: [Training] = [],
         onSaved: ((Training) -> Void)? = nil, onDeleted: ((UUID) -> Void)? = nil) {
        _training = State(initialValue: training)
        self.heroImageURL = heroImageURL
        self.history = history
        self.onSaved = onSaved
        self.onDeleted = onDeleted
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ApexPictureBackground(imageURL: heroImageURL)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: DateFormatter.dateWithDots.string(from: training.date))
                        .font(.system(size: 15, weight: .bold))
                        .tracking(1)
                    Text(verbatim: training.name)
                        .apexTitle()
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

                if training.exercises.isEmpty {
                    CardView {
                        Text("no_exercises")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                }

                TrainingExerciseCards(exercises: training.exercises)

                if let note = training.note, !note.isEmpty {
                    CardView(title: "notes") {
                        Text(verbatim: note)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.apexBackground)
        .navigationTitle(Text(verbatim: training.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onSaved != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("edit_training", systemImage: "pencil")
                        }

                        Button {
                            Task { await toggleCompletion() }
                        } label: {
                            completionLabel(isCompleted: training.isCompleted)
                        }

                        Button {
                            showCopySheet = true
                        } label: {
                            Label("copy_training", systemImage: "doc.on.doc")
                        }

                        Button {
                            templateName = training.name
                            showSaveAsTemplate = true
                        } label: {
                            Label("save_as_template", systemImage: "bookmark")
                        }

                        if onDeleted != nil {
                            Button(role: .destructive) {
                                showDeleteDialog = true
                            } label: {
                                Label("delete_training", systemImage: "trash")
                            }
                        }
                    } label: {
                        if isUpdating {
                            ProgressView()
                        } else {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(Color.apexMainColor)
                        }
                    }
                    .disabled(isUpdating)
                    .accessibilityLabel(Text("training_actions"))
                }
            }
        }
        .alert("save_as_template", isPresented: $showSaveAsTemplate) {
            TextField("name", text: $templateName)
            Button("save") {
                Task { await saveAsTemplate() }
            }
            .disabled(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("cancel", role: .cancel) {}
        } message: {
            Text("save_as_template_hint")
        }
        .confirmationDialog("delete_training_question", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("delete", role: .destructive) {
                Task { await delete() }
            }
            Button("cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditSheet) {
            TrainingFormView(clientId: training.client.id, training: training, history: history) { saved in
                training = saved
                onSaved?(saved)
            }
        }
        .sheet(isPresented: $showCopySheet) {
            // The copy is a new training, so it is only added to the list.
            TrainingFormView(copying: training, history: history) { saved in
                onSaved?(saved)
            }
        }
    }

    @MainActor
    private func toggleCompletion() async {
        isUpdating = true
        defer { isUpdating = false }

        do {
            let updated = try await training.settingCompletion(!training.isCompleted)
            training = updated
            onSaved?(updated)
            toastManager.show(
                updated.isCompleted ? "training_marked_completed" : "training_marked_planned",
                type: .success
            )
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func saveAsTemplate() async {
        isUpdating = true
        defer { isUpdating = false }

        let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await TrainingTemplate.save(SaveTrainingTemplateRequest(name: name, training: training))
            toastManager.show("template_created", type: .success)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func delete() async {
        isUpdating = true
        defer { isUpdating = false }

        do {
            try await Training.delete(id: training.id)
            onDeleted?(training.id)
            toastManager.show("training_deleted_successfully", type: .success)
            dismiss()
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

/// Cards of a training's or template's exercises with their sets,
/// numbered "1.", "2a", "2b"... like the web.
struct TrainingExerciseCards: View {
    let exercises: [Training.Exercise]

    var body: some View {
        let sorted = exercises.sorted { $0.order < $1.order }
        let labels = SupersetLabels.labels(linked: sorted.map(\.isSupersetWithPrevious))
        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, exercise in
            let isInSuperset = exercise.isSupersetWithPrevious
                || (index + 1 < sorted.count && sorted[index + 1].isSupersetWithPrevious)
            exerciseCard(exercise, label: labels[index], isInSuperset: isInSuperset)
                .padding(.horizontal, 20)
        }
    }

    private func exerciseCard(_ exercise: Training.Exercise, label: String, isInSuperset: Bool) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 0) {
                if isInSuperset {
                    // Exercises of a superset are done one after another without rest.
                    Text("superset")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.apexOnAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.apexAccent))
                        .padding(.bottom, 6)
                }

                Text(verbatim: "\(label) \(exercise.workoutName.localized)")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .padding(.bottom, 10)

                let sets = exercise.sets.sorted { $0.order < $1.order }
                if !sets.isEmpty {
                    setRow(Text("set"), Text("reps"), Text("kg"), isHeader: true)
                }
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    Divider().overlay(Color.apexBorder)
                    setRow(
                        Text(verbatim: "\(index + 1)"),
                        Text(verbatim: set.reps?.trimmingCharacters(in: .whitespaces).nilIfEmpty ?? "—"),
                        Text(verbatim: set.weight.map(Self.formatWeight) ?? "—")
                    )
                }

                if let note = exercise.note, !note.isEmpty {
                    Text(verbatim: note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Row of the sets table: set number, repetitions and weight.
    private func setRow(_ set: Text, _ reps: Text, _ weight: Text, isHeader: Bool = false) -> some View {
        HStack {
            set.frame(width: 56, alignment: .leading)
            reps.frame(maxWidth: .infinity, alignment: .leading)
            weight.frame(width: 64, alignment: .trailing)
        }
        .font(isHeader ? .system(size: 11, weight: .semibold) : .subheadline)
        .tracking(isHeader ? 1 : 0)
        .textCase(isHeader ? .uppercase : nil)
        .foregroundStyle(isHeader ? Color.secondary : Color.primary)
        .padding(.vertical, isHeader ? 6 : 9)
    }

    private static func formatWeight(_ weight: Decimal) -> String {
        NSDecimalNumber(decimal: weight).doubleValue.formatted(.number.precision(.fractionLength(0...2)))
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
    .environmentObject(ToastManager())
}
