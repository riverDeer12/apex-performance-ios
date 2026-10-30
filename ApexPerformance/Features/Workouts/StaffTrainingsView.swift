//
//  StaffTrainingsView.swift
//  ApexPerformance
//

import SwiftUI

/// Trainings tab of coaches and administrators, like the web's trainings
/// menu: trainings of all their clients (administrators see all) with
/// search and filters, new trainings, templates and personal records.
/// Trainings can still be made and opened in the client's details too.
struct StaffTrainingsView: View {
    @EnvironmentObject private var toastManager: ToastManager

    // New training: the client is picked first, then the form opens.
    @State private var showClientPicker = false
    @State private var pickedClient: Client?
    @State private var clientForNewTraining: Client?

    @State private var trainings: [Training] = []
    @State private var searchText = ""
    @State private var status = StatusFilter.all
    @State private var clientId: UUID?
    @State private var isLoading = false

    enum StatusFilter: Hashable, CaseIterable {
        case all, planned, completed

        var title: LocalizedStringKey {
            switch self {
            case .all: "all"
            case .planned: "planned"
            case .completed: "completed"
            }
        }
    }

    // Clients that have trainings, by name.
    private var clients: [Training.Person] {
        Dictionary(trainings.map { ($0.client.id, $0.client) }, uniquingKeysWith: { first, _ in first })
            .values
            .sorted { Self.name($0).localizedStandardCompare(Self.name($1)) == .orderedAscending }
    }

    private var filteredTrainings: [Training] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trainings.filter { training in
            switch status {
            case .all: break
            case .planned: guard !training.isCompleted else { return false }
            case .completed: guard training.isCompleted else { return false }
            }
            if let clientId, training.client.id != clientId { return false }
            guard !query.isEmpty else { return true }
            return training.name.localizedStandardContains(query)
                || Self.name(training.client).localizedStandardContains(query)
                || training.exercises.contains { $0.workoutName.allValues.contains { $0.localizedStandardContains(query) } }
        }
    }

    var body: some View {
        NavigationStack {
            content
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                ApexScreenHeader(title: "trainings", subtitle: "all_trainings_subtitle")
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Button("new_training") {
                    pickedClient = nil
                    showClientPicker = true
                }
                .buttonStyle(ApexPrimaryButtonStyle(systemImage: "plus"))
                .padding(.horizontal, 20)

                linksCard
                    .padding(.horizontal, 20)

                Picker("status", selection: $status) {
                    ForEach(StatusFilter.allCases, id: \.self) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)

                HStack(spacing: 10) {
                    searchField
                    clientMenu
                }
                .padding(.horizontal, 20)

                CardView {
                    if filteredTrainings.isEmpty, !isLoading {
                        Text(trainings.isEmpty ? LocalizedStringKey("no_trainings") : LocalizedStringKey("no_trainings_found"))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredTrainings) { training in
                                NavigationLink {
                                    TrainingDetailView(
                                        training: training,
                                        history: trainings.filter { $0.client.id == training.client.id },
                                        onSaved: { upsert($0) },
                                        onDeleted: { id in trainings.removeAll { $0.id == id } }
                                    )
                                } label: {
                                    row(training)
                                }
                                .buttonStyle(.plain)

                                if training.id != filteredTrainings.last?.id {
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
            if isLoading && trainings.isEmpty {
                ProgressView()
            }
        }
        .refreshable {
            await Task { await load() }.value
        }
        // Fresh data every time the screen is shown, not only after pulling
        // to refresh. Own task, so leaving the screen doesn't cancel it.
        .task {
            await Task { await load() }.value
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showClientPicker, onDismiss: {
            // The form opens once the picker is closed.
            clientForNewTraining = pickedClient
        }) {
            ClientPickerView(title: "new_training") { client in
                pickedClient = client
                showClientPicker = false
            }
        }
        .sheet(item: $clientForNewTraining) { client in
            TrainingFormView(
                clientId: client.id,
                history: trainings.filter { $0.client.id == client.id }
            ) { saved in
                upsert(saved)
            }
        }
    }

    // Templates and personal records, like the web's trainings menu.
    private var linksCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                TrainingTemplatesView()
            } label: {
                SettingsRowView(
                    icon: "doc.on.clipboard",
                    iconTint: Color.apexAccent,
                    title: Text("training_templates"),
                    subtitle: Text("training_templates_subtitle"),
                    showChevron: true
                )
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 46)

            NavigationLink {
                PersonalRecordsClientsView()
            } label: {
                SettingsRowView(
                    icon: "trophy",
                    iconTint: Color.apexAccent,
                    title: Text("personal_records"),
                    subtitle: Text("personal_records_hint"),
                    showChevron: true
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .apexCardBackground()
    }

    private func row(_ training: Training) -> some View {
        SettingsRowView(
            icon: training.statusIcon,
            iconTint: training.statusTint,
            title: Text(verbatim: training.name),
            subtitle: Text(verbatim: "\(Self.name(training.client)) · \(DateFormatter.dateWithDots.string(from: training.date))"),
            showChevron: true
        )
    }

    private var clientMenu: some View {
        Menu {
            Picker("client", selection: $clientId) {
                Text("all_clients").tag(UUID?.none)
                ForEach(clients, id: \.id) { client in
                    Text(verbatim: Self.name(client)).tag(UUID?.some(client.id))
                }
            }
        } label: {
            Image(systemName: clientId == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.apexMainColor)
                .frame(width: 44, height: 44)
                .apexCardBackground(cornerRadius: 10)
        }
        .accessibilityLabel(Text("filter_by_client"))
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

    private static func name(_ client: Training.Person) -> String {
        [client.firstName, client.lastName].compactMap { $0 }.joined(separator: " ")
    }

    private func upsert(_ training: Training) {
        trainings.removeAll { $0.id == training.id }
        trainings.append(training)
        trainings.sort { $0.date > $1.date }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            trainings = try await Training.loadAll()
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

/// Searchable list of the coach's clients; tapping one picks it.
struct ClientPickerView: View {
    let title: LocalizedStringKey
    let onPick: (Client) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ClientsList { client in
                Button {
                    onPick(client)
                } label: {
                    Text(verbatim: client.fullName)
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
            .navigationTitle(title)
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
            }
        }
    }
}

/// Clients to open personal records of, like the web's client select.
struct PersonalRecordsClientsView: View {
    var body: some View {
        ClientsList { client in
            NavigationLink {
                PersonalRecordsView(clientId: client.id, clientName: client.fullName)
            } label: {
                Text(verbatim: client.fullName)
            }
        }
        .navigationTitle("personal_records")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Searchable list of the coach's clients (administrators see all) by name.
struct ClientsList<Row: View>: View {
    @ViewBuilder let row: (Client) -> Row

    @EnvironmentObject private var toastManager: ToastManager

    @State private var clients: [Client] = []
    @State private var searchText = ""
    @State private var isLoading = false

    private var filteredClients: [Client] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = clients.sorted { $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending }
        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.fullName.localizedStandardContains(query) }
    }

    var body: some View {
        List {
            if clients.isEmpty, !isLoading {
                Text("no_clients")
                    .foregroundStyle(.secondary)
            }
            ForEach(filteredClients) { client in
                row(client)
            }
        }
        .searchable(text: $searchText, prompt: Text("search_clients"))
        .overlay {
            if isLoading && clients.isEmpty {
                ProgressView()
            }
        }
        .task {
            await load()
        }
    }

    @MainActor
    private func load() async {
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
}
