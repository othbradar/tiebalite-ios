import Foundation

/// ADR-0024: the only HTTP image source approved for Android avatar parity.
enum LegacyPortraitURL {
    private static let host = "tb.himg.baidu.com"
    private static let pathPrefix = "/sys/portrait/item/"

    static func candidate(for portrait: String) -> String? {
        let value = portrait.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if URLComponents(string: value)?.scheme?.lowercased() == "https" { return value }
        let candidate = value.lowercased().hasPrefix("http://")
            ? value : "http://\(host)\(pathPrefix)\(value)"
        guard let components = URLComponents(string: candidate), permits(components) else { return nil }
        return candidate
    }

    static func permits(_ components: URLComponents) -> Bool {
        guard components.scheme?.lowercased() == "http",
              components.host?.lowercased() == host,
              components.user == nil, components.password == nil,
              components.port == nil, components.fragment == nil,
              components.percentEncodedPath.hasPrefix(pathPrefix) else { return false }
        let token = components.percentEncodedPath.dropFirst(pathPrefix.count)
        guard !token.isEmpty, token != ".", token != "..", token.utf8.allSatisfy({ byte in
            switch byte {
            case 45, 46, 48...57, 65...90, 95, 97...122: true
            default: false
            }
        }) else { return false }
        guard let query = components.percentEncodedQuery else { return true }
        return query.hasPrefix("t=") && query.count > 2
            && query.dropFirst(2).utf8.allSatisfy { (48...57).contains($0) }
    }
}
