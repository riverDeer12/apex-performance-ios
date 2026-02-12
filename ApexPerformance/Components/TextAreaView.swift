//
//  TextAreaView.swift
//  ApexPerformance
//
//  Created by Milan Trbojevic on 09.01.2026..
//

import SwiftUI

struct TextAreaView: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .padding(.top, 14)
                    .padding(.leading, 16)
            }
            
            TextEditor(text: $text)
                .focused($isFocused)
                .padding(14)
                .frame(minHeight: 110)
        }
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isFocused ? Color.accentColor :
                        Color.secondary.opacity(0.35),
                    lineWidth: 1
                )
        }
    }
}

struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content
    
    init(_ initialValue: Value, content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initialValue)
        self.content = content
    }
    
    var body: some View {
        content($value)
    }
}

#Preview("Empty") {
    StatefulPreviewWrapper("") { text in
        TextAreaView(
            placeholder: "cancelation_comment_placeholder",
            text: text
        )
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("With text") {
    StatefulPreviewWrapper("Client asked to reschedule due to illness.") { text in
        TextAreaView(
            placeholder: "cancelation_comment_placeholder",
            text: text
        )
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
