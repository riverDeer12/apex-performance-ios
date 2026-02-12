//
//  Appointment.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 18.12.2025..
//

import Foundation

struct Appointment: Decodable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let timeSlot: TimeSlot
    let status: AppointmentStatus
    let clients: [Client]
}

extension Appointment {
    var isActive: Bool {
        status.name == BusinessStatus.approved.rawValue && startTime > Date()
    }
    
    var isCompleted: Bool {
        !isActive && status.name != BusinessStatus.approved.rawValue
    }
}

enum BusinessStatus: String, Decodable {
    case approved = "Approved"
    case pending = "Pending"
    case cancelled = "Cancelled"
}
