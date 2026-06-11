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
                            .frame(
                                maxWidth: geo.size.width * 0.6,
                                maxHeight: geo.size.height * 0.18
                            )
                        
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
                                            .tint(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.apexMainColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoading)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 0)
                }
                .frame(minHeight: geo.size.height)
            }
        }
    }
}

#Preview {
    LoginView()
}

