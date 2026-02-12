//
//  StatusResponse.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 09.01.2026..
//

import Foundation

struct StatusResponse: Decodable{
    let id: UUID
    let status: Bool
}
