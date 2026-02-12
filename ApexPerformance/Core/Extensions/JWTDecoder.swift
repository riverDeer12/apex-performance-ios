//
//  JWTDecoder.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 19.12.2025..
//

import Foundation

struct JWTPayload: Decodable {
    let name: String
    let sub: String
    let permissions: [String]
    let role: String
    let exp: Int
    let iat: Int
    let nbf: Int
}

enum JWTDecoderError: Error {
    case invalidFormat
    case invalidBase64
    case invalidJSON
}

final class JWTDecoder {
    
    static func decodePayload(from token: String) throws -> JWTPayload {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { throw JWTDecoderError.invalidFormat }
        
        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        let paddingLength = 4 - (base64.count % 4)
        if paddingLength < 4 {
            base64 += String(repeating: "=", count: paddingLength)
        }
        
        guard let data = Data(base64Encoded: base64) else {
            throw JWTDecoderError.invalidBase64
        }
        
        do {
            return try JSONDecoder().decode(JWTPayload.self, from: data)
        } catch {
            print("Error decoding.")
            throw JWTDecoderError.invalidJSON
        }
    }
    
    static func isTokenValid(_ token: String) -> Bool {
        guard let payload = try? decodePayload(from: token) else { return false }
        return payload.exp > Int(Date().timeIntervalSince1970)
    }
    
    static func getUserPermissions(token: String) -> [String] {
        guard let payload = try? decodePayload(from: token) else { return [] }
        return payload.permissions;
    }
    
    static func getUserRole(token: String) -> String {
        guard let payload = try? decodePayload(from: token) else { return "" }
        return payload.role;
    }    
    
    static func getUsername(token: String) -> String {
        guard let payload = try? decodePayload(from: token) else { return "" }
        return payload.name;
    }
}

