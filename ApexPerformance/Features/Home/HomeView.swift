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
    @ObservedObject private var profilePicture = ProfilePictureStore.shared
    @ObservedObject private var chatStore = ChatStore.shared

    @State private var selectedTab: AppTab = .appointments
    // Opens progress (body measurements) on the client's home.
    @State private var showsProgress = false
    @State private var hasSelectedFirstTab = false
    @State private var showsChat = false

    private var isClient: Bool {
        authManager.hasRole(role: "Client")
    }

    private var isCoach: Bool {
        authManager.hasRole(role: "Coach")
    }

    // Chat is between coaches and their clients.
    private var canChat: Bool {
        isClient || isCoach
    }

    private var canGetAppointments: Bool {
        authManager.hasPermission(permission: Permissions.canGetAppointments)
    }

    private var canGetAppointmentRequests: Bool {
        authManager.hasPermission(permission: Permissions.canGetAppointmentRequests)
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
            // Five tabs fit the tab bar, so requests open from appointments
            // when there are both, as for clients.
            if canGetAppointments {
                tabs.append(.appointments)
            } else if canGetAppointmentRequests {
                tabs.append(.appointmentRequests)
            }
            // Role-based like the web: coaches and administrators manage
            // trainings (with templates and records) and workouts.
            tabs.append(.trainings)
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

            if availableTabs.contains(.trainings) {
                Group {
                    if isClient {
                        CompletedTrainingsView()
                    } else {
                        StaffTrainingsView()
                    }
                }
                .tabItem {
                    Label("tab_trainings", systemImage: isClient ? "dumbbell" : "list.bullet.clipboard")
                }
                .tag(AppTab.trainings)
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

            UserProfileView()
                .tabItem {
                    Label {
                        Text("tab_profile")
                    } icon: {
                        profileTabImage
                    }
                }
                .tag(AppTab.profile)
        }
        .task {
            await profilePicture.refresh()
        }
        // Chat opens from a floating button on every tab.
        .overlay(alignment: .bottomTrailing) {
            if canChat {
                ChatFloatingButton(unreadCount: chatStore.unreadCount) {
                    showsChat = true
                }
                .padding(.trailing, 16)
                // Above the tab bar.
                .padding(.bottom, 62)
            }
        }
        .sheet(isPresented: $showsChat) {
            ChatListView(showsCloseButton: true)
        }
        .task {
            // The hub keeps the unread badge fresh while logged in.
            if canChat { chatStore.start() }
        }
        .onDisappear {
            chatStore.stop()
            NotificationInbox.shared.reset()
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

    // Small profile picture when the user has one, otherwise the person icon.
    private var profileTabImage: Image {
        if let icon = profilePicture.tabIcon {
            return Image(uiImage: icon)
        }
        return Image(systemName: "person")
    }

    private func openPendingTab() {
        guard var tab = notificationRouter.pendingTab else { return }
        notificationRouter.pendingTab = nil
        switch tab {
        case .chat:
            // Chat isn't a tab, it opens over the current one.
            if canChat { showsChat = true }
            return
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
            // Requests open from appointments when there is no requests tab.
            tab = .appointments
            notificationRouter.opensAppointmentRequests = true
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
