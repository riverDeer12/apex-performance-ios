import Foundation

struct AppointmentRequest: Identifiable, Decodable {
    let id: UUID
    let comment: String
    let sender: Client
    let type: CatalogData
    let appointment: Appointment
}

