import Foundation

/// App dates remain Chinese even when the device uses another language.
enum TiebaDateText {
    /// Compact reading-row date; keep the original display text when cached data has no timestamp.
    static func monthDay(seconds: UInt32?, fallback: String, timeZone: TimeZone = .current) -> String {
        guard let seconds, seconds > 0 else { return fallback }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = Date(timeIntervalSince1970: TimeInterval(seconds))
        return String(format: "%02d-%02d", calendar.component(.month, from: date), calendar.component(.day, from: date))
    }

    static func date(_ date: Date, includesTime: Bool = true, timeZone: TimeZone = .current) -> String {
        date.formatted(Date.FormatStyle(
            date: .abbreviated,
            time: includesTime ? .shortened : .omitted,
            locale: Locale(identifier: "zh_CN"),
            calendar: Calendar(identifier: .gregorian),
            timeZone: timeZone
        ))
    }
}
