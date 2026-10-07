//
//  LoginView.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 16.12.2025..
//

import SwiftUI


struct LoginView: View {
    
    @EnvironmentObject var authManager: AuthManager
    
    @State private var username = ""
    @State private var password = ""
    
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var isPasswordVisible = false
    @State private var showForgotPassword = false
    
    @FocusState private var focusedField: Field?
    enum Field { case username, password }
    
    var body: some View {
        
        GeometryReader { geo in
            
            ScrollView {
                VStack {
                    Spacer(minLength: 0)
                    
                    VStack(spacing: 20) {
                        
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            // The logo artwork has wide transparent margins, so its frame is larger.
                            .frame(
                                maxWidth: geo.size.width * 0.9,
                                maxHeight: geo.size.height * 0.22
                            )
                        
                        if authManager.sessionExpired {
                            Label("session_expired", systemImage: "clock.badge.exclamationmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.orange.opacity(0.12))
                                )
                                .accessibilityIdentifier("session-expired-message")
                        }
                        
                        VStack(spacing: 30) {
                            
                            TextField("username", text: $username)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemBackground))
                                        .shadow(radius: 3)
                                )
                                .focused($focusedField, equals: .username)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                                .disabled(isLoading)
                                .accessibilityIdentifier("login-username")
                            
                            HStack {
                                Group {
                                    if isPasswordVisible {
                                        TextField("password", text: $password)
                                    } else {
                                        SecureField("password", text: $password)
                                    }
                                }
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .disabled(isLoading)
                                .accessibilityIdentifier("login-password")
                                
                                Button {
                                    isPasswordVisible.toggle()
                                } label: {
                                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                        .foregroundColor(.apexMainColor)
                                }
                                .disabled(isLoading)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(radius: 3)
                            )
                            
                            Button {
                                Task {
                                    isLoading = true
                                    focusedField = nil
                                    defer { isLoading = false }
                                    
                                    do {
                                        let response = try await authManager.sendLoginRequest(
                                            username: username,
                                            password: password
                                        )
                                                                                
                                        authManager.login(token: response.token)
                                        PushTokenService.registerCurrentToken()

                                    } catch {
                                        errorMessage = mapError(error)
                                        print(error)
                                        showError = true
                                    }
                                }
                            } label: {
                                ZStack {
                                    // Hidden content to preserve button size
                                    HStack {
                                        Text("login")
                                            .fontWeight(.semibold)
                                        Image(systemName: "arrow.right.circle.fill")
                                    }
                                    .opacity(isLoading ? 0 : 1)

                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(Color(.systemBackground))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.apexMainColor)
                                // apexMainColor is white in dark mode, so the text
                                // uses the background colour (white / black).
                                .foregroundColor(Color(.systemBackground))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoading)
                            .accessibilityIdentifier("login-button")
                            
                            Button("forgot_password") {
                                showForgotPassword = true
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.apexMainColor)
                            .disabled(isLoading)
                            .accessibilityIdentifier("forgot-password-button")
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 0)
                }
                .frame(minHeight: geo.size.height)
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }
}

/// Sends the password reset email, same as "Forgot password?" on the web.
/// The email links to the web app where the new password is set.
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isSending = false
    @State private var isSent = false
    @State private var errorMessage: String?

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        trimmedEmail.contains("@") && trimmedEmail.contains(".")
    }

    var body: some View {
        NavigationStack {
            Form {
                if isSent {
                    Section {
                        Label {
                            Text("forgot_password_sent")
                        } icon: {
                            Image(systemName: "envelope.badge")
                                .foregroundStyle(Color.apexMainColor)
                        }
                    }
                } else {
                    Section {
                        TextField("email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.send)
                            .onSubmit {
                                guard isValid else { return }
                                Task { await send() }
                            }
                    } footer: {
                        if let errorMessage {
                            Text(LocalizedStringKey(errorMessage))
                                .foregroundStyle(.red)
                        } else {
                            Text("forgot_password_hint")
                        }
                    }

                    Section {
                        Button {
                            Task { await send() }
                        } label: {
                            HStack {
                                Spacer()
                                if isSending {
                                    ProgressView()
                                } else {
                                    Text("send_reset_link")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(!isValid || isSending)
                    }
                }
            }
            .navigationTitle("forgot_password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @MainActor
    private func send() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        struct Request: Encodable { let email: String }

        do {
            let url = AppEnvironment.apiURL.appendingPathComponent("authentication/forgot-password")
            // The API answers the same whether the email exists or not.
            try await APIClient.shared.requestData(
                url,
                method: .post,
                body: JSONEncoder().encode(Request(email: trimmedEmail))
            )
            isSent = true
        } catch {
            errorMessage = mapError(error)
        }
    }
}

#Preview {
    LoginView()
}

