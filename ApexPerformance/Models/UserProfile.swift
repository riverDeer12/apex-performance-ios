//
//  UserProfile.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 04.01.2026..
//

import Foundation

struct UserProfile: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let credits: Int?
    let plan: String?
    /// Approved appointments of this month that are over, worked out by the
    /// API: appointments only has the client's upcoming ones.
    var doneThisMonth: Int? = nil
}
