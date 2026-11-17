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
    // Row of a person: their profile picture (or initials) instead of the icon.
    var person: (name: String, pictureUrl: String?)? = nil
    // Small icon on the person's picture, e.g. the status of their training.
    var personBadge: (systemImage: String, tint: Color)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            if let person, let personBadge {
                UserAvatarView(name: person.name, pictureUrl: person.pictureUrl, size: 34)
                    .avatarBadge(systemImage: personBadge.systemImage, tint: personBadge.tint, size: 16)
            } else if let person {
                UserAvatarView(name: person.name, pictureUrl: person.pictureUrl, size: 34)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconTint.opacity(0.15))
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(iconTint)
                }
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
        // The whole row is tappable when it is a link or button label.
        .contentShape(Rectangle())
    }
}

