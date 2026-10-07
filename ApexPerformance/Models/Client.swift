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


/// Which workouts a client can see in the library, agreed with the coach.
enum WorkoutLibraryAccess {
    /// Private coaching: only mobility and stretching workouts.
    case mobilityAndStretching
    /// Online coaching: all workouts.
    case all
    /// Membership or no plan: no library.
    case none

    init(plan: String?) {
        switch plan.flatMap(ClientPlan.init(rawValue:)) {
        case .privateCoaching: self = .mobilityAndStretching
        case .onlineCoaching: self = .all
        case .membership, nil: self = .none
        }
    }

    func allows(_ workout: Workout) -> Bool {
        switch self {
        case .mobilityAndStretching: return workout.isMobilityOrStretching
        case .all: return true
        case .none: return false
        }
    }
}

extension Workout {
    // Parts of workout type names, in any language, for mobility and stretching.
    private static let mobilityAndStretchingKeywords = [
        "mobil", "stretch", "istez", "fleksib", "flexib", "allung"
    ]

    /// True when one of the workout's types is mobility or stretching.
    var isMobilityOrStretching: Bool {
        workoutTypes.contains { type in
            type.name.allValues.contains { name in
                let name = name.lowercased()
                return Self.mobilityAndStretchingKeywords.contains { name.contains($0) }
            }
        }
    }
}
