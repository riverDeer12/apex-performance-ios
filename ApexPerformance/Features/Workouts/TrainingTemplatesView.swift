//
//  TrainingTemplatesView.swift
//  ApexPerformance
//

import SwiftUI

/// Training templates of the coach (administrators see all), opened
/// from the workouts tab. Templates are assigned to clients as planned
/// trainings, same as on the web.
struct TrainingTemplatesView: View {
    @EnvironmentObject private var toastManager: ToastManager

    @State private var templates: [TrainingTemplate] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var showCreateSheet = false
    @State private var templateToDelete: TrainingTemplate?

    private var filteredTemplates: [TrainingTemplate] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return templates }
        return templates.filter { template in
            template.name.localizedStandardContains(query)
                || template.exercises.contains { $0.workoutName.allValues.contains { $0.localizedStandardContains(query) } }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ApexScreenHeader(title: "training_templates", subtitle: "training_templates_subtitle")
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Button("new_template") {
                    showCreateSheet = true
                }
                .buttonStyle(ApexPrimaryButtonStyle(systemImage: "plus"))
                .padding(.horizontal, 20)

                if !templates.isEmpty {
                    searchField
                        .padding(.horizontal, 20)
                }

                CardView {
                    if filteredTemplates.isEmpty, !isLoading {
                        (searchText.isEmpty ? Text("no_templates") : Text("no_templates_found"))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredTemplates) { template in
                                NavigationLink {
                                    TrainingTemplateDetailView(template: template) { updated in
                                        replace(updated)
                                    } onDeleted: {
                                        templates.removeAll { $0.id == template.id }
                                    }
                                } label: {
                                    row(template)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if template.canEdit {
                                        Button("delete_template", systemImage: "trash", role: .destructive) {
                                            templateToDelete = template
                                        }
                                    }
                                }

                                if template.id != filteredTemplates.last?.id {
                                    Divider().padding(.leading, 52)
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
            if isLoading && templates.isEmpty {
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
        .confirmationDialog(
            "delete_template_question",
            isPresented: Binding(
                get: { templateToDelete != nil },
                set: { if !$0 { templateToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: templateToDelete
        ) { template in
            Button("delete", role: .destructive) {
                Task { await delete(template) }
            }
            Button("cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showCreateSheet) {
            TrainingFormView(template: nil) { created in
                replace(created)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ template: TrainingTemplate) -> some View {
        SettingsRowView(
            icon: "doc.on.clipboard",
            iconTint: Color.apexAccent,
            title: Text(verbatim: template.name),
            subtitle: subtitle(template),
            showChevron: true
        )
    }

    // Administrators see templates of several coaches, so then the author is shown too.
    private var showsAuthors: Bool {
        Set(templates.compactMap(\.authorName)).count > 1
    }

    // "5 exercises", or "5 exercises · Ana Horvat".
    private func subtitle(_ template: TrainingTemplate) -> Text {
        let count = Text("exercises_count \(template.exercises.count)")
        guard showsAuthors, let author = template.authorName, !author.isEmpty else { return count }
        return count + Text(verbatim: " · \(author)")
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("search_templates", text: $searchText)
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

    private func replace(_ template: TrainingTemplate) {
        templates.removeAll { $0.id == template.id }
        templates.append(template)
        templates.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            templates = try await TrainingTemplate.loadAll()
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func delete(_ template: TrainingTemplate) async {
        do {
            try await TrainingTemplate.delete(id: template.id)
            templates.removeAll { $0.id == template.id }
            toastManager.show("template_deleted", type: .success)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

/// Exercises of a template, with assigning it to clients and, for its
/// author or an administrator, editing and deleting.
struct TrainingTemplateDetailView: View {
    @State private var template: TrainingTemplate
    private let onSaved: (TrainingTemplate) -> Void
    private let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var showEditSheet = false
    @State private var showAssignSheet = false
    @State private var showDeleteDialog = false
    @State private var isDeleting = false

    init(template: TrainingTemplate, onSaved: @escaping (TrainingTemplate) -> Void,
         onDeleted: @escaping () -> Void) {
        _template = State(initialValue: template)
        self.onSaved = onSaved
        self.onDeleted = onDeleted
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: template.name)
                        .apexTitle()
                    if let author = template.authorName, !author.isEmpty {
                        Label {
                            Text(verbatim: author)
                        } icon: {
                            Image(systemName: "person")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Button("assign_to_clients") {
                    showAssignSheet = true
                }
                .buttonStyle(ApexPrimaryButtonStyle(systemImage: "paperplane"))
                .disabled(template.exercises.isEmpty)
                .opacity(template.exercises.isEmpty ? 0.5 : 1)
                .padding(.horizontal, 20)

                if template.exercises.isEmpty {
                    CardView {
                        Text("no_exercises")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                }

                TrainingExerciseCards(exercises: template.exercises)

                if let note = template.note, !note.isEmpty {
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
        .navigationTitle(Text(verbatim: template.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if template.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("edit_template", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            showDeleteDialog = true
                        } label: {
                            Label("delete_template", systemImage: "trash")
                        }
                    } label: {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(Color.apexMainColor)
                        }
                    }
                    .disabled(isDeleting)
                    .accessibilityLabel(Text("template_actions"))
                }
            }
        }
        .confirmationDialog("delete_template_question", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("delete", role: .destructive) {
                Task { await delete() }
            }
            Button("cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditSheet) {
            TrainingFormView(template: template) { saved in
                template = saved
                onSaved(saved)
            }
        }
        .sheet(isPresented: $showAssignSheet) {
            AssignTrainingTemplateView(template: template)
        }
    }

    @MainActor
    private func delete() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await TrainingTemplate.delete(id: template.id)
            onDeleted()
            toastManager.show("template_deleted", type: .success)
            dismiss()
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

/// Picks clients and a date; each client gets a planned training
/// with the template's exercises and sets.
struct AssignTrainingTemplateView: View {
    let template: TrainingTemplate

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var clients: [Client] = []
    @State private var selectedClients: Set<UUID> = []
    @State private var date = Date.now
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var isAssigning = false

    private var filteredClients: [Client] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = clients.sorted { $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending }
        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.fullName.localizedStandardContains(query) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("date", selection: $date, displayedComponents: .date)
                } footer: {
                    Text("assign_template_hint")
                }

                Section {
                    if clients.isEmpty, !isLoading {
                        Text("no_clients")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(filteredClients) { client in
                        Button {
                            toggle(client.id)
                        } label: {
                            HStack {
                                Text(verbatim: client.fullName)
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                if selectedClients.contains(client.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.apexMainColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                    }
                } header: {
                    HStack {
                        Text("clients")
                        Spacer()
                        if !selectedClients.isEmpty {
                            Text("selected_count \(selectedClients.count)")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: Text("search_clients"))
            .overlay {
                if isLoading && clients.isEmpty {
                    ProgressView()
                }
            }
            .navigationTitle("assign_to_clients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.apexMainColor)
                    }
                    .accessibilityLabel(Text("cancel"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await assign() }
                    } label: {
                        if isAssigning {
                            ProgressView()
                        } else {
                            Text("assign")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.apexMainColor)
                        }
                    }
                    .disabled(selectedClients.isEmpty || isAssigning)
                }
            }
            .task {
                await loadClients()
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedClients.contains(id) {
            selectedClients.remove(id)
        } else {
            selectedClients.insert(id)
        }
    }

    @MainActor
    private func loadClients() async {
        guard clients.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("clients")
            clients = try await APIClient.shared.request(url)
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func assign() async {
        isAssigning = true
        defer { isAssigning = false }

        do {
            let count = try await template.assign(to: Array(selectedClients), date: date)
            toastManager.show("trainings_created \(count)", type: .success)
            dismiss()
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}
