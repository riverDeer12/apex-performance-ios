//
//  Card.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 04.01.2026..
//

import SwiftUI

struct CardView<Content: View>: View {
    var title: LocalizedStringKey? = nil
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .padding(.top, 2)
            }
            
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}
