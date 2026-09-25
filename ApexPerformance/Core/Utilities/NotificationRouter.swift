//
//  NotificationRouter.swift
//  ApexPerformance
//

import Foundation

enum AppTab: Hashable {
    case appointments
    case appointmentRequests
    case workouts
    case clients
    case bodyMeasurements
    case profile
}

// Holds the tab a tapped push notification points to until HomeView is on
// screen to open it, which also covers cold launches and logged-out users.
@MainActor
final class NotificationRouter: ObservableObject {

    static let shared = NotificationRouter()

    @Published var pendingTab: AppTab?

    private init() {}

    func handle(notificationType: String) {
        switch notificationType {
        case "appointment_request":
            pendingTab = .appointmentRequests
        case "appointment_updated":
            pendingTab = .appointments
        case "body_measurement":
            pendingTab = .bodyMeasurements
        default:
            #if DEBUG
            print("⚠️ Unknown notification type: \(notificationType)")
            #endif
        }
    }
}
