import SwiftUI

/// Shared geometry for the home search entry and the editable search field.
struct TiebaSearchBoxSurface<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .foregroundStyle(SemanticColor.secondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
    }
}
