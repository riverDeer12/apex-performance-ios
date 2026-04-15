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
                if granted {
                    print("✅ Notification permission granted")
                } else {
                    print("❌ Notification permission denied")
                }
            }
        )
        
        application.registerForRemoteNotifications()
        
        // Set FCM messaging delegate
        Messaging.messaging().delegate = self
        
        return true
    }
    
    // MARK: - FCM Token
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔑 FCM Token: \(fcmToken ?? "nil")")
        
        // Send this token to your backend server
        if let token = fcmToken {
            sendTokenToServer(token)
        }
    }
    
    // MARK: - APNs Token
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        print("📱 APNs Token registered")
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - Handle Notifications
    
    // Called when notification arrives while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("📩 Notification received in foreground: \(userInfo)")
        
        // Show notification even when app is in foreground
        completionHandler([[.banner, .sound, .badge]])
    }
    
    // Called when user taps on notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("👆 Notification tapped: \(userInfo)")
        
        // Handle notification tap
        handleNotificationTap(userInfo: userInfo)
        
        completionHandler()
    }
    
    // MARK: - Helper Methods
    
    private func sendTokenToServer(_ token: String) {
        // Send FCM token to your backend
        Task {
            do {
                let url = AppEnvironment.apiURL.appendingPathComponent("fcm-tokens")
                
                struct FCMTokenRequest: Encodable {
                    let token: String
                    let platform: String = "ios"
                }
                
                let request = FCMTokenRequest(token: token)
                let _: StatusResponse = try await APIClient.shared.request(
                    url,
                    method: .post,
                    body: JSONEncoder().encode(request)
                )
                
                print("✅ FCM token sent to server successfully")
            } catch {
                print("❌ Failed to send FCM token to server: \(error)")
            }
        }
    }
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // Handle deep linking based on notification data
        // You can post notifications to navigate to specific screens
        
        if let type = userInfo["type"] as? String {
            switch type {
            case "appointment_request":
                // Navigate to appointment requests screen
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToAppointmentRequests"),
                    object: nil,
                    userInfo: userInfo
                )
                
            case "appointment_approved":
                // Navigate to appointments screen
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToAppointments"),
                    object: nil,
                    userInfo: userInfo
                )
                
            case "body_measurement":
                // Navigate to measurements screen
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToBodyMeasurements"),
                    object: nil,
                    userInfo: userInfo
                )
                
            default:
                print("⚠️ Unknown notification type: \(type)")
            }
        }
    }
}
