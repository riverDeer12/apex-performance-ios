//
//  GetTimeSlotsRequest.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 16.01.2026..
//

import Foundation
import SwiftUI

struct GetTimeSlotsRequest: Encodable{
    let coaches: [UUID]
    let day: String
}
