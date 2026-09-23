import Foundation

enum ForumFeedText {
    static func time(_ timestamp: UInt32?, now: Date = .now) -> String? {
        guard let timestamp, timestamp > 0 else { return nil }
        let elapsed = max(0, now.timeIntervalSince1970 - Double(timestamp))
        if elapsed < 60 { return "刚刚" }
        if elapsed < 3_600 { return "\(Int(elapsed / 60)) 分钟前" }
        if elapsed < 86_400 { return "\(Int(elapsed / 3_600)) 小时前" }
        return TiebaDateText.date(Date(timeIntervalSince1970: Double(timestamp)), includesTime: false)
    }

    static func count(_ count: Int64?, fallback: String) -> String {
        guard let count, count > 0 else { return fallback }
        if count >= 10_000 { return String(format: "%.1f万", Double(count) / 10_000) }
        return String(count)
    }
}
