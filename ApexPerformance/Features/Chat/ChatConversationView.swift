//
//  ChatConversationView.swift
//  ApexPerformance
//

import SwiftUI

/// Messages of one conversation with the field to write. New messages
/// come live from the chat hub; scrolling up loads older ones. The coach
/// can turn the chat off, then nobody can write but messages are kept.
struct ChatConversationView: View {
    let conversationId: UUID

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var toastManager: ToastManager
    @ObservedObject private var store = ChatStore.shared

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isLoading = false
    @State private var isLoadingOlder = false
    @State private var hasOlder = false
    @State private var isSending = false
    @State private var isUpdating = false
    @State private var showReport = false
    @State private var reportReason = ""
    // Message to keep in view: the newest after loading or sending,
    // the previously first one after loading older messages.
    @State private var scrollTarget: UUID?

    private static let pageSize = 50

    private var conversation: ChatConversation? {
        store.conversations.first { $0.id == conversationId }
    }

    private var isCoach: Bool {
        authManager.hasRole(role: "Coach")
    }

    private var canSend: Bool {
        (conversation?.isEnabled ?? false)
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSending
    }

    // Own message the read or sent status is shown under.
    private var lastOwnMessageId: UUID? {
        messages.last { $0.senderUserId == store.userId }?.id
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        if hasOlder {
                            Button {
                                Task { await loadOlder() }
                            } label: {
                                if isLoadingOlder {
                                    ProgressView()
                                } else {
                                    Text("chat_load_older")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Color.apexMainColor)
                                }
                            }
                            .buttonStyle(.borderless)
                            .padding(.vertical, 8)
                        }

