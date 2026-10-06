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
                    .apexLabel()
                    .padding(.top, 2)
            }
            
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .apexCardBackground()
    }
}
