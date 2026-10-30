//
//  ShowMoreForEach.swift
//  ApexPerformance
//

import SwiftUI

/// Long lists show their first items and a "Show more" button that adds
/// the next ones, instead of all of them at once.
enum ShowMore {
    static let pageSize = 10
}

/// ForEach over the first `pageSize` items, with "Show more (n)" below
/// while there are more.
struct ShowMoreForEach<Item: Identifiable, Content: View>: View {
    let items: [Item]
    var pageSize = ShowMore.pageSize
    @ViewBuilder let content: (Item) -> Content

    @State private var limit = ShowMore.pageSize

    var body: some View {
        ForEach(items.prefix(limit)) { item in
            content(item)
        }
        if items.count > limit {
            ShowMoreButton(remaining: items.count - limit) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    limit += pageSize
                }
            }
        }
    }
}

struct ShowMoreButton: View {
    let remaining: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("show_more \(remaining)")
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.apexMainColor)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("show-more")
    }
}
