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
    // Nil shows all workouts.
    @State private var category: WorkoutCategory?
    @State private var isLoading = false
    @State private var showFileImporter = false
    @State private var isImporting = false
    // Workout picked for deletion from the long-press menu.
    @State private var workoutToDelete: Workout?
    @State private var showCreateWorkout = false

    // Clients open the library from home, limited by their plan.
    private let workoutFilter: ((Workout) -> Bool)?
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey
    // False when pushed inside another navigation stack.
    private let wrapsInNavigationStack: Bool

    init(workoutFilter: ((Workout) -> Bool)? = nil,
         title: LocalizedStringKey = "workouts",
         subtitle: LocalizedStringKey = "workouts_subtitle",
         wrapsInNavigationStack: Bool = true) {
        self.workoutFilter = workoutFilter
        self.title = title
        self.subtitle = subtitle
        self.wrapsInNavigationStack = wrapsInNavigationStack
    }

    @EnvironmentObject private var toastManager: ToastManager
    @EnvironmentObject private var authManager: AuthManager

    // Same audience as the web: coaches and administrators manage workouts.
    private var canManageWorkouts: Bool {
        !authManager.hasRole(role: "Client")
    }

    // Workouts the user may see, before the category and search.
    private var visibleWorkouts: [Workout] {
        workouts.filter { workoutFilter?($0) ?? true }
    }

    // Clients who see only mobility workouts don't need the filter.
    private var showsCategoryFilter: Bool {
        Set(visibleWorkouts.map(\.workoutCategory)).count > 1
    }

    private var filteredWorkouts: [Workout] {
        visibleWorkouts
            .filter { category == nil || $0.workoutCategory == category }
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
        if wrapsInNavigationStack {
            NavigationStack {
                content
                    .chatToolbarButton()
            }
        } else {
            content
        }
    }

    private var content: some View {
            ScrollView {
                VStack(spacing: 16) {

                    ApexScreenHeader(title: title, subtitle: subtitle)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    searchField
                        .padding(.horizontal, 20)

                    if showsCategoryFilter {
                        categoryFilter
                            .padding(.horizontal, 20)
                    }

                    CardView {
                        if filteredWorkouts.isEmpty, !isLoading {
                            (searchText.isEmpty && category == nil ? Text("no_workouts") : Text("no_workouts_found"))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            LazyVStack(spacing: 0) {
                                ShowMoreForEach(items: filteredWorkouts) { workout in
                                    // Destination link, not a value link: the library is also
                                    // pushed from the client's home, where a value destination
                                    // registered in the pushed view only opened after going back.
                                    NavigationLink {
                                        workoutDetail(workout)
                                    } label: {
                                        workoutRow(workout)
                                    }
                                    .buttonStyle(.apexPlain)
                                    .accessibilityIdentifier("workout-row")
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
            .background(Color.apexBackground)
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
            // Fresh data every time the screen is shown, not only after pulling
            // to refresh. Own task, so leaving the screen doesn't cancel it.
            .task {
                await Task { await loadWorkouts() }.value
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
            .toolbar {
                if canManageWorkouts {
                    ToolbarItem(placement: .topBarTrailing) {
                        addMenu
                    }
                }
            }
            .navigationDestination(isPresented: $showCreateWorkout) {
                WorkoutEditView { created in
                    workouts.append(created)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
    }

    private func workoutDetail(_ workout: Workout) -> some View {
        WorkoutDetailView(workout: workout, canEdit: canManageWorkouts) { updated in
            if let index = workouts.firstIndex(where: { $0.id == updated.id }) {
                workouts[index] = updated
            }
        } onDeleted: {
            workouts.removeAll { $0.id == workout.id }
        }
    }
    
    /// "+" in the top bar: new workout, import from Excel and its template.
    private var addMenu: some View {
        Menu {
            Button {
                showCreateWorkout = true
            } label: {
                Label("new_workout", systemImage: "plus")
            }
            Button {
                showFileImporter = true
            } label: {
                Label("import_workouts", systemImage: "square.and.arrow.down")
            }
            .disabled(isImporting)
            Link(destination: importTemplateURL) {
                Label("download_template", systemImage: "doc.text")
            }
        } label: {
            if isImporting {
                ProgressView()
            } else {
                Image(systemName: "plus")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.apexMainColor)
            }
        }
        .accessibilityLabel(Text("new_workout"))
        .accessibilityIdentifier("workouts-add-menu")
    }

    // Workouts per category among the ones the search finds.
    private func count(of category: WorkoutCategory) -> Int {
        visibleWorkouts.filter { $0.workoutCategory == category && $0.matches(searchText) }.count
    }

    /// Two buttons, one per category: a tapped one shows only its workouts,
    /// tapped again all of them.
    private var categoryFilter: some View {
        HStack(spacing: 8) {
            ForEach(WorkoutCategory.allCases) { option in
                let isSelected = category == option
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        category = isSelected ? nil : option
                    }
                } label: {
                    // e.g. "Mobility and flexibility · 11".
                    Label {
                        Text(option.title) + Text(verbatim: " · \(count(of: option))")
                    } icon: {
                        Image(systemName: option.systemImage)
                    }
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 8)
                        // Dark text on the selected button's sky blue.
                        .foregroundStyle(isSelected ? Color.apexOnAccent : Color.apexMainColor)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? Color.apexMainColor : Color.apexMainColor.opacity(0.1))
                        )
                }
                .buttonStyle(.apexPlain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("category-\(option.rawValue)")
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
                .buttonStyle(.apexPlain)
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
            WorkoutThumbnailView(url: workout.thumbnailUrl, category: workout.workoutCategory)
                .frame(width: 96, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name.localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Primary muscles as on the muscle map, otherwise the types.
                if let muscles = workout.muscles, !muscles.isEmpty {
                    Text(muscles.map { String(localized: String.LocalizationValue("muscle_" + $0)) }
                        .joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else if !workout.workoutTypes.isEmpty {
                    Text(workout.workoutTypes.map { $0.name.localized }.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
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
    // Without a picture, an icon and a soft color of the category.
    var category: WorkoutCategory? = nil

    var body: some View {
        AsyncImage(url: url.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                ZStack {
                    placeholderColor.opacity(0.16)
                    Image(systemName: placeholderImage)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(placeholderColor)
                }
            }
        }
        .clipped()
    }

    private var placeholderColor: Color {
        switch category {
        case .mobilityFlexibility: .teal
        case .strengthConditioning: .orange
        case nil: .apexMainColor
        }
    }

    private var placeholderImage: String {
        switch category {
        case .mobilityFlexibility: "figure.flexibility"
        case .strengthConditioning: "dumbbell.fill"
        case nil: "dumbbell.fill"
        }
    }
}

#Preview {
    WorkoutsView()
        .environmentObject(AuthManager())
        .environmentObject(ToastManager())
}
