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
