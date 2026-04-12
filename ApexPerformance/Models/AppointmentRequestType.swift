import Foundation

import SwiftUI

struct AppointmentRequestType: Decodable {
    let id: UUID
    let name: String
    let description: String?
}


