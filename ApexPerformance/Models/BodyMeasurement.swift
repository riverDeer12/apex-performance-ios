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
