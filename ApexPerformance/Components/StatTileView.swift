//
//  StatTile.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 04.01.2026..
//

import SwiftUI

struct StatTileView: View {
    let value: String
    let label: LocalizedStringKey
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}
