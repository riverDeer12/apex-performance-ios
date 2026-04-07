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
        
        // Get the device's preferred language (first in the list)
        guard let preferredLanguage = Locale.preferredLanguages.first else {
            return "en" // Fallback to English
        }
        
        // Extract language code (e.g., "en" from "en-US" or "hr" from "hr-HR")
        let languageCode = String(preferredLanguage.prefix(2))
        
        // Check if we support this language
        let supportedLanguages = ["en", "hr", "it"]
        if supportedLanguages.contains(languageCode) {
            return languageCode
        }
        
        // Default to English if language not supported
        return "en"
    }
}
