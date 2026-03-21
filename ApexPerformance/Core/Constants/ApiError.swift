//
//  ApiError.swift
//  ApexPerformance
//
//

import Foundation

enum ApiError: Error {
    case validation(ApiErrorResponse)
    case server(message: String)
}

