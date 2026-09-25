//
//  AuthManagerTests.swift
//  ApexPerformanceTests
//

import XCTest
@testable import ApexPerformance

final class AuthManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        KeychainService.shared.deleteToken()
    }

    override func tearDown() {
        KeychainService.shared.deleteToken()
        super.tearDown()
    }

    private func makeToken(
        name: String = "milan",
        permissions: [String] = ["CanGetAppointments"],
        role: String = "Coach",
        exp: Int = Int(Date().timeIntervalSince1970) + 3600
    ) -> String {
        let header = try! JSONSerialization.data(withJSONObject: ["alg": "HS256", "typ": "JWT"])
        let payload: [String: Any] = [
            "name": name,
            "sub": "1",
            "permissions": permissions,
            "role": role,
            "exp": exp,
            "iat": Int(Date().timeIntervalSince1970),
            "nbf": Int(Date().timeIntervalSince1970)
        ]
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        return "\(header.base64EncodedString()).\(payloadData.base64EncodedString()).signature"
    }

    func testInit_withNoStoredToken_isNotAuthenticated() {
        let authManager = AuthManager()
        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.token)
    }

    func testInit_withValidStoredToken_isAuthenticated() {
        KeychainService.shared.saveToken(makeToken())

        let authManager = AuthManager()

        XCTAssertTrue(authManager.isAuthenticated)
    }

    func testInit_withExpiredStoredToken_logsOutAndClearsToken() {
        KeychainService.shared.saveToken(makeToken(exp: Int(Date().timeIntervalSince1970) - 3600))

        let authManager = AuthManager()

        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.token)
    }

    func testLogin_persistsTokenAndSetsAuthenticated() {
        let authManager = AuthManager()
        let token = makeToken(name: "sarah", role: "Client")

        authManager.login(token: token)

        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertEqual(authManager.token, token)
        XCTAssertEqual(authManager.username, "sarah")
        XCTAssertEqual(authManager.userRole, "Client")
    }

    func testLogout_clearsTokenAndAuthenticatedState() {
        let authManager = AuthManager()
        authManager.login(token: makeToken())

        authManager.logout()

        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.token)
    }

    func testHasPermission_reflectsTokenPermissions() {
        let authManager = AuthManager()
        authManager.login(token: makeToken(permissions: ["CanGetClients", "CanGetWorkouts"]))

        XCTAssertTrue(authManager.hasPermission(permission: "CanGetClients"))
        XCTAssertFalse(authManager.hasPermission(permission: "CanGetAppointmentRequests"))
    }

    func testHasRole_reflectsTokenRole() {
        let authManager = AuthManager()
        authManager.login(token: makeToken(role: "Coach"))

        XCTAssertTrue(authManager.hasRole(role: "Coach"))
        XCTAssertFalse(authManager.hasRole(role: "Client"))
    }

    func testHasPermission_withNoStoredToken_isFalse() {
        let authManager = AuthManager()
        XCTAssertFalse(authManager.hasPermission(permission: "CanGetClients"))
    }
}
