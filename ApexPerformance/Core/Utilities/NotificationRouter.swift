//
//  NotificationRouter.swift
//  ApexPerformance
//

import Foundation

enum AppTab: Hashable {
    case home
    case appointments
    case appointmentRequests
    case workouts
    case clients
    case bodyMeasurements
    case trainings
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
        case "client_goal", "monthly_review":
            pendingTab = .home
        case "monthly_review_reminder":
            pendingTab = .clients
        default:
            #if DEBUG
            print("⚠️ Unknown notification type: \(notificationType)")
            #endif
        }
    }
}
