//
//  Toast.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 05.01.2026..
//

import SwiftUI

struct ToastView: View {
    let message: Text
    let toastType: ToastType
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toastType.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                toastType.title
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                
                message
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(2)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 20)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(toastType.color.opacity(0.85))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(radius: 12, y: 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(toastType.title): \(message)")
    }
}

#Preview {
    ToastView(message: Text("successfully_updated_user"), toastType: ToastType.success)
}
