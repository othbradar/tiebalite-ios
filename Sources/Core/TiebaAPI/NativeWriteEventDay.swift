import Foundation

enum NativeWriteEventDay {
    /// iOS 22.11.1 creates a fresh NSDateFormatter and sets only YYYYMMdd.
    /// Preserve its week-year spelling and the user's Foundation defaults.
    static func value(at date: Date, using formatter: DateFormatter = DateFormatter()) -> String {
        formatter.dateFormat = "YYYYMMdd"
        return formatter.string(from: date)
    }
}
