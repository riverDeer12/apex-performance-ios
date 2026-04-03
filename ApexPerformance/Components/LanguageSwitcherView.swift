//
//  LanguageSwitcherView.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 12.01.2026..
//

import SwiftUI

struct LanguageSwitcherView: View {
    @AppStorage("appLanguage") private var appLanguage: String = LanguageManager.getDefaultLanguage()
    
    var body: some View {
        Menu {
            Picker(selection: $appLanguage) {
                Text("english").tag("en")
                Text("croatian").tag("hr")
                Text("italian").tag("it")
            } label: { EmptyView() }
        } label: {
            SettingsRowView(
                icon: "globe",
                iconTint: Color.apexMainColor,
                title: Text("language"),
                subtitle: currentLanguageLabel,
                showChevron: true
            )
        }
        .buttonStyle(.plain)
    }
    
    private var currentLanguageLabel: Text {
        switch appLanguage {
            case "hr": return Text("croatian")
            case "it": return Text("italian")
            default:   return Text("english")
        }
    }
}

#Preview {
    LanguageSwitcherView()
        .padding()
}
