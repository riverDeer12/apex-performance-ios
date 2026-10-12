//
//  NetworkErrorHandler.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 16.12.2025..
//

import Foundation

/// Message for an error, already in the app's language. Callers either
/// show it as it is or pass it to LocalizedStringKey, which leaves it as is.
func mapError(_ error: Error) -> String {
    
    // The user is taken to login, which explains it.
    if error is AuthError {
        return localized("session_expired")
    }
    
    if let urlError = error as? URLError {
        switch urlError.code {
        case .notConnectedToInternet:
            return localized("error_no_internet")
        case .timedOut:
            return localized("error_timed_out")
        default:
            return localized("error_network")
        }
    }
    
    if let apiError = error as? ApiError {
        switch apiError {
        case .validation(let response):
            // The API sends error codes ("1000"), which have translations.
            let messages = response.errors?
                .flatMap { key, values in
                    values.map { "\(key.capitalized): \(localized($0))" }
                }
                .joined(separator: "\n")
            
            return messages ?? localized(response.message)
            
        case .server(let message):
            return localized(message)
        }
    }
    
    if error is DecodingError {
        return localized("error_unexpected_response")
    }
    
    return localized("error_something_went_wrong")
}

// Translation of a key or error code, or the text itself when there is none.
private func localized(_ key: String) -> String {
    String(localized: String.LocalizationValue(key))
}


extension Error {
    // Request was cancelled because the view went away or a refresh
    // started again. Not a real error, so nothing should be shown.
    var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}
