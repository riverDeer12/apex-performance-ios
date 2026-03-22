//
//  ChangePasswordView.swift
//  ApexPerformance
//
//  Created by Sara Husidic on 3/22/26.
//

import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var onSuccess: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("new_password")) {
                    SecureField("enter_new_password", text: $newPassword)
                }
                Section(header: Text("confirm_password")) {
                    SecureField("enter_confirm_password", text: $confirmPassword)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("change_password")
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
                                Text("Save")
                            }
                        }
                    }
                    .disabled(isSaving || newPassword.isEmpty || confirmPassword.isEmpty || newPassword != confirmPassword)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func save() async {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await sendChangePasswordRequest()
            toastManager.show(Text("password_changed_successfully"), type: .success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                dismiss()
                onSuccess?()
            }
        } catch {
            errorMessage = mapError(error)
            toastManager.show(Text(errorMessage ?? "unknown_error_message"), type: .error)
        }
    }
    
    private func sendChangePasswordRequest() async throws {
        struct ChangePasswordRequest: Encodable { let newPassword: String }
        let url = AppEnvironment.apiURL.appendingPathComponent("authentication/change-password")
        let request = ChangePasswordRequest(newPassword: newPassword)
        _ = try await APIClient.shared.request(url, method: .post, body: JSONEncoder().encode(request)) as StatusResponse
    }
}

#Preview {
    ChangePasswordView()
        .environmentObject(ToastManager())
}
