import Foundation

struct AppointmentRequest: Identifiable, Decodable {
    let id: UUID
    let comment: String
    let sender: Client
    let type: CatalogData
    let appointment: Appointment
    let createdAt: Date
}


// Request as returned by GET appointment-requests (all requests with
// their status). Clients use it to follow requests they have sent.
struct SentAppointmentRequest: Identifiable, Decodable {
    let id: UUID
    let comment: String
    let type: CatalogData
    let status: Status
    let appointment: Appointment
    let createdAt: Date
    let updatedAt: Date

    struct Status: Decodable {
        let name: String
    }
}

// Appointment the client requested (created) themselves, from
// GET appointments/my-requests. Its status is the request status.
struct MyAppointmentRequest: Decodable {
    let appointment: Appointment
    let createdAt: Date
    let updatedAt: Date
}

extension SentAppointmentRequest {
    static let newAppointmentTypeName = "NewAppointment"

    // Shows a requested appointment in the same list as other requests.
    init(newAppointment request: MyAppointmentRequest) {
        // An appointment that is in progress was approved.
        let statusName = request.appointment.status.name == "InProgress" ? "Approved" : request.appointment.status.name

        self.init(
            id: request.appointment.id,
            comment: "",
            type: CatalogData(id: request.appointment.id, name: Self.newAppointmentTypeName, description: ""),
            status: Status(name: statusName),
            appointment: request.appointment,
            createdAt: request.createdAt,
            updatedAt: request.updatedAt
        )
    }
}
