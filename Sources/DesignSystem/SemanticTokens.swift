import SwiftUI
import UIKit

enum SemanticColorRole: CaseIterable, Sendable {
    case accent
    case background
    case error
    case mediaBackground
    case primaryText
    case secondaryText
    case separator
    case surface
}

enum SemanticColor {
    static let accent = Color(uiColor: .systemBlue)
    static let background = Color(uiColor: .systemBackground)
    static let error = Color(uiColor: .systemRed)
    static let mediaBackground = Color.black
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let separator = Color(uiColor: .separator)
    static let surface = Color(uiColor: .secondarySystemBackground)

    static func resolve(_ role: SemanticColorRole) -> Color {
        switch role {
        case .accent:
            accent
        case .background:
            background
        case .error:
            error
        case .mediaBackground:
            mediaBackground
        case .primaryText:
            primaryText
        case .secondaryText:
            secondaryText
        case .separator:
            separator
        case .surface:
            surface
        }
    }
}

enum TypographyRole: CaseIterable, Sendable {
    case body
    case caption
    case headline
    case largeTitle
    case subheadline
    case title
}

enum Typography {
    static func font(_ role: TypographyRole) -> Font {
        switch role {
        case .largeTitle:
            .largeTitle
        case .title:
            .title2
        case .headline:
            .headline
        case .body:
            .body
        case .subheadline:
            .subheadline
        case .caption:
            .caption
        }
    }

    static func threadContentRole(
        for preference: ReadingTextSizePreference
    ) -> TypographyRole {
        switch preference {
        case .small:
            .subheadline
        case .standard:
            .body
        case .large:
            .title
        }
    }

    static func threadContentFont(
        _ preference: ReadingTextSizePreference
    ) -> Font {
        font(threadContentRole(for: preference))
    }
}

enum Spacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
}

enum CornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 20
}

enum IconSize {
    static let small: CGFloat = 16
    static let medium: CGFloat = 24
    static let large: CGFloat = 40
}
