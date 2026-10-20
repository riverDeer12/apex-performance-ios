//
//  AppDelegate.swift
//  ApexPerformance
//
//  Created for Firebase Cloud Messaging integration
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Set up notifications
        UNUserNotificationCenter.current().delegate = self
        
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

    // Called when user taps on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
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
