
import SwiftUI

@main struct ApexPerformanceApp: App {
    
    @StateObject private var authManager = AuthManager()
    @StateObject private var toastManager = ToastManager()
    
    @AppStorage("appLanguage") private var appLanguage: String = LanguageManager.getDefaultLanguage()
    
    @State private var refreshID = UUID()
    
    init() {
        // TEMPORARY: Force reset language detection (remove after testing)
        print("=== Language Debug ===")
        print("Current saved language: \(UserDefaults.standard.string(forKey: "appLanguage") ?? "none")")
        print("Current locale: \(Locale.current.identifier)")
        print("Preferred languages: \(Locale.preferredLanguages)")
        
        // Force clear ALL language-related data
        UserDefaults.standard.removeObject(forKey: "hasSetLanguageExplicitly")
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        
        // Now detect and set the language
        let detectedLanguage = LanguageManager.getDefaultLanguage()
        UserDefaults.standard.set(detectedLanguage, forKey: "appLanguage")
        print("🌐 Auto-detected and set language to: \(detectedLanguage)")
        print("=====================")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(refreshID)
                .environmentObject(authManager)
                .environmentObject(toastManager)
                .environment(\.locale, Locale(identifier: appLanguage))
                .onChange(of: appLanguage) {
                    // Mark that user has explicitly changed the language
                    UserDefaults.standard.set(true, forKey: "hasSetLanguageExplicitly")
                    refreshID = UUID()
                }
                .overlay(alignment: .bottom) {
                    if let toast = toastManager.toast {
                        ToastView(messageKey: toast.message, toastType: toast.type)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 60)
                    }
                }
                .animation(.easeInOut, value: toastManager.toast != nil)
        }
    }
}
