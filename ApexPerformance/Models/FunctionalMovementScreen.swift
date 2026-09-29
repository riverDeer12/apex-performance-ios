//
//  FunctionalMovementScreen.swift
//  ApexPerformance
//

import Foundation

// Functional Movement Screen (FMS) of a client. Each test
// result is free text, same as on the web.
struct FunctionalMovementScreen: Identifiable, Decodable {
    let id: UUID
    var deepSquat: String
    var hurdleStep: String
    var inLineLunge: String
    var activeStraightLegRaise: String
    var trunkStabilityPushUp: String
    var rotaryStability: String
    var shoulderMobility: String
    let createdAt: Date
    let client: Person

    struct Person: Decodable {
        let id: UUID
        let firstName: String?
        let lastName: String?
    }
}

// Body of both create (POST) and update (PUT) requests.
struct FunctionalMovementScreenRequest: Encodable {
    let client: UUID
    let deepSquat: String
    let hurdleStep: String
    let inLineLunge: String
    let activeStraightLegRaise: String
    let trunkStabilityPushUp: String
    let rotaryStability: String
    let shoulderMobility: String
}
