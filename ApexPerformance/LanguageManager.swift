//
//  LanguageManager.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic
//

import Foundation

enum LanguageManager {
    static func getDefaultLanguage() -> String {
        // Check if language is already saved
        if let saved = UserDefaults.standard.string(forKey: "appLanguage") {
            return saved
        }
        
        // Detect if user has Croatian locale (including en-HR)
        let locale = Locale.current.identifier
        let preferredLanguages = Locale.preferredLanguages
        
        // Check if any preferred language contains "hr" (Croatian)
        if preferredLanguages.contains(where: { $0.lowercased().contains("hr") }) {
            return "hr"
        }
        
        // Check if current locale is Croatia-based
        if locale.lowercased().contains("hr") {
            return "hr"
        }
        
        // Check if any preferred language contains "it" (Italian)
        if preferredLanguages.contains(where: { $0.lowercased().contains("it") }) {
            return "it"
        }
        
        // Check if current locale is Italy-based
        if locale.lowercased().contains("it") {
            return "it"
        }
        
        return "en"
    }
}
