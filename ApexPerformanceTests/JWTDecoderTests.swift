//
//  JWTDecoderTests.swift
//  ApexPerformanceTests
//

import XCTest
@testable import ApexPerformance

final class JWTDecoderTests: XCTestCase {

    private func makeToken(
        name: String = "milan",
        sub: String = "1",
        permissions: [String] = ["CanGetAppointments"],
        role: String = "Coach",
        exp: Int = Int(Date().timeIntervalSince1970) + 3600,
        iat: Int = Int(Date().timeIntervalSince1970),
        nbf: Int = Int(Date().timeIntervalSince1970)
    ) -> String {
        let header = try! JSONSerialization.data(withJSONObject: ["alg": "HS256", "typ": "JWT"])
        let payload: [String: Any] = [
            "name": name,
            "sub": sub,
            "permissions": permissions,
            "role": role,
            "exp": exp,
            "iat": iat,
            "nbf": nbf
        ]
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)
        return "\(header.base64EncodedString()).\(payloadData.base64EncodedString()).signature"
    }

    // MARK: - decodePayload

    func testDecodePayload_returnsCorrectFields() throws {
        let token = makeToken(name: "milan", sub: "42", permissions: ["CanGetClients"], role: "Coach", exp: 9999999999)

        let payload = try JWTDecoder.decodePayload(from: token)

        XCTAssertEqual(payload.name, "milan")
        XCTAssertEqual(payload.sub, "42")
        XCTAssertEqual(payload.permissions, ["CanGetClients"])
        XCTAssertEqual(payload.role, "Coach")
        XCTAssertEqual(payload.exp, 9999999999)
    }

    func testDecodePayload_throwsInvalidFormat_whenNotThreeSegments() {
        XCTAssertThrowsError(try JWTDecoder.decodePayload(from: "not.a.valid.jwt.token")) { error in
            XCTAssertEqual(error as? JWTDecoderError, .invalidFormat)
        }
        XCTAssertThrowsError(try JWTDecoder.decodePayload(from: "onlyonesegment")) { error in
            XCTAssertEqual(error as? JWTDecoderError, .invalidFormat)
        }
    }

    func testDecodePayload_throwsInvalidBase64_whenPayloadSegmentIsNotBase64() {
        XCTAssertThrowsError(try JWTDecoder.decodePayload(from: "header.not-valid-base64!!!.signature")) { error in
            XCTAssertEqual(error as? JWTDecoderError, .invalidBase64)
        }
    }

    func testDecodePayload_throwsInvalidJSON_whenPayloadDoesNotMatchExpectedShape() {
        let badPayload = try! JSONSerialization.data(withJSONObject: ["foo": "bar"])
        let token = "header.\(badPayload.base64EncodedString()).signature"

        XCTAssertThrowsError(try JWTDecoder.decodePayload(from: token)) { error in
            XCTAssertEqual(error as? JWTDecoderError, .invalidJSON)
        }
    }

    // MARK: - isTokenValid

    func testIsTokenValid_returnsTrue_forFutureExpiry() {
        let token = makeToken(exp: Int(Date().timeIntervalSince1970) + 3600)
        XCTAssertTrue(JWTDecoder.isTokenValid(token))
    }

    func testIsTokenValid_returnsFalse_forExpiredToken() {
        let token = makeToken(exp: Int(Date().timeIntervalSince1970) - 3600)
        XCTAssertFalse(JWTDecoder.isTokenValid(token))
    }

    func testIsTokenValid_returnsFalse_forMalformedToken() {
        XCTAssertFalse(JWTDecoder.isTokenValid("garbage"))
    }

    // MARK: - Convenience accessors

    func testGetUserPermissions_returnsPermissionsFromToken() {
        let token = makeToken(permissions: ["CanGetWorkouts", "CanGetClients"])
        XCTAssertEqual(JWTDecoder.getUserPermissions(token: token), ["CanGetWorkouts", "CanGetClients"])
    }

    func testGetUserPermissions_returnsEmptyArray_forMalformedToken() {
        XCTAssertEqual(JWTDecoder.getUserPermissions(token: "garbage"), [])
    }

    func testGetUserRole_returnsRoleFromToken() {
        let token = makeToken(role: "Client")
        XCTAssertEqual(JWTDecoder.getUserRole(token: token), "Client")
    }

    func testGetUserRole_returnsEmptyString_forMalformedToken() {
        XCTAssertEqual(JWTDecoder.getUserRole(token: "garbage"), "")
    }

    func testGetUsername_returnsNameFromToken() {
        let token = makeToken(name: "sarah")
        XCTAssertEqual(JWTDecoder.getUsername(token: token), "sarah")
    }

    func testGetUsername_returnsEmptyString_forMalformedToken() {
        XCTAssertEqual(JWTDecoder.getUsername(token: "garbage"), "")
    }
}
