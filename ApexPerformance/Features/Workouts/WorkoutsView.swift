//
//  WorkoutsView.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 29.12.2025..
//

import SwiftUI
import UniformTypeIdentifiers

struct WorkoutsView: View {

    @State private var workouts: [Workout] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var showFileImporter = false
    @State private var isImporting = false
    // Workout picked for deletion from the long-press menu.
    @State private var workoutToDelete: Workout?

    @EnvironmentObject private var toastManager: ToastManager
    @EnvironmentObject private var authManager: AuthManager

    // Same audience as the web: coaches and administrators manage workouts.
    private var canManageWorkouts: Bool {
        !authManager.hasRole(role: "Client")
    }

    private var filteredWorkouts: [Workout] {
        workouts
            .filter { $0.matches(searchText) }
            .sorted { $0.name.localized.localizedStandardCompare($1.name.localized) == .orderedAscending }
    }

    // The template is served by the web app on the same host as the API.
    private var importTemplateURL: URL {
        AppEnvironment.apiURL
            .deletingLastPathComponent()
            .appendingPathComponent("assets/templates/workouts-import-template.xlsx")
    }

    private static let xlsxType = UTType(filenameExtension: "xlsx") ?? .data

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text("workouts")
                            .font(.title.bold())
                        Text("workouts_subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    if canManageWorkouts {
                        importSection
                            .padding(.horizontal, 20)
                    }

                    searchField
                        .padding(.horizontal, 20)

                    CardView {
                        if filteredWorkouts.isEmpty, !isLoading {
                            (searchText.isEmpty ? Text("no_workouts") : Text("no_workouts_found"))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredWorkouts) { workout in
                                    NavigationLink(value: workout) {
                                        workoutRow(workout)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        if canManageWorkouts {
                                            Button("delete_workout", systemImage: "trash", role: .destructive) {
                                                workoutToDelete = workout
                                            }
                                        }
                                    }

                                    if workout.id != filteredWorkouts.last?.id {
                                        Divider().padding(.leading, 108)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .overlay {
                if isLoading && workouts.isEmpty {
                    ProgressView()
                }
            }
            .refreshable {
                // Own task so the request isn't cancelled when the
                // view updates during pull-to-refresh.
                await Task { await loadWorkouts() }.value
            }
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                await loadWorkouts()
            }
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout, canEdit: canManageWorkouts) { updated in
                    if let index = workouts.firstIndex(where: { $0.id == updated.id }) {
                        workouts[index] = updated
                    }
                } onDeleted: {
                    workouts.removeAll { $0.id == workout.id }
                }
            }
            .confirmationDialog(
                "delete_workout_question",
                isPresented: Binding(
                    get: { workoutToDelete != nil },
                    set: { if !$0 { workoutToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: workoutToDelete
            ) { workout in
                Button("delete", role: .destructive) {
                    Task { await deleteWorkout(workout) }
                }
                Button("cancel", role: .cancel) {}
            } message: { _ in
                Text("can_not_be_undone")
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [Self.xlsxType]) { result in
                Task { await importWorkouts(from: result) }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var importSection: some View {
        HStack(spacing: 12) {
            Button {
                showFileImporter = true
            } label: {
                HStack(spacing: 6) {
                    if isImporting {
                        ProgressView()
                            .tint(Color(.systemBackground))
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text("import_workouts")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.apexMainColor)
                // apexMainColor is white in dark mode.
                .foregroundStyle(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isImporting)

            Link(destination: importTemplateURL) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                    Text("download_template")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(Color.apexMainColor)
                .background(Color.apexMainColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("search_workouts", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private func workoutRow(_ workout: Workout) -> some View {
        HStack(spacing: 12) {
            WorkoutThumbnailView(url: workout.thumbnailUrl)
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name.localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !workout.workoutTypes.isEmpty {
                    Text(workout.workoutTypes.map { $0.name.localized }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    @MainActor
    private func loadWorkouts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("workouts")
            workouts = try await APIClient.shared.request(url)
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func deleteWorkout(_ workout: Workout) async {
        do {
            try await Workout.delete(id: workout.id)
            workouts.removeAll { $0.id == workout.id }
            toastManager.show("workout_deleted_successfully", type: .success)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    // Uploads the file only; the API validates and saves rows in a background
    // job and emails the result to the user, same as the web import.
    @MainActor
    private func importWorkouts(from result: Result<URL, Error>) async {
        guard case .success(let fileURL) = result else { return }

        isImporting = true
        defer { isImporting = false }

        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { fileURL.stopAccessingSecurityScopedResource() }
        }

        do {
            let fileData = try Data(contentsOf: fileURL)
            let boundary = "Boundary-\(UUID().uuidString)"

            var body = Data()
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".utf8))
            body.append(Data("Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n".utf8))
            body.append(fileData)
            body.append(Data("\r\n--\(boundary)--\r\n".utf8))

            let url = AppEnvironment.apiURL.appendingPathComponent("workouts/import")
            let _: ImportWorkoutsResponse = try await APIClient.shared.request(
                url,
                method: .post,
                body: body,
                headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"]
            )

            toastManager.show("workouts_import_started", type: .success)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

struct WorkoutThumbnailView: View {
    let url: String?

    var body: some View {
        AsyncImage(url: url.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                ZStack {
                    Color.apexMainColor.opacity(0.12)
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(Color.apexMainColor)
                }
            }
        }
        .clipped()
    }
}

#Preview {
    WorkoutsView()
        .environmentObject(AuthManager())
        .environmentObject(ToastManager())
}
