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
    let firstName: String?
    let lastName: String?
    let email: String?
    let phone: String?
    // Profile picture link, nil when there is none (or from an older API).
    var pictureUrl: String? = nil
    
    var fullName: String {
        let first = firstName ?? ""
        let last = lastName ?? ""
        let combined = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? "Unknown Coach" : combined
    }
}
