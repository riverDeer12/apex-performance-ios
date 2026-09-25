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

    private var availableTabs: [AppTab] {
        var tabs: [AppTab] = []
        if authManager.hasPermission(permission: Permissions.canGetAppointments) { tabs.append(.appointments) }
        if authManager.hasPermission(permission: Permissions.canGetAppointmentRequests) { tabs.append(.appointmentRequests) }
        if authManager.hasPermission(permission: Permissions.canGetWorkouts) { tabs.append(.workouts) }
        if !authManager.hasRole(role: "Client") { tabs.append(.clients) }
        if authManager.hasRole(role: "Client") { tabs.append(.bodyMeasurements) }
        tabs.append(.profile)
        return tabs
    }

    var body: some View {

        TabView(selection: $selectedTab) {
            if availableTabs.contains(.appointments) {
                AppointmentsView()
                    .tabItem {
                        Label("", systemImage: "calendar")
                    }
                    .tag(AppTab.appointments)
            }

            if availableTabs.contains(.appointmentRequests) {
                AppointmentRequestsView()
                    .tabItem {
                        Label("", systemImage: "calendar.badge.clock")
                    }
                    .tag(AppTab.appointmentRequests)
            }

            if availableTabs.contains(.workouts) {
                WorkoutsView()
                    .tabItem {
                        Label("", systemImage: "person.3")
                    }
                    .tag(AppTab.workouts)
            }

            if availableTabs.contains(.clients) {
                ClientsView()
                    .tabItem {
                        Label("", systemImage: "person.3")
                    }
                    .tag(AppTab.clients)
            }

            if availableTabs.contains(.bodyMeasurements) {
                MyBodyMeasurementsView()
                    .tabItem {
                        Label("", systemImage: "ruler")
                    }
                    .tag(AppTab.bodyMeasurements)
            }

            UserProfileView()
                .tabItem {
                    Label("", systemImage: "person")
                }
                .tag(AppTab.profile)
        }
        .tint(.apexMainColor)
        .onAppear {
            if !availableTabs.contains(selectedTab) {
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
        // Coaches see measurements through their clients list.
        if tab == .bodyMeasurements && !availableTabs.contains(.bodyMeasurements) {
            tab = .clients
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
