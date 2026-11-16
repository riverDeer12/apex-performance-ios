//
//  HomeWidgetSnapshot.swift
//  ApexPerformance
//
//  Shared with the TrainingActivity widget extension.
//

import Foundation

/// What the home screen widget shows, written by the app whenever it loads
/// home or appointments (and on logout) into the App Group both share; the
/// widget only reads it. Texts come already translated to the app's
/// language, which the extension doesn't know.
struct HomeWidgetSnapshot: Codable, Equatable {
    enum Role: String, Codable {
        case client, coach, loggedOut
    }

    var role: Role
    // The app's language, for dates and "in 2 h" in the widget.
    var languageCode: String
    // "Sljedeći trening" (client) or "Danas" (coach).
    var title: String
    // Shown without an appointment, e.g. "Nema zakazanih termina".
    var emptyText: String
    // Next appointment: the client's next one, the coach's next one today.
    var appointmentId: UUID?
    var appointmentStart: Date?
    // The client's coach or the coach's client.
    var personName: String?
    // Client's package, e.g. "5 / 12", with its label "Paket".
    var packageText: String?
    var packageLabel: String?
    // Coach: requests waiting for an answer, with their label.
    var pendingRequests: Int?
    var pendingLabel: String?
    var updatedAt: Date

    static let widgetKind = "ApexHomeWidget"
    private static let storageKey = "homeWidgetSnapshot"

    /// group.<app bundle id>, the same for the app and its extension.
    static var appGroupId: String {
        let bundleId = Bundle.main.bundleIdentifier ?? "software.rdd.ApexPerformance"
        let appId = bundleId.hasSuffix(".TrainingActivity")
            ? String(bundleId.dropLast(".TrainingActivity".count))
            : bundleId
        return "group.\(appId)"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    static func load() -> HomeWidgetSnapshot? {
        guard let data = defaults?.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(HomeWidgetSnapshot.self, from: data)
    }

    /// Saves it; true when it changed (the widget is reloaded then).
    @discardableResult
    func save() -> Bool {
        var previous = Self.load()
        previous?.updatedAt = updatedAt
        guard previous != self, let data = try? JSONEncoder().encode(self) else { return false }
        Self.defaults?.set(data, forKey: Self.storageKey)
        return true
    }
}
