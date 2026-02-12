//
//  ApiError.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 07.01.2026..
//

import Foundation

enum ApiError: Error {
    case validation(ApiErrorResponse)
    case server(message: String)
}
