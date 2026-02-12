//
//  AppEnvironment.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 24.12.2025..
//

import Foundation

enum AppEnvironment {
    
    private static func value<T>(for key: String) -> T {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? T else {
            fatalError("Missing or invalid Info.plist value for key: \(key)")
        }
        return value
    }
        
    static let apiURL: URL = {
        let string: String = value(for: "API_URL")
        
        guard let url = URL(string: string) else {
            fatalError("Invalid API_URL: \(string)")
        }
        
        return url
    }()
    
    
}
