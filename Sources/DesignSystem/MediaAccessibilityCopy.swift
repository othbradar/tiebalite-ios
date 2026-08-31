import Foundation

enum MediaAccessibilityCopy {
    static func imageLabel(
        alternativeText: String,
        position: Int,
        total: Int
    ) -> String {
        let trimmed = alternativeText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let base = trimmed.isEmpty ? "图片" : trimmed
        guard position > 0, total > 0, position <= total else {
            return base
        }
        return "\(base)，第 \(position) 张，共 \(total) 张"
    }
}
