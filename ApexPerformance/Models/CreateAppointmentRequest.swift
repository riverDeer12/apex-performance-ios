//
//  CreateAppointmentRequest.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 15.01.2026..
//

import Foundation
import SwiftUI

struct CreateAppointmentRequest: Encodable{
    let type: UUID
    let timeSlot: UUID
    var location: UUID?
    let clients: [UUID]
    let coaches: [UUID]
    let startTime: String
    let endTime: String
}
