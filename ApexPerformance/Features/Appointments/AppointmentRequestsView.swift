import SwiftUI

struct AppointmentRequestsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var toastManager: ToastManager
    
    @State private var requests: [AppointmentRequest] = []
    @State private var isInitialLoading = false
    @State private var errorMessage: String?
    @State private var hasLoaded = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("appointment_requests")
                            .font(.title.bold())
                        Text("manage_client_requests")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Content card
                    CardView {
                        if requests.isEmpty, !isInitialLoading {
                            Text("no_requests")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(requests) { request in
                                    NavigationLink {
                                        AppointmentRequestDetailsView(request: request)
                                    } label: {
                                        requestRow(request)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if request.id != requests.last?.id {
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
            .background(Color(.systemGroupedBackground))
            .overlay {
                if isInitialLoading && requests.isEmpty {
                    ProgressView()
                }
            }
            .refreshable {
                await loadData(showInitialSpinner: false)
            }
            .task {
                await loadData(showInitialSpinner: true)
            }
            .onAppear {
                if hasLoaded {
                    Task {
                        await loadData(showInitialSpinner: false)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func requestRow(_ request: AppointmentRequest) -> some View {
        VStack(spacing: 0) {
            
            let title = authManager.hasRole(role: "Client") ?
            request.type.description.lowercased() : request.sender.fullName
            
            let subtitle = authManager.hasRole(role: "Client") ?
            DateFormatter.dateWithDots.string(from: request.appointment.startTime) + " - " +
            (request.appointment.timeSlot.description ?? "") :
                request.type.description.lowercased()
 
            SettingsRowView(
                icon: requestIcon(for: request.type.name),
                iconTint: requestColor(for: request.type.name),
                title: Text(LocalizedStringKey(title)),
                subtitle: Text(LocalizedStringKey(subtitle)),
                showChevron: true
            )
            
            if !request.comment.isEmpty {
                HStack {
                    Text(request.comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.leading, 46)
                        .padding(.trailing, 12)
                        .padding(.top, 4)
                    Spacer()
                }
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
    
    private func requestIcon(for typeName: String) -> String {
        switch typeName.lowercased() {
        case "cancelationrequest":
            return "calendar.badge.minus"
        default:
            return "questionmark.circle"
        }
    }
    
    private func requestColor(for typeName: String) -> Color {
        switch typeName.lowercased() {
        case "cancelationrequest":
            return .red
        default:
            return Color.apexMainColor
        }
    }
    
    private func loadData(showInitialSpinner: Bool) async {
        guard !hasLoaded || !showInitialSpinner else { return }
        
        if showInitialSpinner {
            isInitialLoading = true
        }
        
        defer {
            isInitialLoading = false
            hasLoaded = true
        }
        
        do {
            requests = try await fetchAppointmentRequests()
        } catch {
            errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage!), type: .error)
        }
    }
    
    private func fetchAppointmentRequests() async throws -> [AppointmentRequest] {
        let url = AppEnvironment.apiURL.appendingPathComponent("appointment-requests/pending")
        let response: [AppointmentRequest] = try await APIClient.shared.request(url)
        return response
    }
}

#Preview("Request List") {
    AppointmentRequestsView()
        .environmentObject(AuthManager())
        .environmentObject(ToastManager())
}

