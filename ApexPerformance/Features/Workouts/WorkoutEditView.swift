//
//  WorkoutEditView.swift
//  ApexPerformance
//

import SwiftUI

/// Edits a workout, or creates a new one when no workout is given.
struct WorkoutEditView: View {

    // nil when creating a new workout.
    let workout: Workout?
    var onSaved: (Workout) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var nameHr: String
    @State private var nameEn: String
    @State private var descriptionHr: String
    @State private var descriptionEn: String
    @State private var videoUrl: String
    @State private var thumbnailUrl: String
    @State private var selectedWorkoutTypeIds: Set<UUID>
    @State private var muscles: [String: MuscleRole]
    // Sets record a duration instead of repetitions (e.g. plank).
    @State private var isTimed: Bool
    @State private var category: WorkoutCategory
    // Picked by the coach, then picking a type no longer changes it.
    @State private var isCategoryPicked: Bool

    @State private var workoutTypes: [WorkoutType] = []
    @State private var isSaving = false
    @State private var isConfirmingDiscard = false

    // Same limit and link formats the web form and API accept.
    private static let maxNameLength = 60
    private static let youtubePattern =
        #"^https?://((www|m)\.)?(youtube\.com/(watch\?(.*&)?v=|shorts/|embed/|live/)|youtu\.be/)[\w-]+"#

    // ErrorCodes.AlreadyExists on the API.
    private static let duplicateErrorCode = "1300"

    init(workout: Workout? = nil, onSaved: @escaping (Workout) -> Void) {
        self.workout = workout
        self.onSaved = onSaved
        _nameHr = State(initialValue: workout?.name.value(for: "HR") ?? "")
        _nameEn = State(initialValue: workout?.name.value(for: "EN") ?? "")
        _descriptionHr = State(initialValue: workout?.description.value(for: "HR") ?? "")
        _descriptionEn = State(initialValue: workout?.description.value(for: "EN") ?? "")
        _videoUrl = State(initialValue: workout?.videoUrl ?? "")
        _thumbnailUrl = State(initialValue: workout?.thumbnailUrl ?? "")
        _selectedWorkoutTypeIds = State(initialValue: Set(workout?.workoutTypes.map(\.id) ?? []))
        _muscles = State(initialValue: Self.roles(of: workout))
        _isTimed = State(initialValue: workout?.isTimed ?? false)
        _category = State(initialValue: workout?.workoutCategory ?? .strengthConditioning)
        _isCategoryPicked = State(initialValue: workout != nil)
    }

    private var isNew: Bool {
        workout == nil
    }

