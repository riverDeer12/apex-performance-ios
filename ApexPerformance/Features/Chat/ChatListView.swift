//
//  ChatListView.swift
//  ApexPerformance
//

import SwiftUI

/// Chat tab: conversations between a coach and their clients, newest
/// activity first. Coaches start a chat with a client, clients see the
/// chats their coach turned on.
struct ChatListView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var toastManager: ToastManager
    @ObservedObject private var store = ChatStore.shared
    @ObservedObject private var notificationRouter = NotificationRouter.shared

    @State private var path: [UUID] = []
    @State private var showClientPicker = false
    @State private var pickedClient: Client?
    @State private var isStarting = false

    private var isCoach: Bool {
        authManager.hasRole(role: "Coach")
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    ApexScreenHeader(title: "chat_title", subtitle: "chat_encrypted_info")
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    if isCoach {
                        Button("chat_new") {
                            pickedClient = nil
                            showClientPicker = true
                        }
                        .buttonStyle(ApexPrimaryButtonStyle(systemImage: "plus"))
                        .disabled(isStarting)
                        .padding(.horizontal, 20)
                    }

                    CardView {
                        if store.conversations.isEmpty {
                            if store.hasLoaded {
                                Text(isCoach ? LocalizedStringKey("chat_empty_coach") : LocalizedStringKey("chat_empty_client"))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                            } else {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(store.conversations) { conversation in
                                    NavigationLink(value: conversation.id) {
                                        row(conversation)
                                    }
                                    .buttonStyle(.plain)

                                    if conversation.id != store.conversations.last?.id {
                                        Divider().padding(.leading, 60)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
            .background(Color.apexBackground)
            .refreshable {
                await Task { await store.refresh() }.value
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                ChatConversationView(conversationId: id)
            }
            .sheet(isPresented: $showClientPicker, onDismiss: {
                if let client = pickedClient {
                    Task { await startChat(with: client) }
                }
            }) {
                ClientPickerView(title: "chat_choose_client") { client in
                    pickedClient = client
                    showClientPicker = false
                }
            }
            .onAppear { openPendingConversation() }
            .onChange(of: notificationRouter.pendingConversationId) { openPendingConversation() }
        }
    }

    private func row(_ conversation: ChatConversation) -> some View {
        let other = conversation.otherParticipant(for: store.userId)
        return HStack(spacing: 12) {
            ChatAvatar(name: other.fullName)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(verbatim: other.fullName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if !conversation.isEnabled {
                        Image(systemName: "pause.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("chat_disabled"))
                    }
                    Spacer()
                    if let date = conversation.lastMessageAt {
                        Text(verbatim: Self.shortDate(date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    lastMessageText(conversation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text(verbatim: conversation.unreadCount > 99 ? "99+" : "\(conversation.unreadCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.apexOnAccent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.apexAccent))
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func lastMessageText(_ conversation: ChatConversation) -> Text {
        guard let message = conversation.lastMessage else { return Text("chat_no_messages") }
        let content = message.content.map { Text(verbatim: $0) } ?? Text("chat_unreadable")
        return message.senderUserId == store.userId ? Text("chat_you") + Text(verbatim: ": ") + content : content
    }

    // Time today, date otherwise.
    static func shortDate(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : DateFormatter.dateWithDots.string(from: date)
    }

    private func openPendingConversation() {
        guard let id = notificationRouter.pendingConversationId else { return }
        notificationRouter.pendingConversationId = nil
        path = [id]
    }

    @MainActor
    private func startChat(with client: Client) async {
        isStarting = true
        defer { isStarting = false }

        do {
            let conversation = try await ChatAPI.setConversation(clientId: client.id, isEnabled: true)
            store.upsert(conversation)
            path = [conversation.id]
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

/// Round initials of a participant.
struct ChatAvatar: View {
    let name: String
    var size: CGFloat = 44

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    var body: some View {
        Text(verbatim: initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(Color.apexOnAccent)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.apexAccent))
            .accessibilityHidden(true)
    }
}
