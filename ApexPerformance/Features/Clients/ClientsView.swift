import SwiftUI

struct ClientsView: View {
    @State var clients: [Client] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoaded = false
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    @State private var showCreateClientForm = false
    // nil shows clients of all plans.
    @State private var planFilter: ClientPlan?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("clients")
                            .font(.title.bold())
                        
                        Text("manage_your_clients")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Search
                    HStack(spacing: 10) {
                        ButtonContentView("", style: .iconOnly(systemName: "magnifyingglass"))
                        
                        TextField("search_clients", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .focused($isSearchFocused)
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                ButtonContentView("", style: .iconOnly(systemName: "xmark"))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    }
                    .padding(.horizontal, 20)
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                    }
                    
                    // Clients card
                    CardView {
                        VStack(spacing: 0) {
                            
                            let list = filteredClients
                            
                            ForEach(list) { client in
                                NavigationLink {
                                    ClientDetailsView(client: client)
                                } label: {
                                    clientRow(client)
                                }
                                .buttonStyle(.plain)
                                .background(Color.clear)
                                .accessibilityIdentifier("client-row")
                                .onTapGesture {
                                    isSearchFocused = false
                                }
                                
                                if client.id != list.last?.id {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 12)
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .overlay {
                if isLoading && clients.isEmpty {
                    ProgressView()
                }
            }
            .task {
                await loadData()
            }
            .refreshable {
                // Own task so the request isn't cancelled when the
                // view updates during pull-to-refresh.
                await Task { await loadData() }.value
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("plan", selection: $planFilter) {
                            Text("all_plans").tag(ClientPlan?.none)
                            ForEach(ClientPlan.allCases) { plan in
                                Text(plan.title).tag(ClientPlan?.some(plan))
                            }
                        }
                    } label: {
                        Image(systemName: planFilter == nil
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                            .foregroundStyle(Color.apexMainColor)
                    }
                    .accessibilityLabel("plan")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateClientForm = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.apexMainColor)
                    }
                    .accessibilityLabel("new_client")
                    .buttonStyle(.plain)
                }
            }
            .navigationDestination(isPresented: $showCreateClientForm) {
                CreateClientView()
            }
        }
    }
    
    private var filteredClients: [Client] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let clients = planFilter.map { plan in self.clients.filter { $0.plan == plan.rawValue } } ?? self.clients
        guard !q.isEmpty else { return clients }
        
        return clients.filter { c in
            let fullName = "\(c.firstName) \(c.lastName)".lowercased()
            let email = (c.email ?? "").lowercased()
            _ = (c.phone ?? "").lowercased()
            
            return fullName.contains(q) || email.contains(q)
        }
    }
    
    // Credits and, when known, the client's plan.
    private func planSubtitle(for client: Client) -> Text {
        let credits = Text("\(client.credits ?? 0) credits_remaining.")
        guard let plan = ClientPlan.title(for: client.plan) else { return credits }
        return credits + Text(verbatim: " · ") + Text(plan)
    }
    
    private func clientRow(_ client: Client) -> some View {
        
        let outOfCredits = client.credits ?? 0 < 1

        return SettingsRowView(
            icon: "person",
            iconTint: Color.apexMainColor,
            title: Text("\(client.firstName) \(client.lastName)"),
            subtitle: planSubtitle(for: client),
            showChevron: true,
            badge: outOfCredits ? "out_of_credits" : nil
        )
        .contentShape(Rectangle())
        .background(Color.clear)
    }
    
    @MainActor
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("clients")
            
            let response: [Client] = try await APIClient.shared.request(url)
            
            clients = response.map {
                Client(
                    id: $0.id,
                    firstName: $0.firstName,
                    lastName: $0.lastName,
                    email: $0.email,
                    phone: $0.phone,
                    credits: $0.credits,
                    bodyMeasurements: $0.bodyMeasurements,
                    lastCreditsIncrease: $0.lastCreditsIncrease,
                    plan: $0.plan
                )
            }
            errorMessage = nil
        } catch let error where error.isCancellation {
            return
        } catch {
            errorMessage = mapError(error)
        }
    }
}

#Preview {
    ClientsView(clients: [
        Client(id: UUID(), firstName: "John", lastName: "Doe", email: "john.doe@email.com", phone: "123456789", credits: 0, bodyMeasurements: [], lastCreditsIncrease: .now),
        Client(id: UUID(), firstName: "Ana", lastName: "Kovač", email: "ana.kovac@email.com", phone: "987654321", credits: 1, bodyMeasurements: [], lastCreditsIncrease: .now),
        Client(id: UUID(), firstName: "Marko", lastName: "Horvat", email: "marko.h@email.com", phone: "555666777", credits: 5, bodyMeasurements: [], lastCreditsIncrease: .now),
        Client(id: UUID(), firstName: "Ivana", lastName: "Marić", email: "ivana.m@email.com", phone: "444333222", credits: 12, bodyMeasurements: [], lastCreditsIncrease: .now)
    ])
}
