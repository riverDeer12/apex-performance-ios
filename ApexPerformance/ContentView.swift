//
//  ContentView.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 15.12.2025..
//

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.scenePhase) private var scenePhase
    
    // Newer App Store version found when the app started.
    @State private var availableUpdate: AppUpdateChecker.AvailableUpdate?
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                HomeView()
            } else {
                LoginView()
            }
        }
        .task {
            availableUpdate = await AppUpdateChecker.availableUpdate()
        }
        // A token can expire while the app is in the background.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                authManager.checkSession()
            }
        }
        .alert(
            "update_available_title",
            isPresented: Binding(
                get: { availableUpdate != nil },
                set: { if !$0 { availableUpdate = nil } }
            ),
            presenting: availableUpdate
        ) { update in
            Button("update") {
                AppStoreProductPresenter.show(update)
            }
            Button("later", role: .cancel) {}
        } message: { update in
            Text("update_available_message \(update.version)")
        }
    }
}

#Preview {
    ContentView()
}
