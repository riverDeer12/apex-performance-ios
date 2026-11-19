//
//  HomeView.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 18.12.2025..
//

import SwiftUI

struct HomeView: View {
    
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var notificationRouter = NotificationRouter.shared
    @ObservedObject private var profilePicture = ProfilePictureStore.shared
    @ObservedObject private var chatStore = ChatStore.shared

    @State private var selectedTab: AppTab = .appointments
    // Opens progress (body measurements) on the client's home.
    @State private var showsProgress = false
    @State private var hasSelectedFirstTab = false
    @State private var showsChat = false
    // Cooperation rules the client has to accept before using the app.
    @State private var rulesToAccept: CooperationRules?
    // A tab tapped in the tab bar opens at its first screen: a new identity
    // rebuilds it without the screens pushed on it before.
    @State private var tabResets: [AppTab: Int] = [:]
    @State private var tabRoots = TabRoots()

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

    // The bell is in the top bars of clients and of staff with appointments.
    private var showsNotificationBell: Bool {
        isClient || availableTabs.contains(.appointments)
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

        TabView(selection: tabBarSelection) {
            if availableTabs.contains(.home) {
                ClientHomeView(selectedTab: programmaticSelection, showsProgress: $showsProgress)
                    .tabRoot(.home, roots: tabRoots, resets: tabResets)
                    .tabItem {
                        Label("tab_home", systemImage: "house")
                    }
                    .tag(AppTab.home)
            }

            if availableTabs.contains(.appointments) {
                AppointmentsView()
                    .tabRoot(.appointments, roots: tabRoots, resets: tabResets)
                    .tabItem {
                        Label("tab_appointments", systemImage: "calendar")
                    }
                    .tag(AppTab.appointments)
            }

            if availableTabs.contains(.appointmentRequests) {
                AppointmentRequestsView()
                    .tabRoot(.appointmentRequests, roots: tabRoots, resets: tabResets)
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
                .tabRoot(.trainings, roots: tabRoots, resets: tabResets)
                .tabItem {
                    Label("tab_trainings", systemImage: isClient ? "dumbbell" : "list.bullet.clipboard")
                }
                .tag(AppTab.trainings)
            }

            if availableTabs.contains(.workouts) {
                WorkoutsView()
                    .tabRoot(.workouts, roots: tabRoots, resets: tabResets)
                    .tabItem {
                        Label("tab_workouts", systemImage: "dumbbell.fill")
                    }
                    .tag(AppTab.workouts)
            }

            if availableTabs.contains(.clients) {
                ClientsView()
                    .tabRoot(.clients, roots: tabRoots, resets: tabResets)
                    .tabItem {
                        Label("tab_clients", systemImage: "person.3")
                    }
                    .tag(AppTab.clients)
            }

            UserProfileView()
                .tabRoot(.profile, roots: tabRoots, resets: tabResets)
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
        // Chat and the bell are round buttons in the top bar of every screen
        // of the tabs (topBarActions), so nothing covers the content. Set
        // before the sheet: the chat sheet has neither.
        .environment(\.openChat, canChat ? OpenChatAction(action: { showsChat = true }) : nil)
        .environment(\.showsNotificationBell, showsNotificationBell)
        .sheet(isPresented: $showsChat) {
            ChatListView(showsCloseButton: true)
        }
        // A popup over everything, also over the top bars and the tabs:
        // accepting or logging out are the only ways out.
        .overlay {
            if let rules = rulesToAccept {
                CooperationRulesView(rules: rules) { _ in
                    withAnimation { rulesToAccept = nil }
                } onLogout: {
                    rulesToAccept = nil
                    PushTokenService.unregister()
                    authManager.logout()
                }
            }
        }
        .task {
            await checkRules()
        }
        // A new version of the rules can come while the app is in the background.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await checkRules() }
            }
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
        // Trainings kept on the device without a connection, above the tabs.
        .overlay(alignment: .bottom) {
            TrainingSaveBanner()
                .padding(.bottom, 58)
        }
        .onAppear {
            // Clients start on home, others on their first tab.
            if !hasSelectedFirstTab || !availableTabs.contains(selectedTab) {
                hasSelectedFirstTab = true
                selectedTab = availableTabs.first ?? .profile
            }
            tabRoots.selectedTab = selectedTab
            openPendingTab()
        }
        .onChange(of: notificationRouter.pendingTab) {
            openPendingTab()
        }
    }

