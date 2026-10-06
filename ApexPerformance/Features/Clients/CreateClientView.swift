import SwiftUI

struct CreateClientRequest: Encodable {
    var firstName: String
    var lastName: String
    var email: String?
    var phone: String?
    var credits: Int?
    var coaches: [UUID]
    var plan: String
}

struct CreateClientView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var errorMessage: String? = nil

    // Form values
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var credits: Int? = nil
    @State private var plan: ClientPlan = .privateCoaching
    @State private var isSaving = false
    
    @State private var isLoadingCoaches = false
    @State private var coaches: [Coach] = []
    @State private var selectedCoaches: [UUID] = []

    // API always adds the coach who creates the client as
    // the client's coach, so a coach doesn't pick coaches.
    private var canSelectCoaches: Bool {
        !authManager.hasRole(role: "Coach")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CardView(title: "personal_info") {
                    VStack(spacing: 0) {
                        editableRow(title: "first_name") {
                            TextField("first_name", text: $firstName)
                                .multilineTextAlignment(.trailing)
                        }
                        Divider().padding(.leading, 0)
                        editableRow(title: "last_name") {
                            TextField("last_name", text: $lastName)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .padding(.horizontal, 20)

                CardView(title: "contact") {
                    VStack(spacing: 0) {
                        editableRow(title: "email") {
                            TextField("email", text: $email)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .multilineTextAlignment(.trailing)
                        }
                        Divider()
                        editableRow(title: "mobile_phone") {
                            TextField("mobile_phone", text: $phone)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.phonePad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .padding(.horizontal, 20)

                CardView(title: "credits") {
                    editableRow(title: "appointments_left") {
                        TextField("appointments_left", value: Binding(
                            get: { credits ?? 0 },
                            set: { credits = $0 }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                    }
                }
                .padding(.horizontal, 20)
                
                CardView(title: "plan") {
                    editableRow(title: "plan") {
                        Picker("plan", selection: $plan) {
                            ForEach(ClientPlan.allCases) { plan in
                                Text(plan.title).tag(plan)
                            }
                        }
                        .labelsHidden()
                        .tint(Color.apexMainColor)
                    }
                }
                .padding(.horizontal, 20)
                
                if canSelectCoaches {
                    CardView(title: "select_coaches") {
                        if isLoadingCoaches {
                            ProgressView("loading_coaches")
                        }
                        ForEach(coaches) { coach in
                            Toggle(coach.fullName, isOn: Binding(
                                get: { selectedCoaches.contains(coach.id) },
                                set: { isOn in
                                    if isOn {
                                        selectedCoaches.append(coach.id)
                                    } else {
                                        selectedCoaches.removeAll { $0 == coach.id }
                                    }
                                }
                            ))
                        }
                    }
                    .padding(.horizontal, 20)
                    .disabled(isLoadingCoaches || coaches.isEmpty)
                }
            }
            .padding(.bottom, 24)
        }
        .task {
            if canSelectCoaches {
                await loadCoaches()
            }
        }
        .background(Color.apexBackground)
        .navigationTitle("new_client")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await save() }
                } label: {
                    ZStack {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.apexMainColor)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                }
                .disabled(isSaving || firstName.trimmingCharacters(in: .whitespaces).isEmpty || lastName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func editableRow<Content: View>(
        title: LocalizedStringKey,
        @ViewBuilder field: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            field()
        }
        .padding(.vertical, 10)
    }
    
    private func save() async {
        do {
            _ = try await sendNewClientToApi()
            toastManager.show("client_created_successfully", type: ToastType.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                dismiss()
            }
        } catch {
            errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage!), type: ToastType.error)
        }
    }

    private func sendNewClientToApi() async throws -> StatusResponse {
        isSaving = true
        defer { isSaving = false }
        
        let request = CreateClientRequest(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            credits: credits,
            coaches: canSelectCoaches ? selectedCoaches : [],
            plan: plan.rawValue
        )

        let url = AppEnvironment.apiURL.appendingPathComponent("clients")
        
        let response: StatusResponse = try await APIClient.shared.request(url, method: .post, body: JSONEncoder().encode(request))
        
        return response;
    }
    
    private func loadCoaches() async {
        isLoadingCoaches = true
        defer { isLoadingCoaches = false }
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("coaches/all")
            let response: [Coach] = try await APIClient.shared.request(url)
            coaches = response
        } catch {
            errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage!), type: ToastType.error)
        }
    }
}

#Preview("CreateClientView") {
    NavigationStack {
        CreateClientView()
            .environmentObject(ToastManager())
            .environmentObject(AuthManager())
    }
}
