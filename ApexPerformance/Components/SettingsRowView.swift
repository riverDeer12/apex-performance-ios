//
//  SettingsRow.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 04.01.2026..
//

import SwiftUI

struct SettingsRowView: View {
    let icon: String
    let iconTint: Color
    let title: Text
    let subtitle: Text?
    let showChevron: Bool
    var titleColor: Color = .primary
    var badge: LocalizedStringKey? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconTint.opacity(0.15))
                    .frame(width: 34, height: 34)
                
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconTint)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    title
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(titleColor)
                    
                    if let badge {
                        BadgeView(text: badge, color: .red, isPulsing: true)
                    }
                }
                
                if let subtitle {
                    subtitle
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 10)
    }
}

