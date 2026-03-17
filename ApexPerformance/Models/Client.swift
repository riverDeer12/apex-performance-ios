//
//  Client.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 18.12.2025..
//

import Foundation

struct Client: Identifiable, Decodable, Encodable {
    let id: UUID
    var firstName: String
    var lastName: String
    var email: String?
    var phone: String?
    var credits: Int?
    var bodyMeasurements: [BodyMeasurement]?
    var lastCreditsIncrease: Date?
    
    var fullName: String {
        return self.firstName + " " + self.lastName
    }
}

