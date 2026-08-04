import Foundation

enum LoginWebNavigationPolicy {
    static var loginURL: URL? {
        guard let completionURL = makeHTTPSURL(
            host: "tieba.baidu.com",
            path: "/index/tbwise/mine"
        ) else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "wappass.baidu.com"
        components.path = "/passport"
        let encodedCompletion = [
            "https%3A%2F%2F",
            completionURL.host ?? "",
            "%2Findex%2Ftbwise%2Fmine"
        ].joined()
        components.percentEncodedQuery = "login&u=\(encodedCompletion)"
        return components.url
    }

    static func allows(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              url.port == nil,
              let host = url.host?.lowercased() else {
            return false
        }
        return host == "baidu.com" || host.hasSuffix(".baidu.com")
    }

    static func isCompletion(_ url: URL) -> Bool {
        guard allows(url),
              let host = url.host?.lowercased(),
              host == "tieba.baidu.com" || host == "tiebac.baidu.com" else {
            return false
        }
        return url.path.hasPrefix("/index/tbwise/")
    }

    private static func makeHTTPSURL(
        host: String,
        path: String
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        return components.url
    }
}
