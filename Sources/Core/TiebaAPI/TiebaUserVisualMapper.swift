import Foundation
import GeneratedProtobuf

enum TiebaUserVisualMapper {
    static func map(_ user: Tieba_User) -> TiebaUserVisuals {
        let shownName = user.nameShow.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = user.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return TiebaUserVisuals(
            rawUserID: max(0, user.id),
            displayName: shownName.isEmpty ? (name.isEmpty ? "未知作者" : name) : shownName,
            portrait: user.portrait.isEmpty ? nil : user.portrait,
            levelID: user.levelID > 0 ? Int(user.levelID) : nil,
            isBawu: user.isBawu == 1,
            bawuType: user.bawuType.isEmpty ? nil : user.bawuType,
            ipLocation: user.ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
