//
//  NotificationsView.swift
//  ApexPerformance
//

import SwiftUI

/// Push notification kept for the user (docs/NOTIFICATIONS_API.md in the backend).
struct AppNotification: Identifiable, Decodable, Hashable {
    let id: UUID
    let type: String
    let title: String
    let body: String
    let data: [String: String]
    let createdAt: Date
    var readAt: Date?

    var isRead: Bool { readAt != nil }

    var systemImage: String {
        switch type {
        case "appointment_request", "appointment_updated": "calendar"
        case "body_measurement": "ruler"
        case "client_goal": "scope"
        case "monthly_review", "monthly_review_reminder": "doc.text"
        case "training": "dumbbell"
        default: "bell"
        }
    }
}

/// Notifications of the logged user and the unread count for the bell.
@MainActor
final class NotificationInbox: ObservableObject {
    static let shared = NotificationInbox()

    @Published private(set) var notifications: [AppNotification] = []
    @Published private(set) var unreadCount = 0
    @Published private(set) var hasLoaded = false

    private var baseURL: URL {
        AppEnvironment.apiURL.appendingPathComponent("notifications")
    }

    private init() {}

    func refreshCount() async {
        struct Response: Decodable { let count: Int }
        if let response: Response = try? await APIClient.shared.request(baseURL.appendingPathComponent("unread-count")) {
            unreadCount = response.count
        }
    }

    func load() async throws {
        notifications = try await APIClient.shared.request(baseURL)
        hasLoaded = true
        unreadCount = notifications.filter { !$0.isRead }.count
    }

    func markRead(_ notification: AppNotification) async {
        guard !notification.isRead,
              let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index].readAt = .now
        unreadCount = max(0, unreadCount - 1)
        try? await APIClient.shared.requestData(
            baseURL.appendingPathComponent(notification.id.uuidString).appendingPathComponent("read"),
            method: .post
        )
    }

    func markAllRead() async throws {
        try await APIClient.shared.requestData(baseURL.appendingPathComponent("read-all"), method: .post)
        let now = Date.now
        for index in notifications.indices where notifications[index].readAt == nil {
            notifications[index].readAt = now
        }
        unreadCount = 0
    }

    func clearRead() async throws {
        try await APIClient.shared.requestData(baseURL.appendingPathComponent("read"), method: .delete)
        notifications.removeAll(where: \.isRead)
    }

    /// After logout.
    func reset() {
        notifications = []
        unreadCount = 0
        hasLoaded = false
    }
}

/// Bell with the number of unread notifications; opens the list.
struct NotificationBellButton: View {
    @ObservedObject private var inbox = NotificationInbox.shared
    @State private var showsNotifications = false

    var body: some View {
        Button {
            showsNotifications = true
        } label: {
            Image(systemName: inbox.unreadCount > 0 ? "bell.badge" : "bell")
                .foregroundStyle(Color.apexMainColor)
                .overlay(alignment: .topTrailing) {
                    if inbox.unreadCount > 0 {
                        Text(verbatim: inbox.unreadCount > 99 ? "99+" : "\(inbox.unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 10, y: -8)
                    }
                }
        }
        .accessibilityLabel(Text("notifications"))
        .accessibilityValue(Text(verbatim: "\(inbox.unreadCount)"))
        .task {
            await inbox.refreshCount()
        }
        .sheet(isPresented: $showsNotifications) {
            NotificationsView()
        }
    }
}

/// Notifications newest first; tapping one opens what it is about.
struct NotificationsView: View {
    @ObservedObject private var inbox = NotificationInbox.shared
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                if inbox.notifications.isEmpty && inbox.hasLoaded {
                    Text("no_notifications")
                        .foregroundStyle(.secondary)
                }
                ForEach(inbox.notifications) { notification in
                    Button {
                        Task { await open(notification) }
                    } label: {
                        row(notification)
                    }
                }
            }
            .overlay {
                if isLoading && !inbox.hasLoaded {
                    ProgressView()
                }
            }
            .refreshable {
                await Task { await load() }.value
            }
            .task {
                await load()
            }
            .navigationTitle("notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.apexMainColor)
                    }
                    .accessibilityLabel(Text("close"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await markAllRead() }
                        } label: {
                            Label("mark_all_read", systemImage: "checkmark.circle")
                        }
                        .disabled(inbox.unreadCount == 0)
                        Button(role: .destructive) {
                            Task { await clearRead() }
                        } label: {
                            Label("clear_read_notifications", systemImage: "trash")
                        }
                        .disabled(!inbox.notifications.contains(where: \.isRead))
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.apexMainColor)
                    }
                    .accessibilityLabel(Text("notification_options"))
                }
            }
        }
    }

    private func row(_ notification: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: notification.systemImage)
                .font(.subheadline)
                .foregroundStyle(Color.apexMainColor)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.apexMainColor.opacity(0.12)))
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: notification.title)
                    .font(.subheadline.weight(notification.isRead ? .regular : .semibold))
                    .foregroundStyle(Color.primary)
                Text(verbatim: notification.body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Text(notification.createdAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if !notification.isRead {
                Circle()
                    .fill(Color.apexMainColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                    .accessibilityLabel(Text("unread"))
            }
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await inbox.load()
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    // Marks it read and opens its screen like the push would.
    @MainActor
    private func open(_ notification: AppNotification) async {
        await inbox.markRead(notification)
        dismiss()
        NotificationRouter.shared.handle(
            notificationType: notification.type,
            conversationId: notification.data["conversationId"],
            trainingId: notification.data["trainingId"]
        )
    }

    @MainActor
    private func markAllRead() async {
        do {
            try await inbox.markAllRead()
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func clearRead() async {
        do {
            try await inbox.clearRead()
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}
