import Foundation

enum RecommendationFeedText {
    static func relativeTime(_ timestamp: UInt32?, now: Date) -> String? {
        guard let timestamp, timestamp > 0 else { return nil }
        let elapsed = max(0, Int(now.timeIntervalSince1970 - Double(timestamp)))
        switch elapsed {
        case ..<60: return "刚刚"
        case ..<3_600: return "\(elapsed / 60) 分钟前"
        case ..<86_400: return "\(elapsed / 3_600) 小时前"
        case ..<604_800: return "\(elapsed / 86_400) 天前"
        default:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: Date(timeIntervalSince1970: Double(timestamp)))
        }
    }

    static func count(_ value: Int64?, fallback: String) -> String {
        guard let value, value > 0 else { return fallback }
        if value > 9_999 {
            return String(format: "%.1f万", Double(value) / 10_000)
        }
        return String(value)
    }
}
