//
//  AppointmentsStatus.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 18.12.2025..
//

import Foundation

struct AppointmentsStatus : Decodable {
    let approvedAppointments: [Appointment]
    let pendingAppointments: [Appointment]
    let inProgressAppointments: [Appointment]
}
