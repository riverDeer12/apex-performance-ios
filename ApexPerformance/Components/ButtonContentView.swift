//
//  ButtonView.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 09.01.2026..
//

import SwiftUI

struct ButtonContentView: View {
    let text: LocalizedStringKey
    let style: ButtonContentStyle
    
    init(_ text: LocalizedStringKey, style: ButtonContentStyle = .text) {
        self.text = text
        self.style = style
    }
    
    var body: some View {
        HStack(spacing: 6) {
            switch style {
            case .text:
                Text(text)
                
            case .textWithIcon(let systemName):
                Text(text)
                Image(systemName: systemName)
                
            case .iconOnly(let systemName):
                Image(systemName: systemName)
                    .accessibilityLabel(text) // important for icon-only
            }
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Color.apexMainColor)
        .padding(.horizontal, style == .iconOnly(systemName: "") ? 0 : 12) // (see note below)
        .frame(height: 34)
        .padding(.horizontal, style.isIconOnly ? 0 : 0) // optional, remove if not needed
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.apexMainColor.opacity(0.10))
        )
        .padding(.horizontal, style.isIconOnly ? 10 : 0) // optional
        .frame(minWidth: style.isIconOnly ? 34 : nil) // icon-only square-ish
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension ButtonContentStyle {
    var isIconOnly: Bool {
        if case .iconOnly = self { return true }
        return false
    }
}


#Preview("TextButton") {
    ButtonContentView(
        "click_me", style: .text
    )
}

#Preview("IconButton") {
    ButtonContentView(
       "", style: .iconOnly(systemName: "paperplane")
    )
}

#Preview("TextWithIconButton") {
    ButtonContentView(
        "send", style: .textWithIcon(systemName: "paperplane")
    )
}
