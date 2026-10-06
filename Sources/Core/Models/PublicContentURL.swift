import Foundation

/// Public web links only. Never reuse authenticated API requests as share payloads.
enum PublicContentURL {
    static func thread(_ id: Int64) -> URL? {
        guard id > 0 else { return nil }
        return URL(string: "https://tieba.baidu.com/p/\(id)")
    }

    static func forum(_ name: String) -> URL? {
        guard let name = ForumName(name) else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "tieba.baidu.com"
        components.path = "/f"
        components.queryItems = [URLQueryItem(name: "kw", value: name.rawValue)]
        return components.url
    }
}
