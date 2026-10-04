//
//  AppearanceSwitcherView.swift
//  ApexPerformance
//

import SwiftUI

/// App colour scheme the user picked in their profile.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appAppearance"

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system: return "appearance_system"
        case .light: return "appearance_light"
        case .dark: return "appearance_dark"
        }
    }

    /// nil follows the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct AppearanceSwitcherView: View {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system

    var body: some View {
        Menu {
            Picker(selection: $appearance) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.title).tag(option)
                }
            } label: { EmptyView() }
        } label: {
            SettingsRowView(
                icon: "circle.lefthalf.filled",
                iconTint: Color.apexMainColor,
                title: Text("appearance"),
                subtitle: Text(appearance.title),
                showChevron: true
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AppearanceSwitcherView()
        .padding()
}