    /// The selection as the tab bar changes it: only the user's taps come
    /// through here (notifications, widgets and Live Activities set
    /// selectedTab directly and open their screen in the tab). A tab left on
    /// a pushed screen opens at its first screen again; tapping the open tab
    /// goes back to its first screen by itself.
    private var tabBarSelection: Binding<AppTab> {
        Binding {
            selectedTab
        } set: { tab in
            if tab != selectedTab, tabRoots.isShowingPushedScreen(tab) {
                if tab == .home { showsProgress = false }
                tabRoots.reset(tab)
                tabResets[tab, default: 0] += 1
            }
            select(tab)
        }
    }

    /// Changes the tab from code (notifications, home's shortcuts).
    private var programmaticSelection: Binding<AppTab> {
        Binding { selectedTab } set: { select($0) }
    }

    private func select(_ tab: AppTab) {
        tabRoots.selectedTab = tab
        selectedTab = tab
    }

    // Small profile picture when the user has one, otherwise the person icon.
    private var profileTabImage: Image {
        if let icon = profilePicture.tabIcon {
            return Image(uiImage: icon)
        }
        return Image(systemName: "person")
    }

    /// Asks a client on private coaching to accept the cooperation rules.
    @MainActor
    private func checkRules() async {
        guard isClient, rulesToAccept == nil,
              let rules = try? await CooperationRules.load(), rules.needsAcceptance else { return }
        showsChat = false
        withAnimation { rulesToAccept = rules }
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
        case .home where !availableTabs.contains(.home):
            // Staff have no home: their first tab.
            tab = availableTabs.first ?? .profile
        case .appointments where !availableTabs.contains(.appointments):
            // Without the appointments tab (clients without the permission) the requests open.
            tab = availableTabs.contains(.appointmentRequests) ? .appointmentRequests : (availableTabs.first ?? .profile)
            notificationRouter.pendingAppointmentId = nil
        case .appointmentRequests where !availableTabs.contains(.appointmentRequests):
            // Requests open from appointments when there is no requests tab.
            tab = .appointments
            notificationRouter.opensAppointmentRequests = true
        default:
            break
        }
        if availableTabs.contains(tab) {
            select(tab)
        }
    }
}

/// Whether each tab's first screen is on screen, told by the screens
/// themselves (topBarActions(isTabRoot:)). Not observed: only read when a
/// tab is tapped.
final class TabRoots {
    /// Set before selectedTab changes, so a first screen that disappears
    /// because another tab was opened isn't taken for one under a pushed screen.
    var selectedTab: AppTab?
    private var isVisible: [AppTab: Bool] = [:]

    func set(_ tab: AppTab, visible: Bool) {
        if visible {
            isVisible[tab] = true
        } else if tab == selectedTab {
            // Gone while its tab is open: a screen was pushed over it.
            isVisible[tab] = false
        }
    }

    /// A screen is pushed over the tab's first screen.
    func isShowingPushedScreen(_ tab: AppTab) -> Bool {
        isVisible[tab] == false
    }

    func reset(_ tab: AppTab) {
        isVisible[tab] = nil
    }
}

private extension View {
    /// A tab's content: its first screen reports whether it is visible, and
    /// a new reset count rebuilds it at its first screen.
    func tabRoot(_ tab: AppTab, roots: TabRoots, resets: [AppTab: Int]) -> some View {
        environment(\.tabRootVisibility, TabRootVisibilityAction { roots.set(tab, visible: $0) })
            .id(resets[tab, default: 0])
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthManager())
}
