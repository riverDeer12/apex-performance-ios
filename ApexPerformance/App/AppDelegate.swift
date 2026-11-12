//
//  AppDelegate.swift
//  ApexPerformance
//
//  Created for Firebase Cloud Messaging integration
//

import UIKit
import FirebaseCore
import FirebaseCrashlytics
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        // Configure Firebase
        FirebaseApp.configure()
        // Crash reports (Crashlytics) only from TestFlight and App Store builds.
        #if DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        #endif
        
        // Set up notifications
        UNUserNotificationCenter.current().delegate = self
        Self.registerNotificationCategories()
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                #if DEBUG
                if granted {
                    print("✅ Notification permission granted")
                } else {
                    print("❌ Notification permission denied")
                }
                #endif
            }
        )
        
        application.registerForRemoteNotifications()
        
        // Set FCM messaging delegate
        Messaging.messaging().delegate = self

        // Live Activities of trainings started by push (client, coach's other iPhones).
        if application.isProtectedDataAvailable {
            KeychainService.shared.makeAvailableInBackground()
        }
        MainActor.assumeIsolated { LiveActivityPushService.shared.start() }
        
        return true
    }
    
    // MARK: - FCM Token
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            PushTokenService.register(token)
        }
    }
    
    // MARK: - APNs Token
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
        #endif
    }

    // MARK: - Handle Notifications

    // Called when notification arrives while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // A message of the chat that is open on screen isn't shown again.
        let userInfo = notification.request.content.userInfo
        if userInfo["type"] as? String == "chat_message",
           let id = (userInfo["conversationId"] as? String).flatMap(UUID.init(uuidString:)),
           MainActor.assumeIsolated({ ChatStore.shared.openConversationId == id }) {
            completionHandler([])
            return
        }

        // The bell shows the new notification too.
        Task { @MainActor in await NotificationInbox.shared.refreshCount() }

        // Show notification even when app is in foreground
        completionHandler([[.banner, .sound, .badge]])
    }

    // MARK: - Training end reminder

    // Category of the backend's reminder that a training started an hour ago is
    // still running (aps.category), with "End training", which ends it without
    // opening the app.
    static let trainingEndReminderCategory = "TRAINING_END_REMINDER"
    static let endTrainingAction = "END_TRAINING"

    private static func registerNotificationCategories() {
        let endTraining = UNNotificationAction(identifier: endTrainingAction,
                                               title: String(localized: "end_training"),
                                               options: [.authenticationRequired])
        let reminder = UNNotificationCategory(identifier: trainingEndReminderCategory,
                                              actions: [endTraining], intentIdentifiers: [],
                                              options: [])
        UNUserNotificationCenter.current().setNotificationCategories([reminder])
    }

    /// Ends the training of the reminder (PUT trainings/{id}/times with its
    /// start and the end now) and its Live Activity on this iPhone. If that
    /// fails, the reminder is shown again so the coach can retry or open it.
    @MainActor
    private static func endTraining(from notification: UNNotification) async {
        let userInfo = notification.request.content.userInfo
        guard let id = (userInfo["trainingId"] as? String).flatMap(UUID.init(uuidString:)),
              let startedAt = (userInfo["startedAt"] as? String).flatMap(date(fromISO8601:)) else { return }

        do {
            try await Training.endFromReminder(id: id, startedAt: startedAt)
        } catch {
            #if DEBUG
            print("❌ Training \(id) could not be ended from the reminder: \(error)")
            #endif
            let request = UNNotificationRequest(identifier: UUID().uuidString,
                                                content: notification.request.content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    // "2026-11-11T10:00:00.250Z", also without the milliseconds.
    private static func date(fromISO8601 string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    // Called when user taps on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // "End training" of the reminder: the app stays in the background
        // until the training was ended.
        if response.actionIdentifier == Self.endTrainingAction {
            let notification = response.notification
            Task { @MainActor in
                await Self.endTraining(from: notification)
                completionHandler()
            }
            return
        }

        let userInfo = response.notification.request.content.userInfo
        if let type = userInfo["type"] as? String {
            let conversationId = userInfo["conversationId"] as? String
            let trainingId = userInfo["trainingId"] as? String
            Task { @MainActor in
                NotificationRouter.shared.handle(notificationType: type, conversationId: conversationId,
                                                 trainingId: trainingId)
            }
        }

        completionHandler()
    }
}
