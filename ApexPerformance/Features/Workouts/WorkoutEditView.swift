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

    @State private var workoutTypes: [WorkoutType] = []
    @State private var isSaving = false

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
            // The API accepts a new workout without a video, it can be added later.
            && (isVideoUrlValid || (isNew && videoUrl.trimmingCharacters(in: .whitespaces).isEmpty))
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
            workoutTypes: Array(selectedWorkoutTypeIds)
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
