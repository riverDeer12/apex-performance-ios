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
    // Coaches of the appointment, for their pictures; nil from an older API.
    var coaches: [Coach]? = nil
}

extension Appointment {
    /// Clients of the appointment for the avatars (name and picture).
    var clientAvatars: [(name: String, pictureUrl: String?)] {
        clients.map { ($0.fullName, $0.pictureUrl) }
    }
}

extension Appointment {
    var isActive: Bool {
        status.name == BusinessStatus.approved.rawValue && startTime > Date()
    }
    
    var isCompleted: Bool {
        !isActive && status.name == BusinessStatus.approved.rawValue
    }
}

enum BusinessStatus: String, Decodable {
    case approved = "Approved"
    case pending = "Pending"
    case cancelled = "Cancelled"
}
