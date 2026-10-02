//
//  AppUpdateChecker.swift
//  ApexPerformance
//

import Foundation

/// Checks the App Store for a newer version of the app, using
/// Apple's public lookup API (no backend needed).
enum AppUpdateChecker {

    struct AvailableUpdate: Equatable {
        let version: String
        let storeURL: URL
    }

    private struct LookupResponse: Decodable {
        let results: [Result]

        struct Result: Decodable {
            let version: String
            let trackViewUrl: String
        }
    }

    // Store the app is sold in, used when the device region has no result.
    private static let fallbackCountry = "hr"

    /// Newer App Store version than the installed one, or nil when the
    /// app is up to date or the store can't be reached.
    static func availableUpdate() async -> AvailableUpdate? {
        guard let bundleId = Bundle.main.bundleIdentifier,
              let installedVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        else { return nil }

        var countries = [fallbackCountry]
        if let region = Locale.current.region?.identifier.lowercased(), region != fallbackCountry {
            countries.insert(region, at: 0)
        }

        for country in countries {
            guard let result = await lookup(bundleId: bundleId, country: country) else { continue }

            guard isVersion(result.version, newerThan: installedVersion),
                  let url = URL(string: result.trackViewUrl) else { return nil }

            return AvailableUpdate(version: result.version, storeURL: url)
        }

        return nil
    }

    private static func lookup(bundleId: String, country: String) async -> LookupResponse.Result? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleId),
            URLQueryItem(name: "country", value: country),
            // Avoid an old cached answer right after a release.
            URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))
        ]
        guard let url = components?.url else { return nil }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(LookupResponse.self, from: data).results.first
        } catch {
            return nil
        }
    }

    /// Compares versions like "1.10.1" and "1.9" number by number.
    static func isVersion(_ version: String, newerThan other: String) -> Bool {
        let lhs = version.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = other.split(separator: ".").map { Int($0) ?? 0 }

        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }
}
