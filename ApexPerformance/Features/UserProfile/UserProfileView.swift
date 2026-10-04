import SwiftUI
// Import ChangePasswordView if it's in a separate file/module
// import ChangePasswordView
// Import ChangeUsernameView if it's in a separate file/module
// import ChangeUsernameView

struct UserProfileView: View {
    
    @State private var profile: UserProfile?
    // Account data from api/profile, same for all roles.
    @State private var accountProfile: Profile?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasLoaded = false
    
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var toastManager: ToastManager
    
    @State private var showLogoutDialog = false
    @State private var showChangePasswordSheet = false
    @State private var showChangeUsernameSheet = false
    @State private var showEditProfileSheet = false
    
    // Preview data is shown as is, without loading from the API.
    init(previewProfile: Profile? = nil) {
        _accountProfile = State(initialValue: previewProfile)
        _hasLoaded = State(initialValue: previewProfile != nil)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("my_profile")
                            .font(.title.bold())
                        Text("account_details_and_settings")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // Content
                    profileContent
                    
                    CardView(title: "profile_management") {
                        VStack(spacing: 0) {
                            
                            if accountProfile != nil {
                                Button { showEditProfileSheet = true } label: {
                                    SettingsRowView(
                                        icon: "person.crop.circle",
                                        iconTint: Color.apexMainColor,
                                        title: Text("edit_profile"),
                                        subtitle: nil,
                                        showChevron: true
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Divider().padding(.leading, 52)
                            }
     
                            Button { changeUsername() } label: {
                                SettingsRowView(
                                    icon: "pencil",
                                    iconTint: Color.apexMainColor,
                                    title: Text("change_username"),
                                    subtitle: nil,
                                    showChevron: true
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Divider().padding(.leading, 52)
                            
                            Button { changePassword() } label: {
                                SettingsRowView(
                                    icon: "key",
                                    iconTint: Color.apexMainColor,
                                    title: Text("change_password"),
                                    subtitle: nil,
                                    showChevron: true
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Divider().padding(.leading, 52)
                            
                            AppearanceSwitcherView()
                            
                            Divider().padding(.leading, 52)
                            
                            Button(role: .destructive) { showLogoutDialog = true } label: {
                                SettingsRowView(
                                    icon: "arrow.left.square",
                                    iconTint: .red,
                                    title: Text("logout"),
                                    subtitle: nil,
                                    showChevron: true,
                                    titleColor: .red
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 12)
                }
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .overlay {
                if isLoading && accountProfile == nil {
                    ProgressView()
                }
            }
            .task {
                guard !hasLoaded else { return }
                
                hasLoaded = true
            
                await loadUserProfile()
            }
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("logout_question", isPresented: $showLogoutDialog) {
                Button("logout", role: .destructive) {
                    PushTokenService.unregister()
                    authManager.logout()
                }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("you_will_be_signed_out")
            }
            .sheet(isPresented: $showChangePasswordSheet) {
                ChangePasswordView(onSuccess: { showChangePasswordSheet = false })
            }
            .sheet(isPresented: $showChangeUsernameSheet) {
                ChangeUsernameView(onSuccess: { showChangeUsernameSheet = false })
            }
            .sheet(isPresented: $showEditProfileSheet) {
                if let accountProfile {
                    EditProfileView(profile: accountProfile) { updated in
                        self.accountProfile = updated
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var profileContent: some View {
        if let accountProfile {
            // Top card
            CardView {
                HStack(spacing: 14) {
                    ProfilePictureView(profile: accountProfile)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(fullName)
                            .font(.headline)
                        Text("@\(authManager.username)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            
            if isClient {
                // Credits tile
                HStack(spacing: 12) {
                    StatTileView(value: "\(profile?.credits ?? 0)", label: "credits")
                }
                .padding(.horizontal, 20)
            }
            
            // Details
            CardView(title: "details") {
                VStack(spacing: 0) {
                    if accountProfile.hasPersonalData {
                        InfoRow(icon: "person", title: "first_name", value: accountProfile.firstName ?? "—")
                        Divider().padding(.leading, 52)
                        InfoRow(icon: "person", title: "last_name", value: accountProfile.lastName ?? "—")
                        Divider().padding(.leading, 52)
                    }
                    InfoRow(icon: "at", title: "username", value: authManager.username)
                    Divider().padding(.leading, 52)
                    InfoRow(icon: "envelope", title: "email", value: accountProfile.email)
                    if accountProfile.hasPhone {
                        Divider().padding(.leading, 52)
                        InfoRow(icon: "phone", title: "mobile_phone", value: accountProfile.phone ?? "—")
                    }
                    if isClient {
                        Divider().padding(.leading, 52)
                        InfoRow(icon: "creditcard", title: "credits", value: "\(profile?.credits ?? 0)")
                        if let plan = profile?.plan.flatMap(ClientPlan.init(rawValue:)) {
                            Divider().padding(.leading, 52)
                            InfoRow(icon: "figure.strengthtraining.traditional", title: "plan", value: plan.localizedTitle)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        } else if !isLoading {
            nonClientProfileContent
        }
    }
    
    private var nonClientProfileContent: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                Text("profile")
                    .font(.headline)
                Text("profile_is_not_provided")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 20)
    }

    private var isClient: Bool {
        authManager.hasRole(role: "Client")
    }
    
    private var fullName: String {
        guard let accountProfile, accountProfile.hasPersonalData else {
            return authManager.username
        }
        let first = accountProfile.firstName ?? "—"
        let last = accountProfile.lastName ?? ""
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }
    
    private struct InfoRow: View {
        let icon: String
        let title: LocalizedStringKey
        let value: String
        
        var body: some View {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.apexMainColor.opacity(0.25))
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.apexMainColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                }
                
                Spacer()
            }
            .padding(.vertical, 10)
        }
    }
    
    @MainActor
    private func loadUserProfile() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("profile")
            let response: Profile = try await APIClient.shared.request(url)
            accountProfile = response
            
            // Credits are only on client data.
            if isClient {
                let clientURL = AppEnvironment.apiURL.appendingPathComponent("clients/current-client")
                let client: UserProfile = try await APIClient.shared.request(clientURL)
                profile = client
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = mapError(error)
        }
    }
    
    private func changePassword() {
        showChangePasswordSheet = true
    }
    
    private func changeUsername() {
        showChangeUsernameSheet = true
    }
}

#Preview{
    UserProfileView(previewProfile: .previewClient)
        .environmentObject(AuthManager())
        .environmentObject(ToastManager())
}
