import SwiftUI

/// Shared geometry for the home search entry and the editable search field.
struct TiebaSearchBoxSurface<Content: View>: View {
    enum Placement {
        case content
        case navigationBar
    }

    var placement: Placement = .content
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .foregroundStyle(SemanticColor.secondaryText)
            .padding(.horizontal, 16)
            // The navigation title slot is 44pt; a 48pt surface overflows its
            // transition bounds by 2pt on each side.
            .padding(.vertical, placement == .navigationBar ? 10 : 12)
            .frame(minHeight: placement == .navigationBar ? 44 : 48)
            .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
    }
}