    private var isVideoUrlValid: Bool {
        videoUrl.trimmingCharacters(in: .whitespaces)
            .range(of: Self.youtubePattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private var isValid: Bool {
        let trimmedNameHr = nameHr.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedNameHr.isEmpty
            && trimmedNameHr.count <= Self.maxNameLength
            && nameEn.trimmingCharacters(in: .whitespacesAndNewlines).count <= Self.maxNameLength
            && !descriptionHr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            // The video and thumbnail are optional, like on the API; a link must be valid.
            && (isVideoUrlValid || videoUrl.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // Asked before closing when the form has unsaved changes.
    private var hasChanges: Bool {
        nameHr != (workout?.name.value(for: "HR") ?? "") || nameEn != (workout?.name.value(for: "EN") ?? "")
            || descriptionHr != (workout?.description.value(for: "HR") ?? "")
            || descriptionEn != (workout?.description.value(for: "EN") ?? "")
            || videoUrl != (workout?.videoUrl ?? "") || thumbnailUrl != (workout?.thumbnailUrl ?? "")
            || selectedWorkoutTypeIds != Set(workout?.workoutTypes.map(\.id) ?? [])
            || muscles != Self.roles(of: workout)
            || isTimed != (workout?.isTimed ?? false)
            || category != (workout?.workoutCategory ?? .strengthConditioning)
    }

    private static func roles(of workout: Workout?) -> [String: MuscleRole] {
        var roles: [String: MuscleRole] = [:]
        for muscle in workout?.secondaryMuscles ?? [] { roles[muscle] = .secondary }
        for muscle in workout?.muscles ?? [] { roles[muscle] = .primary }
        return roles
    }

    // In the API's order, which the body map also uses.
    private func selectedMuscles(_ role: MuscleRole) -> [String] {
        WorkoutMuscle.all.filter { muscles[$0] == role }
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
        Form {
            Section("name") {
                TextField("croatian", text: $nameHr)
                TextField("english", text: $nameEn)
            }

            Section("description") {
                TextField("croatian", text: $descriptionHr, axis: .vertical)
                    .lineLimit(3...8)
                TextField("english", text: $descriptionEn, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section {
                TextField("video_url", text: $videoUrl)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("video_url")
            } footer: {
                if !videoUrl.isEmpty && !isVideoUrlValid {
                    Text("invalid_youtube_url")
                        .foregroundStyle(.red)
                }
            }

            Section {
                TextField("thumbnail_url", text: $thumbnailUrl)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("thumbnail_url")
            } footer: {
                Text("thumbnail_url_hint")
            }

            Section {
                MuscleMapView(primary: selectedMuscles(.primary), secondary: selectedMuscles(.secondary))
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                ForEach(WorkoutMuscle.all, id: \.self) { muscle in
                    Picker(selection: $muscles[muscle]) {
                        Text("muscle_not_worked").tag(MuscleRole?.none)
                        Text("primary_muscle").tag(MuscleRole?.some(.primary))
                        Text("secondary_muscle").tag(MuscleRole?.some(.secondary))
                    } label: {
                        Text(WorkoutMuscle.name(muscle))
                    }
                    .pickerStyle(.menu)
                    .tint(muscles[muscle] == nil ? Color.secondary : Color.apexMainColor)
                }
            } header: {
                Text("worked_muscles")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if isNew {
                        Text("muscles_guess_hint")
                    }
                    Text("full_body_muscles_hint")
                }
            }

            Section {
                Toggle("timed_workout", isOn: $isTimed)
                    .tint(Color.apexMainColor)
            } footer: {
                Text("timed_workout_hint")
            }

            Section {
                Picker("category", selection: Binding(
                    get: { category },
                    set: { category = $0; isCategoryPicked = true }
                )) {
                    ForEach(WorkoutCategory.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("category")
            }

            Section("workout_types") {
                if workoutTypes.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(workoutTypes) { workoutType in
                        Button {
                            toggle(workoutType.id)
                        } label: {
                            HStack {
                                Text(workoutType.name.localized)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedWorkoutTypeIds.contains(workoutType.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.apexMainColor)
                                        .fontWeight(.semibold)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .confirmsDiscardingChanges(hasChanges, isConfirming: $isConfirmingDiscard, replacesBackButton: true) {
            dismiss()
        }
        .navigationTitle(isNew ? LocalizedStringKey("new_workout") : LocalizedStringKey("edit_workout"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(!isValid || isSaving)
            }
        }
        .task {
            await loadWorkoutTypes()
        }
    }

    private func toggle(_ id: UUID) {
        if selectedWorkoutTypeIds.contains(id) {
            selectedWorkoutTypeIds.remove(id)
        } else {
            selectedWorkoutTypeIds.insert(id)
            Task { await markFullBodyMuscles() }
            // A new workout with a mobility or stretching type is in that category.
            if !isCategoryPicked, let type = workoutTypes.first(where: { $0.id == id }),
               Workout.isMobilityOrStretching(type) {
                category = .mobilityFlexibility
            }
        }
    }

    /// A full body type was picked: marks the muscles the exercise works,
    /// guessed by the API from the name. Muscles already marked stay.
    @MainActor
    private func markFullBodyMuscles() async {
        let empty = LocalizedText(translations: [:])
        let request = GuessMusclesRequest(
            name: localizedText(from: workout?.name ?? empty, hr: nameHr, en: nameEn),
            workoutTypes: Array(selectedWorkoutTypeIds)
        )
        guard let guessed: GuessMusclesResponse = try? await APIClient.shared.request(
            AppEnvironment.apiURL.appendingPathComponent("workouts/guess-muscles"),
            method: .post,
            body: JSONEncoder().encode(request)
        ), guessed.isFullBody else { return }

        let groups: [([String], MuscleRole)] = [(guessed.muscles, .primary), (guessed.secondaryMuscles, .secondary)]
        var marked = 0
        for (codes, role) in groups {
            for muscle in codes where muscles[muscle] == nil && WorkoutMuscle.all.contains(muscle) {
                muscles[muscle] = role
                marked += 1
            }
        }
        if marked > 0 {
            toastManager.show("full_body_muscles_marked", type: .success)
        }
    }

    // Only HR and EN are editable; other translations (e.g. IT) are kept.
    private func localizedText(from existing: LocalizedText, hr: String, en: String) -> LocalizedText {
        var translations = existing.translations
        translations["HR"] = hr.trimmingCharacters(in: .whitespacesAndNewlines)

        let trimmedEn = en.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEn.isEmpty {
            translations.removeValue(forKey: "EN")
        } else {
            translations["EN"] = trimmedEn
        }

        return LocalizedText(translations: translations)
    }

    @MainActor
    private func loadWorkoutTypes() async {
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("workout-types")
            let response: [WorkoutType] = try await APIClient.shared.request(url)
            workoutTypes = response.sorted {
                $0.name.localized.localizedStandardCompare($1.name.localized) == .orderedAscending
            }
        } catch is CancellationError {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let empty = LocalizedText(translations: [:])
        let request = UpdateWorkoutRequest(
            name: localizedText(from: workout?.name ?? empty, hr: nameHr, en: nameEn),
            description: localizedText(from: workout?.description ?? empty, hr: descriptionHr, en: descriptionEn),
            // An empty thumbnail is generated from the YouTube video on the API.
            thumbnailUrl: thumbnailUrl.trimmingCharacters(in: .whitespaces),
            videoUrl: videoUrl.trimmingCharacters(in: .whitespaces),
            workoutTypes: Array(selectedWorkoutTypeIds),
            muscles: isNew && muscles.isEmpty ? nil : selectedMuscles(.primary),
            secondaryMuscles: isNew && muscles.isEmpty ? nil : selectedMuscles(.secondary),
            isTimed: isTimed,
            category: category.rawValue
        )

        do {
            var url = AppEnvironment.apiURL.appendingPathComponent("workouts")
            if let workout {
                url = url.appendingPathComponent(workout.id.uuidString)
            }
            let saved: Workout = try await APIClient.shared.request(
                url,
                method: isNew ? .post : .put,
                body: JSONEncoder().encode(request)
            )

            onSaved(saved)
            toastManager.show(
                isNew ? "workout_created_successfully" : "workout_updated_successfully",
                type: .success
            )
            dismiss()
        } catch ApiError.validation(let response)
                    where response.errors?["generalErrors"]?.contains(Self.duplicateErrorCode) == true {
            toastManager.show("workout_duplicate", type: .error)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}
