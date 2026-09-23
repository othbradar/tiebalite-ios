import Foundation

/// App dates remain Chinese even when the device uses another language.
enum TiebaDateText {
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
