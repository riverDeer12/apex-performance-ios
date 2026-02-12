//
//  ApiErrorResponse.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 07.01.2026..
//

import Foundation

struct ApiErrorResponse: Decodable {
    let statusCode: Int
    let message: String
    let errors: [String: [String]]?
}
