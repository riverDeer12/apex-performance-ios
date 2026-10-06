//
//  WorkoutDetailView.swift
//  ApexPerformance
//

import SwiftUI

struct WorkoutDetailView: View {

    @State private var workout: Workout
    @State private var isPlayingVideo = false
    @State private var showDeleteDialog = false
    @State private var isDeleting = false
    let canEdit: Bool
    var onSaved: (Workout) -> Void
    var onDeleted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    init(workout: Workout, canEdit: Bool, onSaved: @escaping (Workout) -> Void, onDeleted: (() -> Void)? = nil) {
        self._workout = State(initialValue: workout)
        self.canEdit = canEdit
        self.onSaved = onSaved
        self.onDeleted = onDeleted
    }

    private var videoId: String? {
        YouTubeVideo.id(from: workout.videoUrl)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                videoArea
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Text(workout.name.localized)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                CardView(title: "workout_types") {
                    if workout.workoutTypes.isEmpty {
                        Text(verbatim: "—")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(workout.workoutTypes) { workoutType in
                                    Text(workoutType.name.localized)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.apexMainColor.opacity(0.12))
                                        .foregroundStyle(Color.apexMainColor)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                CardView(title: "description") {
                    Text(workout.description.localized.isEmpty ? "—" : workout.description.localized)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 24)
        }
        .background(Color.apexBackground)
        .navigationTitle(Text(workout.name.localized))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        WorkoutEditView(workout: workout) { updated in
                            workout = updated
                            isPlayingVideo = false
                            onSaved(updated)
                        }
                    } label: {
                        Text("edit")
                            .foregroundStyle(Color.apexMainColor)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteDialog = true
                    } label: {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                    .accessibilityLabel("delete_workout")
                    .disabled(isDeleting)
                }
            }
        }
        .confirmationDialog("delete_workout_question", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("delete", role: .destructive) {
                Task { await deleteWorkout() }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("can_not_be_undone")
        }
    }

    @MainActor
    private func deleteWorkout() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await Workout.delete(id: workout.id)
            toastManager.show("workout_deleted_successfully", type: .success)
            onDeleted?()
            dismiss()
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    // Shows the thumbnail until tapped, then plays the video in place.
    @ViewBuilder
    private var videoArea: some View {
        let frame = Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .frame(maxWidth: .infinity)

        if isPlayingVideo, let videoId {
            frame
                .overlay { YouTubePlayerView(videoId: videoId).id(videoId) }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            let thumbnail = frame
                .overlay { WorkoutThumbnailView(url: workout.thumbnailUrl) }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    if videoId != nil {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.white, .black.opacity(0.45))
                    }
                }

            if videoId != nil {
                Button {
                    isPlayingVideo = true
                } label: {
                    thumbnail
                }
                .buttonStyle(.plain)
            } else {
                thumbnail
            }
        }
    }
}
