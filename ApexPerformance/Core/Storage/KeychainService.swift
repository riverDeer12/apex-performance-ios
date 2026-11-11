//
//  KeychainService.swift
//  ApexPerformance
//
//

import Foundation
import Security

final class KeychainService {
    
    static let shared = KeychainService()
    private init() {}
    
    private let service = "software.rdd.jwt"
    
    func saveToken(_ token: String) {
        let data = Data(token.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "accessToken",
            kSecValueData as String: data,
            kSecAttrAccessible as String: Self.accessibility
        ]
        
        SecItemDelete(query as CFDictionary) // overwrite
        SecItemAdd(query as CFDictionary, nil)
    }

    // Readable after the first unlock, also while the iPhone is locked: a
    // training's Live Activity started by push launches the app in the
    // background, which then registers the activity with the backend.
    private static let accessibility = kSecAttrAccessibleAfterFirstUnlock

    /// Tokens saved before by older versions are readable only while unlocked.
    func makeAvailableInBackground() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "accessToken"
        ]
        SecItemUpdate(query as CFDictionary,
                      [kSecAttrAccessible as String: Self.accessibility] as CFDictionary)
    }
    
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "accessToken",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataRef)
        
        guard status == errSecSuccess,
              let data = dataRef as? Data else {
            return nil
        }
        
        return String(decoding: data, as: UTF8.self)
    }
    
    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "accessToken"
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

