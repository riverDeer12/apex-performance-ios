//
//  Client.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 18.12.2025..
//

import Foundation
import SwiftUI

struct Client: Identifiable, Decodable, Encodable {
    let id: UUID
    var firstName: String
    var lastName: String
    var email: String?
    var phone: String?
    var credits: Int?
    var bodyMeasurements: [BodyMeasurement]?
    var lastCreditsIncrease: Date?
    // One of ClientPlan raw values.
    var plan: String? = nil
    
    var fullName: String {
        return self.firstName + " " + self.lastName
    }
}

// How the client trains, same values as the API (ClientPlans).
enum ClientPlan: String, CaseIterable, Identifiable {
    case privateCoaching = "PrivateCoaching"
    case onlineCoaching = "OnlineCoaching"
    case membership = "Membership"

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .privateCoaching: return "plan_private_coaching"
        case .onlineCoaching: return "plan_online_coaching"
        case .membership: return "plan_membership"
        }
    }

    var localizedTitle: String {
        switch self {
        case .privateCoaching: return String(localized: "plan_private_coaching")
        case .onlineCoaching: return String(localized: "plan_online_coaching")
        case .membership: return String(localized: "plan_membership")
        }
    }

    /// Title for a plan value from the API, or nil when unknown.
    static func title(for value: String?) -> LocalizedStringKey? {
        value.flatMap(ClientPlan.init(rawValue:))?.title
    }
}

