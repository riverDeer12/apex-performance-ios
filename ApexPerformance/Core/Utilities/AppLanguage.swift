//
//  AppLanguage.swift
//  ApexPerformance
//

import SwiftUI

/// Language of the app, picked in the app (profile or login) at any time.
/// "System" follows the device's language like before.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, hr, en, it

    static let storageKey = "appLanguage"

    // Languages the app is translated to.
    private static let supported = ["hr", "en", "it"]

    var id: String { rawValue }

    /// Name in the language itself, so anyone finds their language.
    var nativeName: String {
        switch self {
        case .system: ""
        case .hr: "Hrvatski"
        case .en: "English"
        case .it: "Italiano"
        }
    }

    /// Picked language; UI tests can pass "-appLanguage en".
    static var selected: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    /// Code of the language the app runs in, e.g. "hr".
    static var current: String {
        selected == .system ? systemLanguage : selected.rawValue
    }

    static var locale: Locale {
        Locale(identifier: current)
    }

    // The device's language (or the app's language in iOS settings) when
    // the app has it, otherwise English.
    private static var systemLanguage: String {
        Bundle.preferredLocalizations(from: supported, forPreferences: Locale.preferredLanguages).first ?? "en"
    }

    /// Switches the app's texts to the picked language; call at launch.
    static func apply() {
        LanguageBundle.use(current)
    }

    /// Picks a language: texts change right away, pushes come in it from now on.
    static func select(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
        apply()
        PushTokenService.registerCurrentToken()
    }
}

/// Main bundle that looks texts up in the picked language's table.
private final class LanguageBundle: Bundle, @unchecked Sendable {
    nonisolated(unsafe) private static var languageBundle: Bundle?

    static func use(_ language: String) {
        if !(Bundle.main is LanguageBundle) {
            object_setClass(Bundle.main, LanguageBundle.self)
        }
        languageBundle = Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
    }

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let languageBundle = Self.languageBundle {
            return languageBundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

/// Menu with the app's languages, e.g. on login and in the profile.
struct LanguageMenu<Label: View>: View {
    @AppStorage(AppLanguage.storageKey) private var language = AppLanguage.system.rawValue
    @ViewBuilder var label: () -> Label

    var body: some View {
        Menu {
            Picker(selection: Binding(
                get: { AppLanguage(rawValue: language) ?? .system },
                set: { AppLanguage.select($0) }
            )) {
                ForEach(AppLanguage.allCases) { option in
                    if option == .system {
                        Text("device_language").tag(option)
                    } else {
                        Text(verbatim: option.nativeName).tag(option)
                    }
                }
            } label: {
                EmptyView()
            }
        } label: {
            label()
        }
    }
}
