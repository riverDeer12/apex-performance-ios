import SwiftUI

struct ChangeUsernameView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var newUsername: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var onSuccess: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("new_username")) {
                    TextField("enter_new_username", text: $newUsername)
                        .textInputAutocapitalization(.never)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("change_username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        ZStack {
                            if isSaving {
                                ProgressView().scaleEffect(0.9)
                            } else {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.apexMainColor)
                            }
                        }
                    }
                    .disabled(isSaving || newUsername.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button{
                        dismiss()
                    } label : {
                        Image(systemName: "chevron.backward")
                            .foregroundStyle(Color.apexMainColor)
                    }
                }
            }
        }
    }
    
    private func save() async {
        guard !newUsername.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Username cannot be empty."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await sendChangeUsernameRequest()
            toastManager.show(Text("username_changed_successfully"), type: .success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                dismiss()
                onSuccess?()
            }
        } catch {
            errorMessage = mapError(error)
            toastManager.show(Text(errorMessage ?? "unknown_error_message"), type: .error)
        }
    }
    
    private func sendChangeUsernameRequest() async throws {
        struct ChangeUsernameRequest: Encodable { let username: String }
        let url = AppEnvironment.apiURL.appendingPathComponent("authentication/change-username")
        let request = ChangeUsernameRequest(username: newUsername.trimmingCharacters(in: .whitespaces))
        _ = try await APIClient.shared.request(url, method: .post, body: JSONEncoder().encode(request)) as StatusResponse
    }
}

#Preview {
    ChangeUsernameView()
        .environmentObject(ToastManager())
}
