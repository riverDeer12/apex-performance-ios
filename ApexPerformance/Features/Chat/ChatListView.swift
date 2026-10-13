//
//  ChatListView.swift
//  ApexPerformance
//

import SwiftUI

/// Chat, opened from the floating button: conversations between a coach
/// and their clients, newest activity first. Either side can start a chat;
/// only the coach can turn it off, then it stays read only for both.
struct ChatListView: View {
    // Shown as a sheet over the tabs.
    var showsCloseButton = false

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var toastManager: ToastManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = ChatStore.shared
    @ObservedObject private var notificationRouter = NotificationRouter.shared

    @State private var path: [UUID] = []
    @State private var showContactPicker = false
    @State private var pickedContact: ChatContact?
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

                    Button("chat_new") {
                        pickedContact = nil
                        showContactPicker = true
                    }
                    .buttonStyle(ApexPrimaryButtonStyle(systemImage: "plus"))
                    .disabled(isStarting)
                    .padding(.horizontal, 20)

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
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(Color.apexMainColor)
                        }
                        .accessibilityLabel(Text("close"))
                    }
                }
            }
            .sheet(isPresented: $showContactPicker, onDismiss: {
                if let contact = pickedContact {
                    Task { await startChat(with: contact) }
                }
            }) {
                ChatContactPickerView(title: isCoach ? "chat_choose_client" : "chat_choose_coach") { contact in
                    pickedContact = contact
                    showContactPicker = false
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

    /// Opens the chat with the contact, starting it when there is none yet.
    /// An existing chat opens as it is, also when the coach turned it off.
    @MainActor
    private func startChat(with contact: ChatContact) async {
        if let id = contact.conversationId {
            path = [id]
            return
        }

        isStarting = true
        defer { isStarting = false }

        do {
            let conversation: ChatConversation
            if isCoach {
                conversation = try await ChatAPI.setConversation(clientId: contact.id, isEnabled: true)
            } else {
                conversation = try await ChatAPI.start(coachId: contact.id)
            }
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

/// People the user can chat with (clients for a coach, coaches for a
/// client); tapping one picks them.
struct ChatContactPickerView: View {
    let title: LocalizedStringKey
    let onPick: (ChatContact) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastManager: ToastManager

    @State private var contacts: [ChatContact] = []
    @State private var searchText = ""
    @State private var isLoading = false

    private var filteredContacts: [ChatContact] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return contacts }
        return contacts.filter { $0.fullName.localizedStandardContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if contacts.isEmpty, !isLoading {
                    Text("chat_no_contacts")
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredContacts) { contact in
                    Button {
                        onPick(contact)
                    } label: {
                        HStack(spacing: 12) {
                            ChatAvatar(name: contact.fullName, size: 34)
                            Text(verbatim: contact.fullName)
                                .foregroundStyle(Color.primary)
                            Spacer()
                            if contact.conversationId != nil {
                                Image(systemName: contact.isEnabled ? "bubble.left.and.bubble.right" : "pause.circle")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
            .searchable(text: $searchText, prompt: Text("search"))
            .overlay {
                if isLoading && contacts.isEmpty {
                    ProgressView()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.apexMainColor)
                    }
                    .accessibilityLabel(Text("cancel"))
                }
            }
            .task {
                await load()
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            contacts = try await ChatAPI.contacts()
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}

/// Round chat button floating over the tabs, with the unread count.
struct ChatFloatingButton: View {
    let unreadCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.apexOnAccent)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.apexAccent))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                .overlay(alignment: .topTrailing) {
                    if unreadCount > 0 {
                        Text(verbatim: unreadCount > 99 ? "99+" : "\(unreadCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("tab_chat"))
        .accessibilityValue(unreadCount > 0 ? Text(verbatim: "\(unreadCount)") : Text(verbatim: ""))
    }
}
