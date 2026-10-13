//
//  ChatHub.swift
//  ApexPerformance
//

import Foundation

/// Listens to the chat SignalR hub (api/hubs/chat) over a WebSocket with the
/// SignalR JSON protocol. The hub has no methods to call, the app only gets
/// "MessageReceived", "MessagesRead" and "ConversationUpdated" events, so a
/// small client is enough and the app needs no SignalR package.
@MainActor
final class ChatHub {
    enum Event {
        case messageReceived(ChatMessage)
        case messagesRead(ChatMessagesRead)
        case conversationUpdated
        // Connected again after a drop; events missed meanwhile aren't replayed.
        case reconnected
    }

    var onEvent: ((Event) -> Void)?

    private static let recordSeparator = "\u{1e}"
    // The server drops a client that sends nothing for 30 seconds.
    private static let pingInterval: Duration = .seconds(15)
    private static let retryDelays: [Duration] = [.seconds(1), .seconds(3), .seconds(10), .seconds(30)]

    private var task: URLSessionWebSocketTask?
    private var loop: Task<Void, Never>?
    private var hasConnectedBefore = false

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            var attempt = 0
            while !Task.isCancelled {
                guard let self else { return }
                let connected = await self.runConnection()
                if Task.isCancelled { return }
                attempt = connected ? 0 : attempt + 1
                let delay = Self.retryDelays[min(attempt, Self.retryDelays.count - 1)]
                try? await Task.sleep(for: delay)
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        hasConnectedBefore = false
    }

    /// One connection until it closes. True when the handshake succeeded.
    private func runConnection() async -> Bool {
        guard let token = KeychainService.shared.getToken(), let url = Self.hubURL(token: token) else {
            return false
        }

        let task = URLSession.shared.webSocketTask(with: url)
        self.task = task
        task.resume()

        var handshakeDone = false
        let pinger = Task { [weak task] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pingInterval)
                try? await task?.send(.string("{\"type\":6}" + Self.recordSeparator))
            }
        }
        defer {
            pinger.cancel()
            task.cancel(with: .goingAway, reason: nil)
        }

        do {
            try await task.send(.string("{\"protocol\":\"json\",\"version\":1}" + Self.recordSeparator))

            while !Task.isCancelled {
                let text: String
                switch try await task.receive() {
                case .string(let string): text = string
                case .data(let data): text = String(decoding: data, as: UTF8.self)
                @unknown default: continue
                }

                for record in text.components(separatedBy: Self.recordSeparator) where !record.isEmpty {
                    guard let data = record.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                    if !handshakeDone {
                        // "{}" or {"error": "..."}
                        guard json["error"] == nil else { return false }
                        handshakeDone = true
                        if hasConnectedBefore { onEvent?(.reconnected) }
                        hasConnectedBefore = true
                        continue
                    }

                    switch json["type"] as? Int {
                    case 1: handleInvocation(json)
                    case 7: return true // Close, connect again.
                    default: break // Pings and others.
                    }
                }
            }
        } catch {
            #if DEBUG
            print("⚠️ Chat hub disconnected: \(error.localizedDescription)")
            #endif
        }
        return handshakeDone
    }

    private func handleInvocation(_ json: [String: Any]) {
        guard let target = json["target"] as? String,
              let argument = (json["arguments"] as? [Any])?.first else { return }

        switch target {
        case "MessageReceived":
            if let message: ChatMessage = Self.decode(argument) {
                onEvent?(.messageReceived(message))
            }
        case "MessagesRead":
            if let event: ChatMessagesRead = Self.decode(argument) {
                onEvent?(.messagesRead(event))
            }
        case "ConversationUpdated":
            onEvent?(.conversationUpdated)
        default:
            break
        }
    }

    private static func decode<T: Decodable>(_ argument: Any) -> T? {
        guard JSONSerialization.isValidJSONObject(argument),
              let data = try? JSONSerialization.data(withJSONObject: argument) else { return nil }
        return try? APIClient.decoder.decode(T.self, from: data)
    }

    // wss://.../api/hubs/chat?access_token=..., WebSockets without negotiation.
    private static func hubURL(token: String) -> URL? {
        let url = AppEnvironment.apiURL.appendingPathComponent("hubs").appendingPathComponent("chat")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let isPlainHTTP = components?.scheme == "http"
        components?.scheme = isPlainHTTP ? "ws" : "wss"
        components?.queryItems = [URLQueryItem(name: "access_token", value: token)]
        return components?.url
    }
}

/// Chat state shared by the tab badge, the conversation list and the
/// open conversation. Started after login for coaches and clients.
@MainActor
final class ChatStore: ObservableObject {
    static let shared = ChatStore()

    @Published private(set) var conversations: [ChatConversation] = []
    @Published private(set) var unreadCount = 0
    @Published private(set) var hasLoaded = false
    // Conversation on screen: its pushes aren't shown and its messages are read.
    @Published var openConversationId: UUID?

    /// Hub events for the open conversation screen.
    var onMessage: ((ChatMessage) -> Void)?
    var onMessagesRead: ((ChatMessagesRead) -> Void)?
    var onReconnected: (() -> Void)?

    private let hub = ChatHub()
    private var isStarted = false

    private init() {
        hub.onEvent = { [weak self] event in self?.handle(event) }
    }

    var userId: UUID? {
        KeychainService.shared.getToken().flatMap { JWTDecoder.getUserId(token: $0) }
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        hub.start()
        Task { await refresh() }
    }

    func stop() {
        isStarted = false
        hub.stop()
        conversations = []
        unreadCount = 0
        hasLoaded = false
        openConversationId = nil
    }

    func refresh() async {
        do {
            conversations = try await ChatAPI.conversations()
            hasLoaded = true
            recountUnread()
        } catch {
            // The badge waits for the next refresh.
        }
    }

    /// Puts a conversation from the API (e.g. after turning it on) into the list.
    func upsert(_ conversation: ChatConversation) {
        conversations.removeAll { $0.id == conversation.id }
        conversations.append(conversation)
        sortConversations()
        recountUnread()
    }

    /// Own message sent from this device.
    func didSend(_ message: ChatMessage) {
        apply(message)
    }

    /// The open conversation was read on this device.
    func markReadLocally(conversationId: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        conversations[index].unreadCount = 0
        recountUnread()
    }

    private func handle(_ event: ChatHub.Event) {
        switch event {
        case .messageReceived(let message):
            if !conversations.contains(where: { $0.id == message.conversationId }) {
                Task { await refresh() }
            }
            apply(message)
            onMessage?(message)

        case .messagesRead(let event):
            // Another device of this user read them.
            if event.readerUserId == userId {
                markReadLocally(conversationId: event.conversationId)
            }
            onMessagesRead?(event)

        case .conversationUpdated:
            Task { await refresh() }

        case .reconnected:
            Task { await refresh() }
            onReconnected?()
        }
    }

    // Last message and unread count of the message's conversation.
    private func apply(_ message: ChatMessage) {
        guard let index = conversations.firstIndex(where: { $0.id == message.conversationId }) else { return }
        // The same message can come from the POST and the hub.
        if conversations[index].lastMessage?.id == message.id { return }

        conversations[index].lastMessage = message
        conversations[index].lastMessageAt = message.createdAt
        if message.senderUserId != userId && openConversationId != message.conversationId {
            conversations[index].unreadCount += 1
        }
        sortConversations()
        recountUnread()
    }

    private func sortConversations() {
        conversations.sort { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
    }

    private func recountUnread() {
        unreadCount = conversations.reduce(0) { $0 + $1.unreadCount }
    }
}
