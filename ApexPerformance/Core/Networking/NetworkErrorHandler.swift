//
//  NetworkErrorHandler.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 16.12.2025..
//

import Foundation

func mapError(_ error: Error) -> String {
    
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet:
            return "No internet connection."
        case .timedOut:
            return "The request timed out. Please try again."
        default:
            return "Network error. Please try again."
        }
    }
    
    if let apiError = error as? ApiError {
        switch apiError {
        case .validation(let response):
            let messages = response.errors?
                .flatMap { key, values in
                    values.map { "\(key.capitalized): \($0)" }
                }
                .joined(separator: "\n")
            
            return messages ?? response.message
            
        case .server(let message):
            return message
        }
    }
    
    if error is DecodingError {
        return "Unexpected server response."
    }
    
    return "Something went wrong."
}

