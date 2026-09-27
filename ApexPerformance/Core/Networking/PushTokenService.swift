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
                let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
                let osVersion = PushTokenService.osVersion
                let deviceModel = PushTokenService.deviceModelIdentifier
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

    private static var osVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    // Hardware identifier such as "iPhone17,3"; the simulator reports the simulated device's.
    private static var deviceModelIdentifier: String {
        if let simulatorModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatorModel
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    static func registerCurrentToken() {
        Messaging.messaging().token { token, _ in
            if let token {
                register(token)
            }
        }
    }

    // Invalidates this device's token so the backend can no longer reach the
    // logged-out user here; the next login registers a fresh token.
    static func unregister() {
        Messaging.messaging().deleteToken { error in
            #if DEBUG
            if let error {
                print("❌ Failed to delete FCM token: \(error)")
            }
            #endif
        }
    }
}
