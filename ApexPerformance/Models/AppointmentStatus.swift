//
//  AppointmentStatus.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 18.12.2025..
//

import Foundation

struct AppointmentStatus: Identifiable, Decodable {
    let id: UUID
    let name: String
    let description: String
}

