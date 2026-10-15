//
//  NotifyClientToggle.swift
//  ApexPerformance
//

import SwiftUI

/// Coach's choice whether the client gets a push notification about
/// what is being saved (the API's "notifyClient").
struct NotifyClientToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label("notify_client", systemImage: "bell")
        }
        .tint(Color.apexMainColor)
    }
}
