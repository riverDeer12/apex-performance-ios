//
//  UserPictureTests.swift
//  ApexPerformanceTests
//

import XCTest
@testable import ApexPerformance

/// Profile picture links of other users, as the API sends them.
final class UserPictureTests: XCTestCase {

    func testRelativeLinkIsLoadedFromTheAPI() {
        let link = "users/0F8B6A1E-2C3D-4E5F-8A9B-0C1D2E3F4A5B/picture?v=1763375400250"
        let url = UserPictureCache.url(for: link)
        var base = AppEnvironment.apiURL.absoluteString
        if base.hasSuffix("/") { base.removeLast() }
        XCTAssertEqual(url?.absoluteString, "\(base)/\(link)")
        XCTAssertEqual(url?.query, "v=1763375400250")
    }

    func testPictureLinkDecodesAndIsOptional() throws {
        let decoder = JSONDecoder()
        let withPicture = try decoder.decode(Coach.self, from: Data("""
            {"id":"0F8B6A1E-2C3D-4E5F-8A9B-0C1D2E3F4A5B","firstName":"Luka","lastName":"Marić",
             "email":null,"phone":null,"pictureUrl":"users/1/picture?v=2"}
            """.utf8))
        XCTAssertEqual(withPicture.pictureUrl, "users/1/picture?v=2")

        let olderAPI = try decoder.decode(ChatParticipant.self, from: Data("""
            {"id":"0F8B6A1E-2C3D-4E5F-8A9B-0C1D2E3F4A5B","userId":"0F8B6A1E-2C3D-4E5F-8A9B-0C1D2E3F4A5C",
             "fullName":"Ana Kovač"}
            """.utf8))
        XCTAssertNil(olderAPI.pictureUrl)
    }

    func testNoPictureLoadsNothing() async {
        let image = await UserPictureCache.shared.image(for: nil)
        XCTAssertNil(image)
        XCTAssertNil(UserPictureCache.shared.cachedImage(for: nil))
    }
}
