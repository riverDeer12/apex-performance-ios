
import SwiftUI
import FirebaseCore

@main struct ApexPerformanceApp: App {
    // AppDelegate connection to handle Firebase and push notifications
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var authManager = AuthManager()
    @StateObject private var toastManager = ToastManager()
    
    // Animated splash shown over the app right after the launch screen.
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(toastManager)
                .preferredColorScheme(.light)
                .overlay(alignment: .bottom) {
                    if let toast = toastManager.toast {
                        ToastView(messageKey: toast.message, toastType: toast.type)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 60)
                    }
                }
                .animation(.easeInOut, value: toastManager.toast != nil)
                .overlay {
                    if showSplash {
                        SplashView { showSplash = false }
                    }
                }
        }
    }
}
