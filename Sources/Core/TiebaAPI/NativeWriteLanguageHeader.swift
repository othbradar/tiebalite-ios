import Foundation

enum NativeWriteLanguageHeader {
    /// AFHTTPRequestSerializer's 22.11.1 language block uses float arithmetic,
    /// %0.1g and includes the entry whose quality reaches 0.5 before stopping.
    static func value(_ preferredLanguages: [String]) -> String {
        preferredLanguages.prefix(6).enumerated().map { index, language in
            let quality: Float = 1 + Float(index) * -0.1
            return String(format: "%@;q=%0.1g", locale: Locale(identifier: "en_US_POSIX"), language, Double(quality))
        }.joined(separator: ", ")
    }
}
