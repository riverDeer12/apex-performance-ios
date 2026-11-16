//
//  EmptyStateView.swift
//  ApexPerformance
//

import SwiftUI

/// What an empty list shows: an icon, one sentence and, where it makes
/// sense, a button for the first step (e.g. "Book appointment").
struct EmptyStateView: View {
    let systemImage: String
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Color.apexMainColor)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 6)
                        .frame(minHeight: 32)
                }
                .buttonStyle(.bordered)
                .tint(Color.apexMainColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("empty-state")
    }
}

#Preview {
    VStack(spacing: 16) {
        CardView {
            EmptyStateView(systemImage: "calendar", message: "no_appointments_today")
        }
        CardView {
            EmptyStateView(systemImage: "calendar.badge.plus", message: "no_client_appointments",
                           actionTitle: "book_appointment") {}
        }
    }
    .padding(20)
    .background(Color.apexBackground)
}
