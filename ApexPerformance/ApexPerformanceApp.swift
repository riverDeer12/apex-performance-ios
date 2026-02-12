//
//  ApexPerformanceApp.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 15.12.2025..
//

import SwiftUI

@main struct ApexPerformanceApp: App {
    
    @StateObject private var authManager = AuthManager()
    @StateObject private var toastManager = ToastManager()
    
    @AppStorage("appLanguage") private var appLanguage: String = "en"
    
    @State private var refreshID = UUID()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(refreshID)
                .environmentObject(authManager)
                .environmentObject(toastManager)
                .environment(\.locale, Locale(identifier: appLanguage))
                .onChange(of: appLanguage) {
                    refreshID = UUID()
                }
                .overlay(alignment: .bottom) {
                    if let toast = toastManager.toast {
                        ToastView(message: toast.message, toastType: toast.type)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 60)
                    }
                }
                .animation(.easeInOut, value: toastManager.toast != nil)
        }
    }
}
