//
//  WorkoutDetailView.swift
//  ApexPerformance
//

import SwiftUI

struct WorkoutDetailView: View {

    @State private var workout: Workout
    @State private var isPlayingVideo = false
    let canEdit: Bool
    var onSaved: (Workout) -> Void

    init(workout: Workout, canEdit: Bool, onSaved: @escaping (Workout) -> Void) {
        self._workout = State(initialValue: workout)
        self.canEdit = canEdit
        self.onSaved = onSaved
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
                        Text("—")
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
        .background(Color(.systemGroupedBackground))
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
            }
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
