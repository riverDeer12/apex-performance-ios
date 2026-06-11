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
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                
                if let authToken = KeychainService.shared.getToken() {
                    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                }
                
                let tokenRequest = FCMTokenRequest(token: token)
                request.httpBody = try JSONEncoder().encode(tokenRequest)
                
                print("🌐 Sending FCM token to server...")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let http = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                print("📥 FCM Token Response Status: \(http.statusCode)")
                if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                    print("📥 FCM Token Response Body: \(responseString)")
                }
                
                guard 200..<300 ~= http.statusCode else {
                    throw URLError(.badServerResponse)
                }
                
                print("✅ FCM token sent to server successfully")
            } catch {
                print("❌ Failed to send FCM token to server: \(error)")
                // Don't fail silently - this is important for debugging but not critical for app functionality
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
