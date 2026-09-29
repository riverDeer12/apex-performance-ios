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
