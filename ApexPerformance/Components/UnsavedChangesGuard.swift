//
//  UnsavedChangesGuard.swift
//  ApexPerformance
//

import SwiftUI

extension View {
    /// Asks before a form with unsaved changes is closed. The sheet can't be
    /// swiped down while there are changes; the form's close button sets
    /// `isConfirming` instead of dismissing, and a pushed form gets a back
    /// button that does the same.
    func confirmsDiscardingChanges(
        _ hasChanges: Bool,
        isConfirming: Binding<Bool>,
        replacesBackButton: Bool = false,
        onDiscard: @escaping () -> Void
    ) -> some View {
        modifier(UnsavedChangesGuard(
            hasChanges: hasChanges,
            isConfirming: isConfirming,
            replacesBackButton: replacesBackButton,
            onDiscard: onDiscard
        ))
    }
}

private struct UnsavedChangesGuard: ViewModifier {
    let hasChanges: Bool
    @Binding var isConfirming: Bool
    let replacesBackButton: Bool
    let onDiscard: () -> Void

    func body(content: Content) -> some View {
        content
            .interactiveDismissDisabled(hasChanges)
            .navigationBarBackButtonHidden(replacesBackButton && hasChanges)
            .toolbar {
                if replacesBackButton && hasChanges {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            isConfirming = true
                        } label: {
                            Image(systemName: "chevron.backward")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.apexMainColor)
                        }
                        .accessibilityLabel(Text("back"))
                    }
                }
            }
            .confirmationDialog("discard_changes_question", isPresented: $isConfirming, titleVisibility: .visible) {
                Button("discard_changes", role: .destructive, action: onDiscard)
                Button("keep_editing", role: .cancel) {}
            } message: {
                Text("discard_changes_info")
            }
    }
}
