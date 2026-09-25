//
//  PushTokenService.swift
//  ApexPerformance
//

import Foundation
import FirebaseMessaging

enum PushTokenService {

    // The backend links the FCM token to the user from the bearer token,
    // so registration is skipped until the user is logged in.
    static func register(_ fcmToken: String) {
        guard let authToken = KeychainService.shared.getToken() else { return }

        Task {
            struct FCMTokenRequest: Encodable {
                let token: String
                let platform: String = "ios"
            }

            do {
                var request = URLRequest(url: AppEnvironment.apiURL.appendingPathComponent("fcm-tokens"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                request.httpBody = try JSONEncoder().encode(FCMTokenRequest(token: fcmToken))

                let (_, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse,
                      200..<300 ~= http.statusCode else {
                    throw URLError(.badServerResponse)
                }
            } catch {
                #if DEBUG
                print("❌ Failed to send FCM token to server: \(error)")
                #endif
            }
        }
    }

    static func registerCurrentToken() {
        Messaging.messaging().token { token, _ in
            if let token {
                register(token)
            }
        }
    }
}
