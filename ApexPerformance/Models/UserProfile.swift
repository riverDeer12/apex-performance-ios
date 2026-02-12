//
//  UserProfile.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 04.01.2026..
//

import Foundation

struct UserProfile: Decodable {
    let firstName: String
    let lastName: String
    let email: String
    let credits: Int
}
