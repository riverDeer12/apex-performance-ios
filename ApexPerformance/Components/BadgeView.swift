//
//  Badge.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 04.01.2026..
//

import SwiftUI

struct BadgeView: View {
    let text: LocalizedStringKey
    let color: Color
    var isPulsing: Bool = false
    
    @State private var pulse = false
    
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .scaleEffect(isPulsing && pulse ? 1.06 : 1.0)
            .opacity(isPulsing && pulse ? 0.85 : 1.0)
            .animation(
                isPulsing
                ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                : .default,
                value: pulse
            )
            .onAppear {
                guard isPulsing else { return }
                pulse = true
            }
            .onDisappear {
                pulse = false
            }
    }
}
