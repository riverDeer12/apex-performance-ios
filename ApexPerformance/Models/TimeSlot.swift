//
//  TimeSlot.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 18.12.2025..
//

import Foundation

struct TimeSlot: Identifiable, Decodable, Equatable {
    let id: UUID
    var name: String? = nil
    var day: String? = nil
    var startTime: String? = nil
    var endTime: String? = nil
    var description: String? = nil
}
