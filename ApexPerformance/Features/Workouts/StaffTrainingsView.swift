//
//  StaffTrainingsView.swift
//  ApexPerformance
//

import SwiftUI

/// Trainings of all the coach's clients (administrators see all), with
/// search and filters, same as the web's trainings page. New trainings
/// are still made in the client's details.
struct StaffTrainingsView: View {
    @EnvironmentObject private var toastManager: ToastManager

    @State private var trainings: [Training] = []
    @State private var searchText = ""
    @State private var status = StatusFilter.all
    @State private var clientId: UUID?
    @State private var isLoading = false
    @State private var hasLoaded = false

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
        ScrollView {
            VStack(spacing: 16) {
                ApexScreenHeader(title: "trainings", subtitle: "all_trainings_subtitle", showsWordmark: false)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

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
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            await load()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ training: Training) -> some View {
        SettingsRowView(
            icon: training.isCompleted ? "checkmark.circle" : "calendar",
            iconTint: training.isCompleted ? .green : .orange,
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
