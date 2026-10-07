//
//  ClientGoal.swift
//  ApexPerformance
//

import Foundation

/// Client's goal and plan, written by the coach (api/client-goals).
/// All fields are empty while the coach hasn't written it yet.
struct ClientGoal: Codable, Equatable {
    var goal: String?
    var currentBlock: String?
    var focus: String?
    var nextAssessment: String?
    var nextAssessmentDate: Date?
    var updatedAt: Date?

    var isEmpty: Bool {
        [goal, currentBlock, focus, nextAssessment].allSatisfy { ($0 ?? "").isEmpty } && nextAssessmentDate == nil
    }

    private enum CodingKeys: String, CodingKey {
        case goal, currentBlock, focus, nextAssessment, nextAssessmentDate, updatedAt
    }

    init(goal: String? = nil, currentBlock: String? = nil, focus: String? = nil,
         nextAssessment: String? = nil, nextAssessmentDate: Date? = nil, updatedAt: Date? = nil) {
        self.goal = goal
        self.currentBlock = currentBlock
        self.focus = focus
        self.nextAssessment = nextAssessment
        self.nextAssessmentDate = nextAssessmentDate
        self.updatedAt = updatedAt
    }

    // Only the editable fields are sent, dates as ISO 8601 for the API.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(goal, forKey: .goal)
        try container.encode(currentBlock, forKey: .currentBlock)
        try container.encode(focus, forKey: .focus)
        try container.encode(nextAssessment, forKey: .nextAssessment)
        try container.encode(nextAssessmentDate.map { ISO8601DateFormatter().string(from: $0) },
                             forKey: .nextAssessmentDate)
    }
}

extension ClientGoal {
    /// Goal and plan of the logged client.
    @MainActor
    static func loadMine() async throws -> ClientGoal {
        let url = AppEnvironment.apiURL.appendingPathComponent("client-goals/my")
        return try await APIClient.shared.request(url)
    }

    /// Goal and plan of a client (staff).
    @MainActor
    static func load(clientId: UUID) async throws -> ClientGoal {
        let url = AppEnvironment.apiURL
            .appendingPathComponent("client-goals")
            .appendingPathComponent(clientId.uuidString)
        return try await APIClient.shared.request(url)
    }

    /// Saves the goal and plan of a client (staff).
    @MainActor
    func save(clientId: UUID) async throws -> ClientGoal {
        let url = AppEnvironment.apiURL
            .appendingPathComponent("client-goals")
            .appendingPathComponent(clientId.uuidString)
        return try await APIClient.shared.request(url, method: .put, body: JSONEncoder().encode(self))
    }
}

/// Coach's review of a client's month (api/monthly-reviews).
struct MonthlyReview: Identifiable, Decodable, Hashable {
    let id: UUID
    let clientId: UUID
    let year: Int
    let month: Int
    let content: String
    let updatedAt: Date

    /// First day of the reviewed month, for formatting.
    var monthDate: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
    }
}

extension MonthlyReview {
    /// Reviews newest month first. Clients get their own, staff pass the client.
    @MainActor
    static func load(clientId: UUID? = nil) async throws -> [MonthlyReview] {
        var components = URLComponents(
            url: AppEnvironment.apiURL.appendingPathComponent("monthly-reviews"),
            resolvingAgainstBaseURL: false
        )
        if let clientId {
            components?.queryItems = [URLQueryItem(name: "clientId", value: clientId.uuidString)]
        }
        guard let url = components?.url else { throw URLError(.badURL) }
        return try await APIClient.shared.request(url)
    }

    /// Writes or updates the review of a client's month (staff).
    @MainActor
    static func save(clientId: UUID, year: Int, month: Int, content: String) async throws -> MonthlyReview {
        struct Request: Encodable {
            let client: UUID
            let year: Int
            let month: Int
            let content: String
        }

        let url = AppEnvironment.apiURL.appendingPathComponent("monthly-reviews")
        let request = Request(client: clientId, year: year, month: month, content: content)
        return try await APIClient.shared.request(url, method: .put, body: JSONEncoder().encode(request))
    }

    @MainActor
    static func delete(id: UUID) async throws {
        let url = AppEnvironment.apiURL
            .appendingPathComponent("monthly-reviews")
            .appendingPathComponent(id.uuidString)
        try await APIClient.shared.requestData(url, method: .delete)
    }
}
