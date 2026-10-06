//
//  HomeView.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 18.12.2025..
//

import SwiftUI

struct HomeView: View {
    
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var notificationRouter = NotificationRouter.shared

    @State private var selectedTab: AppTab = .appointments
    // Opens progress (body measurements) on the client's home.
    @State private var showsProgress = false
    @State private var hasSelectedFirstTab = false

    private var isClient: Bool {
        authManager.hasRole(role: "Client")
    }

    private var canGetAppointments: Bool {
        authManager.hasPermission(permission: Permissions.canGetAppointments)
    }

    private var availableTabs: [AppTab] {
        var tabs: [AppTab] = []
        if isClient {
            // Clients: home, appointments, trainings and profile. Sent requests
            // open from appointments, body measurements from home (progress).
            tabs.append(.home)
            if canGetAppointments {
                tabs.append(.appointments)
            } else {
                tabs.append(.appointmentRequests)
            }
            tabs.append(.trainings)
        } else {
            if canGetAppointments { tabs.append(.appointments) }
            if authManager.hasPermission(permission: Permissions.canGetAppointmentRequests) {
                tabs.append(.appointmentRequests)
            }
            // Role-based like the web: coaches and administrators manage workouts.
            tabs.append(.workouts)
            tabs.append(.clients)
        }
        tabs.append(.profile)
        return tabs
    }

    var body: some View {

        TabView(selection: $selectedTab) {
            if availableTabs.contains(.home) {
                ClientHomeView(selectedTab: $selectedTab, showsProgress: $showsProgress)
                    .tabItem {
                        Label("tab_home", systemImage: "house")
                    }
                    .tag(AppTab.home)
            }

            if availableTabs.contains(.appointments) {
                AppointmentsView()
                    .tabItem {
                        Label("tab_appointments", systemImage: "calendar")
                    }
                    .tag(AppTab.appointments)
            }

            if availableTabs.contains(.appointmentRequests) {
                AppointmentRequestsView()
                    .tabItem {
                        Label("tab_requests", systemImage: "calendar.badge.clock")
                    }
                    .tag(AppTab.appointmentRequests)
            }

            if availableTabs.contains(.workouts) {
                WorkoutsView()
                    .tabItem {
                        Label("tab_workouts", systemImage: "dumbbell.fill")
                    }
                    .tag(AppTab.workouts)
            }

            if availableTabs.contains(.clients) {
                ClientsView()
                    .tabItem {
                        Label("tab_clients", systemImage: "person.3")
                    }
                    .tag(AppTab.clients)
            }

            if availableTabs.contains(.trainings) {
                CompletedTrainingsView()
                    .tabItem {
                        Label("tab_trainings", systemImage: "dumbbell")
                    }
                    .tag(AppTab.trainings)
            }

            UserProfileView()
                .tabItem {
                    Label("tab_profile", systemImage: "person")
                }
                .tag(AppTab.profile)
        }
        .tint(.apexAccent)
        .onAppear {
            // Clients start on home, others on their first tab.
            if !hasSelectedFirstTab || !availableTabs.contains(selectedTab) {
                hasSelectedFirstTab = true
                selectedTab = availableTabs.first ?? .profile
            }
            openPendingTab()
        }
        .onChange(of: notificationRouter.pendingTab) {
            openPendingTab()
        }
    }

    private func openPendingTab() {
        guard var tab = notificationRouter.pendingTab else { return }
        notificationRouter.pendingTab = nil
        switch tab {
        case .bodyMeasurements:
            // Clients see measurements in progress on home,
            // coaches through their clients list.
            if isClient {
                tab = .home
                showsProgress = true
            } else {
                tab = .clients
            }
        case .appointmentRequests where !availableTabs.contains(.appointmentRequests):
            // Clients open their sent requests from appointments.
            tab = .appointments
        default:
            break
        }
        if availableTabs.contains(tab) {
            selectedTab = tab
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthManager())
}
