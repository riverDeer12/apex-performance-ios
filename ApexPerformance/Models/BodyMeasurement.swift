//
//  BodyMeasurement.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 23.12.2025..
//

import Foundation

struct BodyMeasurement: Identifiable, Decodable, Encodable {
    let id: UUID
    var height: Decimal
    var weight: Decimal
    var shoulders: Decimal
    var chest: Decimal
    var upperArm: Decimal
    var waist: Decimal
    var thigh: Decimal
    var calves: Decimal
    var glutes: Decimal
    let measuredAt: Date
    let client: Client?
}

extension BodyMeasurement {
    /// Wheel range and starting value of a measurement, by its title key.
    static func wheel(for key: String) -> (range: ClosedRange<Int>, start: Decimal) {
        switch key {
        case "height": return (100...230, 175)
        case "weight": return (30...250, 75)
        case "shoulders": return (60...180, 110)
        case "chest": return (50...180, 100)
        case "upper_arm": return (15...70, 32)
        case "waist": return (40...180, 85)
        case "thigh": return (30...100, 55)
        case "calves": return (20...70, 37)
        case "glutes": return (50...180, 100)
        default: return (0...300, 0)
        }
    }
}
