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
    
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false
    
    var onSuccess: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("new_password")) {
                    ZStack {
                        if showNewPassword {
                            TextField("enter_new_password", text: $newPassword)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("enter_new_password", text: $newPassword)
                        }
                        HStack {
                            Spacer()
                            Button {
                                showNewPassword.toggle()
                            } label: {
                                Image(systemName: showNewPassword ? "eye.slash" : "eye")
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundColor(Color.apexMainColor)
                                    .padding(8)
                                    .contentShape(Rectangle())
                                    .frame(minWidth: 32, minHeight: 32)
                            }
                            .accessibilityLabel(showNewPassword ? "Hide password" : "Show password")
                        }
                        .padding(.trailing, 8)
                    }
                }
                Section(header: Text("confirm_password")) {
                    ZStack {
                        if showConfirmPassword {
                            TextField("enter_confirm_password", text: $confirmPassword)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("enter_confirm_password", text: $confirmPassword)
                        }
                        HStack {
                            Spacer()
                            Button {
                                showConfirmPassword.toggle()
                            } label: {
                                Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                    .font(.system(size: 20, weight: .regular))
                                    .foregroundColor(Color.apexMainColor)
                                    .padding(8)
                                    .contentShape(Rectangle())
                                    .frame(minWidth: 32, minHeight: 32)
                            }
                            .accessibilityLabel(showConfirmPassword ? "Hide password" : "Show password")
                        }
                        .padding(.trailing, 8)
                    }
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
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.apexMainColor)
                            }
                        }
                    }
                    .disabled(isSaving || newPassword.isEmpty || confirmPassword.isEmpty || newPassword != confirmPassword)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label :{
                        Image(systemName: "chevron.backward")
                            .foregroundStyle(Color.apexMainColor)
                    }
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
            toastManager.show("password_changed_successfully", type: .success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                dismiss()
                onSuccess?()
            }
        } catch {
            errorMessage = mapError(error)
            toastManager.show(LocalizedStringKey(errorMessage!), type: .error)
        }
    }
    
    private func sendChangePasswordRequest() async throws {
        struct ChangePasswordRequest: Encodable { let newPassword: String }
        let url = AppEnvironment.apiURL.appendingPathComponent("authentication/reset-password")
        let request = ChangePasswordRequest(newPassword: newPassword)
        _ = try await APIClient.shared.request(url, method: .post, body: JSONEncoder().encode(request)) as StatusResponse
    }
}

#Preview {
    ChangePasswordView()
        .environmentObject(ToastManager())
}

