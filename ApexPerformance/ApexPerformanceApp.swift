
import SwiftUI
import FirebaseCore

@main struct ApexPerformanceApp: App {
    // AppDelegate connection to handle Firebase and push notifications
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var authManager = AuthManager()
    @StateObject private var toastManager = ToastManager()
    
    // Animated splash shown over the app right after the launch screen.
    @State private var showSplash = true
    
    // Light, dark or system, picked in the user's profile.
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    // Picked in the app at any time; the screens are rebuilt in it.
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system.rawValue
    
    init() {
        AppLanguage.apply()
        ApexFont.applyToNavigationBars()
        #if DEBUG
        // App Store screenshots: invented data instead of the test server's.
        if DemoAPI.isEnabled { DemoAPI.start() }
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, AppLanguage.locale)
                .id(language)
                .environmentObject(authManager)
                .environmentObject(toastManager)
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
                .onAppear { applyAppearance() }
                .onChange(of: appearance) { applyAppearance() }
        }
    }
    
    // Set on the windows instead of preferredColorScheme, which doesn't
    // switch back to the system setting reliably once dark or light was set.
    private func applyAppearance() {
        let style: UIUserInterfaceStyle = switch appearance {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.overrideUserInterfaceStyle = style }
    }
}
