//
//  Profile.swift
//  ApexPerformance
//

import Foundation

// Profile of the logged user (api/profile), same for all roles.
struct Profile: Decodable {
    let userId: UUID
    let username: String
    let email: String
    let roles: [String]
    // Client, Coach, Administrator or nil when user
    // has no personal data (e.g. only super admin).
    let profileType: String?
    let firstName: String?
    let lastName: String?
    let phone: String?
    let hasProfilePicture: Bool
    // Kept as a string, only used to reload the picture when it changes.
    let profilePictureUpdatedAt: String?

    var hasPersonalData: Bool {
        profileType != nil
    }

    var hasPhone: Bool {
        profileType == "Client" || profileType == "Coach"
    }
}

struct UpdateProfileRequest: Encodable {
    let email: String
    let firstName: String?
    let lastName: String?
    let phone: String?
}

// Sample data for SwiftUI previews, no API calls needed.
extension Profile {
    static let previewClient = Profile(
        userId: UUID(),
        username: "ana.horvat",
        email: "ana.horvat@example.com",
        roles: ["Client"],
        profileType: "Client",
        firstName: "Ana",
        lastName: "Horvat",
        phone: "+385 91 123 4567",
        hasProfilePicture: false,
        profilePictureUpdatedAt: nil
    )

    static let previewSuperAdmin = Profile(
        userId: UUID(),
        username: "admin",
        email: "admin@example.com",
        roles: ["SuperAdmin"],
        profileType: nil,
        firstName: nil,
        lastName: nil,
        phone: nil,
        hasProfilePicture: false,
        profilePictureUpdatedAt: nil
    )
}
