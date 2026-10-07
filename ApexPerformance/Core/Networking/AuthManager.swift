//
//  AuthManager.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 16.12.2025..
//

import Foundation

final class AuthManager: ObservableObject {
    
    @Published var isAuthenticated = false
    // Set when the user was logged out because the session expired,
    // so login can tell why.
    @Published var sessionExpired = false
    
    private var sessionExpiredObserver: NSObjectProtocol?
    
    init() {
        // UI tests (App Store screenshots) start logged out,
        // so each test can log in with its own account.
        if ProcessInfo.processInfo.arguments.contains("-uiTestResetLogin") {
            KeychainService.shared.deleteToken()
        }
        validateToken()
        
        sessionExpiredObserver = NotificationCenter.default.addObserver(
            forName: .sessionExpired, object: nil, queue: .main
        ) { [weak self] _ in
            self?.expireSession()
        }
    }
    
    deinit {
        if let sessionExpiredObserver {
            NotificationCenter.default.removeObserver(sessionExpiredObserver)
        }
    }
    
    /// Logs out a user whose session ended (401 or expired token)
    /// and shows login with a message.
    func expireSession() {
        guard isAuthenticated else { return }
        KeychainService.shared.deleteToken()
        sessionExpired = true
        isAuthenticated = false
    }
    
    /// Checks the token again, e.g. when the app comes back to the foreground.
    func checkSession() {
        guard isAuthenticated else { return }
        if let token = KeychainService.shared.getToken(), JWTDecoder.isTokenValid(token) {
            return
        }
        expireSession()
    }
    
    var token: String? {
        KeychainService.shared.getToken()
    }
    
    var userPermissions: [String] {
        guard let token = KeychainService.shared.getToken() else { return [] }
        return JWTDecoder.getUserPermissions(token: token)
    }
    
    var userRole: String {
        guard let token = KeychainService.shared.getToken() else { return "" }
        return JWTDecoder.getUserRole(token: token)
    }
    
    var username: String {
        guard let token = KeychainService.shared.getToken() else { return "" }
        return JWTDecoder.getUsername(token: token)
    }
    
    func validateToken() {
        guard let token = KeychainService.shared.getToken(),
              JWTDecoder.isTokenValid(token) else {
            logout()
            return
        }
        
        isAuthenticated = true
    }
    
    func login(token: String) {
        KeychainService.shared.saveToken(token)
        sessionExpired = false
        isAuthenticated = true
    }
    
    func logout() {
        KeychainService.shared.deleteToken()
        isAuthenticated = false
    }
    
    func hasPermission(permission: String) -> Bool {
        return userPermissions.contains(permission)
    }
    
    func hasRole(role: String) -> Bool{
        return userRole == role;
    }
    
    func sendLoginRequest(username: String, password: String) async throws -> LoginResponse {
        
        let url = AppEnvironment.apiURL.appendingPathComponent("authentication/login")
                
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            LoginRequest(username: username, password: password)
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse,
              200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(LoginResponse.self, from: data)
    }
}
