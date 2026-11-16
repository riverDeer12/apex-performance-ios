//
//  HomeWidgetWriter.swift
//  ApexPerformance
//

import Foundation
import WidgetKit

/// Writes what the home screen widget shows (HomeWidgetSnapshot) and
/// reloads the widget when it changed.
enum HomeWidgetWriter {

    /// Client: the next approved appointment with the coach, and the package.
    static func client(appointments: [Appointment], coachName: String?, package: PackageSummary) {
        let next = appointments
            .filter { $0.startTime > .now }
            .min { $0.startTime < $1.startTime }
        write(HomeWidgetSnapshot(
            role: .client,
            languageCode: AppLanguage.current,
            title: String(localized: "next_appointment"),
            emptyText: String(localized: "widget_no_appointment"),
            appointmentId: next?.id,
            appointmentStart: next?.startTime,
            personName: next == nil ? nil : coachName,
            packageText: package.total > 0 ? "\(package.done) / \(package.total)" : nil,
            packageLabel: String(localized: "my_package"),
            updatedAt: .now
        ))
    }

    /// Coach: the next appointment today with its client, and the requests waiting.
    static func coach(appointments: [Appointment], pendingRequests: Int) {
        let next = appointments
            .filter { $0.endTime > .now && Calendar.current.isDateInToday($0.startTime) }
            .min { $0.startTime < $1.startTime }
        write(HomeWidgetSnapshot(
            role: .coach,
            languageCode: AppLanguage.current,
            title: String(localized: "today"),
            emptyText: String(localized: "widget_no_more_appointments_today"),
            appointmentId: next?.id,
            appointmentStart: next?.startTime,
            personName: next.map { $0.clients.map(\.fullName).joined(separator: ", ") },
            pendingRequests: pendingRequests,
            pendingLabel: String(localized: "pending_requests"),
            updatedAt: .now
        ))
    }

    /// After logout: "Log in to Apex".
    static func loggedOut() {
        write(HomeWidgetSnapshot(
            role: .loggedOut,
            languageCode: AppLanguage.current,
            title: "Apex",
            emptyText: String(localized: "widget_log_in"),
            updatedAt: .now
        ))
    }

    private static func write(_ snapshot: HomeWidgetSnapshot) {
        if snapshot.save() {
            WidgetCenter.shared.reloadTimelines(ofKind: HomeWidgetSnapshot.widgetKind)
        }
    }
}
