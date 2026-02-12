//
//  Coach.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 16.01.2026..
//

import Foundation
import SwiftUI

struct Coach: Encodable, Decodable, Identifiable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
}
