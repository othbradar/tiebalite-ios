import SwiftUI
import UIKit

/// Android UI c5f1125: Avatars, Headers, HomePage, Util/ColorUtils.
enum TiebaParityTokens {
    static let userAvatarSize: CGFloat = 36
    static let forumAvatarSize: CGFloat = 40
    static let horizontalInset: CGFloat = 16
    static let imageGap: CGFloat = 4
    static let contentActionIconFont = Font.system(size: 18)
    static let neutralFill = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.16, alpha: 1)
            : UIColor(white: 0.95, alpha: 1)
    })
    static let divider = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.20, alpha: 1)
            : UIColor(white: 0.95, alpha: 1)
    })

    static func userLevelColor(_ level: Int) -> Color {
        let rgb: UInt32
        switch level {
        case 1...3: rgb = 0x2FBEAB
        case 4...9: rgb = 0x3AA7E9
        case 10...15: rgb = 0xFFA126
        case 16...18: rgb = 0xFF9C19
        default: rgb = 0xB7BCB6
        }
        let original = UIColor(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        original.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        return Color(uiColor: UIColor(
            hue: hue,
            saturation: max(0, saturation - 0.2),
            brightness: max(0, brightness - 0.2 / 3),
            alpha: 1
        ))
    }
}
