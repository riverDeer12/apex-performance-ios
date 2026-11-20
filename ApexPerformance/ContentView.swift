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
        // Trainings saved without a connection go to the server once it is back.
        .task {
            TrainingSaveQueue.shared.start()
            await TrainingSaveQueue.shared.syncAll()
            // Trainings on the lock screen or started here: still running,
            // and their activity still shown (started again if it went away).
            if authManager.isAuthenticated && TrainingLiveActivity.hasActivities {
                _ = try? await Training.loadAll()
            }
        }
        // A token can expire while the app is in the background.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                authManager.checkSession()
                // Notifications may have come while the app was in the background.
                if authManager.isAuthenticated {
                    Task { await NotificationInbox.shared.refreshCount() }
                    // A training on the lock screen may have ended elsewhere,
                    // or its activity went away while the phone was locked
                    // (started again). After the waiting trainings are saved,
                    // so a training started meanwhile is seen as running.
                    Task {
                        await TrainingSaveQueue.shared.syncAll()
                        if TrainingLiveActivity.hasActivities {
                            _ = try? await Training.loadAll()
                        }
                    }
                }
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
