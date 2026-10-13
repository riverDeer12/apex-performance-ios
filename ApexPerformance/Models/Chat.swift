//
//  Chat.swift
//  ApexPerformance
//

import Foundation

/// Coach or client in a chat (docs/CHAT_API.md in the backend).
struct ChatParticipant: Decodable, Hashable {
    // Coach id or client id.
    let id: UUID
    let userId: UUID
    let fullName: String
}

struct ChatMessage: Identifiable, Decodable, Hashable {
    let id: UUID
    let conversationId: UUID
    let senderUserId: UUID
    // Nil when the message can't be decrypted.
    let content: String?
    let createdAt: Date
    // When the other participant read it.
    var readAt: Date?
}

struct ChatConversation: Identifiable, Decodable, Hashable {
    let id: UUID
    let coach: ChatParticipant
    let client: ChatParticipant
    var isEnabled: Bool
    var lastMessageAt: Date?
    var lastMessage: ChatMessage?
    // Messages of the other participant the logged user hasn't read.
    var unreadCount: Int

    /// The other side: the client for a coach, the coach for a client.
    func otherParticipant(for userId: UUID?) -> ChatParticipant {
        coach.userId == userId ? client : coach
    }
}

/// Someone the logged user can chat with: a client for a coach,
/// a coach for a client.
struct ChatContact: Identifiable, Decodable, Hashable {
    // Client id for a coach, coach id for a client.
    let id: UUID
    let userId: UUID
    let fullName: String
    // Nil when no chat was started yet.
    let conversationId: UUID?
    // False when the coach turned the chat off (read only).
    let isEnabled: Bool
}

/// "MessagesRead" hub event.
struct ChatMessagesRead: Decodable {
    let conversationId: UUID
    let readerUserId: UUID
    let readAt: Date
}

enum ChatAPI {
    private static var baseURL: URL {
        AppEnvironment.apiURL.appendingPathComponent("chat")
    }

    private static func conversationURL(_ id: UUID) -> URL {
        baseURL.appendingPathComponent("conversations").appendingPathComponent(id.uuidString)
    }

    /// Conversations of the logged user, newest activity first.
    @MainActor
    static func conversations() async throws -> [ChatConversation] {
        try await APIClient.shared.request(baseURL.appendingPathComponent("conversations"))
    }

    /// People the logged user can start a chat with, by name.
    @MainActor
    static func contacts() async throws -> [ChatContact] {
        try await APIClient.shared.request(baseURL.appendingPathComponent("contacts"))
    }

    /// Client only: opens the chat with one of their coaches, creating it when needed.
    /// A chat the coach turned off comes back read only.
    @MainActor
    static func start(coachId: UUID) async throws -> ChatConversation {
        struct Request: Encodable { let coachId: UUID }
        return try await APIClient.shared.request(
            baseURL.appendingPathComponent("conversations").appendingPathComponent("start"),
            method: .post,
            body: JSONEncoder().encode(Request(coachId: coachId))
        )
    }

    /// Coach only: creates the conversation with the client if needed and turns it on or off.
    @MainActor
    static func setConversation(clientId: UUID, isEnabled: Bool) async throws -> ChatConversation {
        struct Request: Encodable {
            let clientId: UUID
            let isEnabled: Bool
        }
        return try await APIClient.shared.request(
            baseURL.appendingPathComponent("conversations"),
            method: .post,
            body: JSONEncoder().encode(Request(clientId: clientId, isEnabled: isEnabled))
        )
    }

    /// Newest messages, or the ones before the given date; oldest first.
    @MainActor
    static func messages(conversationId: UUID, before: Date? = nil, take: Int = 50) async throws -> [ChatMessage] {
        var components = URLComponents(
            url: conversationURL(conversationId).appendingPathComponent("messages"),
            resolvingAgainstBaseURL: false
        )
        var query = [URLQueryItem(name: "take", value: String(take))]
        if let before {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            query.append(URLQueryItem(name: "before", value: formatter.string(from: before)))
        }
        components?.queryItems = query
        guard let url = components?.url else { return [] }
        return try await APIClient.shared.request(url)
    }

    @MainActor
    static func send(_ content: String, conversationId: UUID) async throws -> ChatMessage {
        struct Request: Encodable { let content: String }
        return try await APIClient.shared.request(
            conversationURL(conversationId).appendingPathComponent("messages"),
            method: .post,
            body: JSONEncoder().encode(Request(content: content))
        )
    }

    /// Marks the other participant's messages as read.
    @MainActor
    static func markRead(conversationId: UUID) async throws {
        try await APIClient.shared.requestData(
            conversationURL(conversationId).appendingPathComponent("read"),
            method: .post
        )
    }

    @MainActor
    static func unreadCount() async throws -> Int {
        struct Response: Decodable { let count: Int }
        let response: Response = try await APIClient.shared.request(baseURL.appendingPathComponent("unread-count"))
        return response.count
    }
}
