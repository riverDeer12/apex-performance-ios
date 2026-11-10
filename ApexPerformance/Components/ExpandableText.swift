//
//  ExpandableText.swift
//  ApexPerformance
//

import SwiftUI

/// Long free text (a goal, a review, a note) shown on a few lines with
/// "Show more" under it, only when the text doesn't fit; "Show less"
/// folds it again.
struct ExpandableText: View {
    let text: String
    var lineLimit = 3
    var font: Font = .subheadline

    @State private var isExpanded = false
    @State private var isTruncated = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TruncationAwareText(
                text: Text(verbatim: text).font(font),
                lineLimit: lineLimit,
                isExpanded: isExpanded,
                isTruncated: $isTruncated
            )

            if isTruncated {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    ShowMoreLabel(isExpanded: isExpanded)
                }
                .buttonStyle(.apexPlain)
                .accessibilityIdentifier("expandable-text-toggle")
            }
        }
    }
}

/// "Show more" / "Show less" link text.
struct ShowMoreLabel: View {
    var isExpanded = false

    var body: some View {
        Text(isExpanded ? LocalizedStringKey("show_less") : LocalizedStringKey("show_more"))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.apexMainColor)
            .frame(minHeight: 28)
            .contentShape(Rectangle())
    }
}

/// Text on at most lineLimit lines (all of it when expanded) that tells
/// whether those lines cut it.
struct TruncationAwareText: View {
    let text: Text
    let lineLimit: Int
    var isExpanded = false
    @Binding var isTruncated: Bool

    // Heights of the text on lineLimit lines and of the whole text.
    @State private var limitedHeight: CGFloat = 0
    @State private var fullHeight: CGFloat = 0

    var body: some View {
        text
            .lineLimit(isExpanded ? nil : lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Both heights measured hidden, at the width the text has.
            .background(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    measured(lineLimit: lineLimit) { limitedHeight = $0 }
                    measured(lineLimit: nil) { fullHeight = $0 }
                }
                .hidden()
                .accessibilityHidden(true)
            }
            .onChange(of: fullHeight - limitedHeight, initial: true) { _, difference in
                let truncated = difference > 1
                if truncated != isTruncated {
                    isTruncated = truncated
                }
            }
    }

    private func measured(lineLimit: Int?, onHeight: @escaping (CGFloat) -> Void) -> some View {
        text
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                onHeight(height)
            }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        ExpandableText(text: "Short text.")
        ExpandableText(text: String(repeating: "A long goal written by the coach, with details. ", count: 8))
    }
    .padding(20)
}