                        if messages.isEmpty && !isLoading {
                            Text("chat_start_conversation")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 40)
                        }

                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            if index == 0 || !Calendar.current.isDate(messages[index - 1].createdAt,
                                                                      inSameDayAs: message.createdAt) {
                                Text(verbatim: DateFormatter.dateWithDots.string(from: message.createdAt))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 6)
                            }
                            bubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: scrollTarget) {
                    guard let target = scrollTarget else { return }
                    withAnimation { proxy.scrollTo(target, anchor: target == messages.last?.id ? .bottom : .top) }
                    scrollTarget = nil
                }
            }
            .overlay {
                if isLoading && messages.isEmpty {
                    ProgressView()
                }
            }

            inputBar
        }
        .background(Color.apexBackground)
        .navigationTitle(Text(verbatim: conversation?.otherParticipant(for: store.userId).fullName ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let conversation {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if isCoach {
                            Toggle(isOn: Binding(
                                get: { conversation.isEnabled },
                                set: { isOn in Task { await setEnabled(isOn) } }
                            )) {
                                Label("chat_enabled", systemImage: "bubble.left.and.bubble.right")
                            }
                        }
                        Button(role: .destructive) {
                            reportReason = ""
                            showReport = true
                        } label: {
                            Label("chat_report", systemImage: "exclamationmark.bubble")
                        }
                    } label: {
                        if isUpdating {
                            ProgressView()
                        } else {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(Color.apexMainColor)
                        }
                    }
                    .accessibilityLabel(Text("chat_options"))
                }
            }
        }
        .alert("chat_report", isPresented: $showReport) {
            TextField("chat_report_reason", text: $reportReason)
            Button("chat_report_send", role: .destructive) {
                Task { await report() }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("chat_report_info")
        }
        .task {
            await loadNewest()
        }
        .onAppear { attach() }
        .onDisappear { detach() }
    }

    // MARK: - Views

    private func bubble(_ message: ChatMessage) -> some View {
        let isOwn = message.senderUserId == store.userId
        return VStack(alignment: isOwn ? .trailing : .leading, spacing: 2) {
            Group {
                if let content = message.content {
                    Text(verbatim: content)
                } else {
                    Text("chat_unreadable").italic()
                }
            }
            .font(.subheadline)
            .foregroundStyle(isOwn ? Color.apexOnAccent : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isOwn ? Color.apexAccent : Color.apexCard)
            )
            .textSelection(.enabled)

            HStack(spacing: 4) {
                Text(verbatim: message.createdAt.formatted(date: .omitted, time: .shortened))
                if isOwn && message.id == lastOwnMessageId {
                    Text(verbatim: "·")
                    Text(message.readAt == nil ? LocalizedStringKey("chat_sent") : LocalizedStringKey("chat_read"))
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: isOwn ? .trailing : .leading)
        .padding(isOwn ? .leading : .trailing, 48)
    }

    @ViewBuilder
    private var inputBar: some View {
        if conversation?.isEnabled == false {
            Label("chat_disabled_info", systemImage: "pause.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color.apexCard)
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("chat_placeholder", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .apexCardBackground(cornerRadius: 18)

                Button {
                    Task { await send() }
                } label: {
                    ZStack {
                        if isSending {
                            ProgressView().tint(Color.apexOnAccent)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundStyle(Color.apexOnAccent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.apexAccent))
                    .opacity(canSend ? 1 : 0.4)
                }
                .disabled(!canSend)
                .accessibilityLabel(Text("chat_send"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.apexBackground)
        }
    }

    // MARK: - Live events

    private func attach() {
        store.openConversationId = conversationId
        store.onMessage = { message in
            guard message.conversationId == conversationId else { return }
            append(message)
            if message.senderUserId != store.userId {
                Task { await markRead() }
            }
        }
        store.onMessagesRead = { event in
            guard event.conversationId == conversationId, event.readerUserId != store.userId else { return }
            for index in messages.indices
            where messages[index].senderUserId == store.userId
                && messages[index].readAt == nil
                && messages[index].createdAt <= event.readAt {
                messages[index].readAt = event.readAt
            }
        }
        store.onReconnected = {
            Task { await loadNewest() }
        }
    }

    private func detach() {
        // Another conversation may already be open.
        guard store.openConversationId == conversationId else { return }
        store.openConversationId = nil
        store.onMessage = nil
        store.onMessagesRead = nil
        store.onReconnected = nil
    }

    private func append(_ message: ChatMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
        scrollTarget = message.id
    }

    // MARK: - API

    @MainActor
    private func loadNewest() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let newest = try await ChatAPI.messages(conversationId: conversationId, take: Self.pageSize)
            // Keep older pages that were already loaded.
            let older = messages.filter { message in
                guard let first = newest.first else { return false }
                return message.createdAt < first.createdAt
            }
            messages = older + newest
            if older.isEmpty { hasOlder = newest.count == Self.pageSize }
            scrollTarget = messages.last?.id
            await markRead()
        } catch let error where error.isCancellation {
            return
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func loadOlder() async {
        guard let first = messages.first, !isLoadingOlder else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }

        do {
            let older = try await ChatAPI.messages(conversationId: conversationId, before: first.createdAt,
                                                   take: Self.pageSize)
            messages = older.filter { message in !messages.contains { $0.id == message.id } } + messages
            hasOlder = older.count == Self.pageSize
            scrollTarget = first.id
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func send() async {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        isSending = true
        defer { isSending = false }

        do {
            let message = try await ChatAPI.send(content, conversationId: conversationId)
            draft = ""
            append(message)
            store.didSend(message)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
            // The coach may have just turned the chat off: show it read only.
            await store.refresh()
        }
    }

    @MainActor
    private func markRead() async {
        guard (conversation?.unreadCount ?? 0) > 0 || messages.contains(where: {
            $0.senderUserId != store.userId && $0.readAt == nil
        }) else { return }
        store.markReadLocally(conversationId: conversationId)
        let now = Date()
        for index in messages.indices where messages[index].senderUserId != store.userId && messages[index].readAt == nil {
            messages[index].readAt = now
        }
        try? await ChatAPI.markRead(conversationId: conversationId)
    }

    @MainActor
    private func report() async {
        let reason = reportReason.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await ChatAPI.report(conversationId: conversationId, reason: reason.isEmpty ? nil : reason)
            toastManager.show("chat_report_sent", type: .success)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }

    @MainActor
    private func setEnabled(_ isEnabled: Bool) async {
        guard let conversation else { return }
        isUpdating = true
        defer { isUpdating = false }

        do {
            let updated = try await ChatAPI.setConversation(clientId: conversation.client.id, isEnabled: isEnabled)
            store.upsert(updated)
            toastManager.show(isEnabled ? "chat_enabled_detail" : "chat_disabled_detail", type: .success)
        } catch {
            toastManager.show(LocalizedStringKey(mapError(error)), type: .error)
        }
    }
}
