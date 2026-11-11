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
    case chat
    case profile
}

// Holds the tab a tapped push notification points to until HomeView is on
// screen to open it, which also covers cold launches and logged-out users.
@MainActor
final class NotificationRouter: ObservableObject {

    static let shared = NotificationRouter()

    @Published var pendingTab: AppTab?
    // Requests open from the appointments tab when there is no requests tab.
    @Published var opensAppointmentRequests = false
    // Chat conversation a tapped message push opens.
    @Published var pendingConversationId: UUID?
    // Training a tapped training push opens.
    @Published var pendingTrainingId: UUID?

    private init() {}

    /// apexperformance://training/<id>, from a tap on the training's Live
    /// Activity: opens the training like a training push does.
    func handle(url: URL) {
        guard url.scheme == "apexperformance", url.host == "training" else { return }
        let id = url.pathComponents.dropFirst().first.flatMap(UUID.init(uuidString:))
        // Not saved yet: the app opens on the new training form, still open.
        guard let id else { return }
        pendingTrainingId = id
        pendingTab = .trainings
    }

    func handle(notificationType: String, conversationId: String? = nil, trainingId: String? = nil) {
        switch notificationType {
        case "training":
            pendingTrainingId = trainingId.flatMap(UUID.init(uuidString:))
            pendingTab = .trainings
        case "chat_message":
            pendingConversationId = conversationId.flatMap(UUID.init(uuidString:))
            pendingTab = .chat
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
