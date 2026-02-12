//
//  ApiClient.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 16.12.2025..
//

import Foundation

@MainActor
final class APIClient {
    
    static let shared = APIClient()
    private init() {}
    
    private var token: String? {
        KeychainService.shared.getToken()
    }
    
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        
        // Handles: 2025-12-18T10:00:00+01:00 and also with milliseconds
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            
            // try with fractional seconds
            if let date = iso.date(from: str) { return date }
            
            // fallback: no fractional seconds
            let iso2 = ISO8601DateFormatter()
            iso2.formatOptions = [.withInternetDateTime]
            if let date = iso2.date(from: str) { return date }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(str)"
            )
        }
        
        return decoder
    }()
    
    func request<T: Decodable>(
        _ url: URL,
        method: HTTPMethod = .get,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws -> T {
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Default headers
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // Bearer token
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Custom headers (optional)
        headers.forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if http.statusCode == 401 {
            throw AuthError.unauthorized
        }
        
        guard 200..<300 ~= http.statusCode else {
            if let apiError = try? JSONDecoder().decode(ApiErrorResponse.self, from: data) {
                throw ApiError.validation(apiError)
            } else {
                throw ApiError.server(message: "Unknown server error.")
            }
        }
        
        return try Self.decoder.decode(T.self, from: data)
    }
}


enum APIError: Error {
    case server(Int)
}

enum AuthError: Error {
    case unauthorized
}

enum HTTPMethod: String {
    case get     = "GET"
    case post    = "POST"
    case put     = "PUT"
    case patch   = "PATCH"
    case delete  = "DELETE"
}
