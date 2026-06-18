//
//  TimeSlot.swift
//  ApexPerformance
//
//

import Foundation

struct TimeSlot: Identifiable, Decodable, Equatable {
    let id: UUID
    var name: String? = nil
    var day: String? = nil
    var startTime: String? = nil
    var endTime: String? = nil
    var description: String? = nil
    var isTaken: Bool? = nil
    var appointmentId: UUID? = nil
}

