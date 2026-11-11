//
//  LiveActivityPushService.swift
//  ApexPerformance
//

import ActivityKit
import Foundation
import UIKit

/// Registers this iPhone's ActivityKit push tokens with the backend, so it
/// can start, update and end the Live Activity of a training in progress:
/// on the client's iPhone and on all the coach's iPhones, also when the
/// training is started on the web or on another device.
///
/// - The push-to-start token of the device (iOS 17.2+).
/// - The update token of every training activity, started here or by push,
///   for its training (a draft registers once linked to the saved training).
///
/// The device is its FCM token, registered before by `PushTokenService`.
/// See the backend's docs/LIVE_ACTIVITY_PUSH.md.
@MainActor
final class LiveActivityPushService {
    static let shared = LiveActivityPushService()
    private init() {}

    private typealias TrainingActivity = Activity<TrainingActivityAttributes>

    private var isStarted = false
    private var pushToStartToken: String?
    // Activity id -> its push token (hex).
    private var updateTokens: [String: String] = [:]
    private var observed: Set<String> = []
    // What the backend has for `sentForDevice`: "pushToStart" or a training id -> token.
    private var sent: [String: String] = [:]
    private var sentForDevice: String?

    /// From the app's launch, also the background launch iOS does for an
    /// activity started by push, so its token reaches the backend.
    func start() {
        guard !isStarted else { return }
        isStarted = true

        Task {
            for await data in TrainingActivity.pushToStartTokenUpdates {
                pushToStartToken = Self.hex(data)
                syncTokens()
            }
        }

        for activity in TrainingActivity.activities {
            observe(activity)
        }

        Task {
            for await activity in TrainingActivity.activityUpdates {
                observe(activity)
                activitiesChanged()
            }
        }

        // The login token in the keychain can be read again (unlocked), or the
        // app is open: whatever couldn't be sent before is sent now.
        for name in [UIApplication.protectedDataDidBecomeAvailableNotification,
                     UIApplication.didBecomeActiveNotification] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in LiveActivityPushService.shared.activitiesChanged() }
            }
        }

        activitiesChanged()
    }

    /// An activity started, was linked to its training or ended.
    func activitiesChanged() {
        endDuplicates()
        syncTokens()
    }

    /// The FCM token was (re)registered, e.g. after a login or a new token:
    /// the backend keeps Live Activity tokens per FCM token, so all are sent again.
    func deviceRegistered() {
        sent = [:]
        sentForDevice = nil
        activitiesChanged()
    }

    /// Logout: the backend forgets this device's Live Activity tokens. Called
    /// before the login token is deleted, which the request needs.
    nonisolated static func unregisterDevice() {
        guard let authToken = KeychainService.shared.getToken(),
              let deviceToken = PushTokenService.registeredToken else { return }

        struct Body: Encodable { let deviceToken: String }
        Task {
            _ = await send(path: "live-activity-tokens/remove", method: "POST",
                           body: Body(deviceToken: deviceToken), authToken: authToken)
            await MainActor.run {
                shared.sent = [:]
                shared.sentForDevice = nil
            }
        }
    }

    // MARK: - Private

    private func observe(_ activity: TrainingActivity) {
        guard observed.insert(activity.id).inserted else { return }

        Task {
            for await data in activity.pushTokenUpdates {
                updateTokens[activity.id] = Self.hex(data)
                syncTokens()
            }
        }
        Task {
            for await state in activity.activityStateUpdates where state == .ended || state == .dismissed {
                updateTokens[activity.id] = nil
                break
            }
        }
    }

    private static func isShown(_ activity: TrainingActivity) -> Bool {
        activity.activityState == .active || activity.activityState == .stale
    }

    /// The activity of each training on this iPhone. A push start can cross
    /// the training being started here: the one the app started itself
    /// (no `showsEndButton`) stays, otherwise the first.
    private func survivors() -> [String: TrainingActivity] {
        var result: [String: TrainingActivity] = [:]
        for activity in TrainingActivity.activities where Self.isShown(activity) {
            guard let id = activity.content.state.trainingId else { continue }
            if let kept = result[id], kept.attributes.showsEndButton == nil || activity.attributes.showsEndButton != nil {
                continue
            }
            result[id] = activity
        }
        return result
    }

    private func endDuplicates() {
        let kept = survivors()
        for activity in TrainingActivity.activities where Self.isShown(activity) {
            guard let id = activity.content.state.trainingId, let survivor = kept[id],
                  survivor.id != activity.id else { continue }
            updateTokens[activity.id] = nil
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func syncTokens() {
        guard let deviceToken = PushTokenService.registeredToken,
              let authToken = KeychainService.shared.getToken() else { return }

        if sentForDevice != deviceToken {
            sent = [:]
            sentForDevice = deviceToken
        }

        var wanted: [(key: String, body: TokenBody)] = []
        if let pushToStartToken {
            wanted.append(("pushToStart", TokenBody(deviceToken: deviceToken, kind: "pushToStart",
                                                    trainingId: nil, token: pushToStartToken)))
        }
        for (trainingId, activity) in survivors() {
            guard let token = updateTokens[activity.id] else { continue }
            wanted.append((trainingId, TokenBody(deviceToken: deviceToken, kind: "update",
                                                 trainingId: trainingId, token: token)))
        }

        for (key, body) in wanted where sent[key] != body.token {
            sent[key] = body.token
            Task {
                let ok = await Self.send(path: "live-activity-tokens", method: "PUT", body: body,
                                         authToken: authToken)
                // Sent again on the next change, unlock or opening of the app.
                if !ok, sent[key] == body.token { sent[key] = nil }
            }
        }
    }

    private struct TokenBody: Encodable {
        let deviceToken: String
        let kind: String
        let trainingId: String?
        let token: String
    }

    private nonisolated static func send<Body: Encodable>(path: String, method: String, body: Body,
                                                          authToken: String) async -> Bool {
        do {
            var request = URLRequest(url: AppEnvironment.apiURL.appendingPathComponent(path))
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(body)

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw URLError(.badServerResponse)
            }
            return true
        } catch {
            #if DEBUG
            print("❌ Live Activity token not sent (\(path)): \(error)")
            #endif
            return false
        }
    }

    private nonisolated static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}
