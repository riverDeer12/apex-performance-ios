//
//  DemoAPITests.swift
//  ApexPerformanceTests
//

// DemoAPI only exists in Debug builds.
#if DEBUG
import XCTest
import UIKit
@testable import ApexPerformance

/// Demo data for the App Store screenshots must decode into the app's
/// models, or the screens would show errors instead of the demo.
final class DemoAPITests: XCTestCase {

    // APIClient.decoder is main actor isolated.
    @MainActor
    func testFixturesDecodeIntoAppModels() {
        for check in DemoAPI.decodingChecks {
            let name = "\(check.method) \(check.path) as \(check.role)"
            let reply = DemoAPI.fixture(check.method, check.path, role: check.role, body: check.body)
            XCTAssertEqual(reply.status, 200, name)
            do {
                try check.decode(reply.data)
            } catch {
                XCTFail("\(name): \(error)")
            }
        }
    }

    func testLoginPicksCoachOrClientByUsername() throws {
        for (username, role, userId) in [("demo.coach", "Coach", DemoAPI.coachUserId),
                                         ("demo.client", "Client", DemoAPI.anaUserId)] {
            let body = try JSONEncoder().encode(LoginRequest(username: username, password: "demo"))
            let reply = DemoAPI.fixture("POST", "authentication/login", role: .client, body: body)
            XCTAssertEqual(reply.status, 200)

            // Decoded like AuthManager does.
            let token = try JSONDecoder().decode(LoginResponse.self, from: reply.data).token
            XCTAssertTrue(JWTDecoder.isTokenValid(token))
            XCTAssertEqual(JWTDecoder.getUserRole(token: token), role)
            XCTAssertEqual(JWTDecoder.getUserId(token: token), userId)
        }
    }

    func testCoachHasPermissionsForAllTabs() {
        let token = DemoAPI.token(for: .coach)
        let permissions = JWTDecoder.getUserPermissions(token: token)
        XCTAssertTrue(permissions.contains(Permissions.canGetClients))
        XCTAssertTrue(permissions.contains(Permissions.canGetAppointments))
        XCTAssertTrue(permissions.contains(Permissions.canCreateAppointment))
        XCTAssertTrue(permissions.contains(Permissions.canGetAppointmentRequests))

        let clientPermissions = JWTDecoder.getUserPermissions(token: DemoAPI.token(for: .client))
        XCTAssertTrue(clientPermissions.contains(Permissions.canGetAppointments))
        XCTAssertTrue(clientPermissions.contains(Permissions.canCreateAppointment))
    }

    @MainActor
    func testChatParticipantsMatchTokens() throws {
        let reply = DemoAPI.fixture("GET", "chat/conversations", role: .coach)
        let conversations = try APIClient.decoder.decode([ChatConversation].self, from: reply.data)

        // Ana's conversation comes first and her messages are told apart by the token's sub.
        let first = try XCTUnwrap(conversations.first)
        XCTAssertEqual(first.id, DemoAPI.anaConversationId)
        XCTAssertEqual(first.coach.userId, JWTDecoder.getUserId(token: DemoAPI.token(for: .coach)))
        XCTAssertEqual(first.client.userId, JWTDecoder.getUserId(token: DemoAPI.token(for: .client)))

        let messagesReply = DemoAPI.fixture("GET", "chat/conversations/\(first.id.uuidString)/messages?take=50", role: .client)
        let messages = try APIClient.decoder.decode([ChatMessage].self, from: messagesReply.data)
        XCTAssertTrue(messages.contains { $0.isImage })
        XCTAssertTrue(messages.contains { $0.isWorkout && $0.workout != nil })
        XCTAssertEqual(messages.map(\.createdAt), messages.map(\.createdAt).sorted())
    }

    func testChatPictureIsAnImage() throws {
        let path = "chat/conversations/\(DemoAPI.anaConversationId.uuidString)/attachments/\(UUID().uuidString)"
        let reply = DemoAPI.fixture("GET", path, role: .client)
        XCTAssertEqual(reply.status, 200)
        XCTAssertEqual(reply.contentType, "image/jpeg")
        XCTAssertNotNil(UIImage(data: reply.data))
    }

    @MainActor
    func testClientPackageAndHome() throws {
        let client = try APIClient.decoder.decode(
            UserProfile.self, from: DemoAPI.fixture("GET", "clients/current-client", role: .client).data
        )
        let appointments = try APIClient.decoder.decode(
            AppointmentsStatus.self, from: DemoAPI.fixture("GET", "appointments", role: .client).data
        )
        let package = PackageSummary(client: client, approvedAppointments: appointments.approvedAppointments)
        XCTAssertEqual(package.reserved, 2)
        XCTAssertEqual(package.available, 5)
        XCTAssertLessThanOrEqual(package.total, 12)

        // No goal sheet over home: the goal has no update date.
        let goal = try APIClient.decoder.decode(
            ClientGoal.self, from: DemoAPI.fixture("GET", "client-goals/my", role: .client).data
        )
        XCTAssertFalse(goal.isEmpty)
        XCTAssertNil(goal.updatedAt)

        // Clients only get completed trainings.
        let trainings = try APIClient.decoder.decode(
            [Training].self, from: DemoAPI.fixture("GET", "trainings", role: .client).data
        )
        XCTAssertEqual(trainings.count, 6)
        XCTAssertTrue(trainings.allSatisfy(\.isCompleted))
    }

    func testUnknownPathIsNotFound() {
        XCTAssertEqual(DemoAPI.fixture("GET", "no-such-endpoint", role: .client).status, 404)
        XCTAssertEqual(DemoAPI.fixture("GET", "profile/picture", role: .client).status, 404)
        XCTAssertEqual(DemoAPI.fixture("GET", "hubs/chat", role: .client).status, 404)
    }

    func testOnlyTheAPIHostIsAnswered() throws {
        let apiRequest = URLRequest(url: AppEnvironment.apiURL.appendingPathComponent("profile"))
        XCTAssertTrue(DemoURLProtocol.canInit(with: apiRequest))

        let otherRequest = URLRequest(url: try XCTUnwrap(URL(string: "https://itunes.apple.com/lookup")))
        XCTAssertFalse(DemoURLProtocol.canInit(with: otherRequest))
    }
}
#endif
