import Foundation

enum DeepLinkParser {
    private static let maximumURLLength = 2_048

    static func parse(_ url: URL) -> NavigationCommand? {
        guard url.absoluteString.utf8.count <= maximumURLLength,
              let components = URLComponents(
                  url: url,
                  resolvingAgainstBaseURL: false
              ),
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.fragment == nil,
              let scheme = components.scheme?.lowercased() else {
            return nil
        }

        switch scheme {
        case "com.baidu.tieba":
            return parseOfficialScheme(components)
        case "https":
            return parseWebLink(components)
        default:
            return nil
        }
    }

    private static func parseOfficialScheme(
        _ components: URLComponents
    ) -> NavigationCommand? {
        guard components.host?.lowercased() == "unidispatch" else {
            return nil
        }

        switch components.percentEncodedPath {
        case "/frs":
            return forumCommand(queryName: "kw", components: components)
        case "/pb":
            return threadCommand(queryName: "tid", components: components)
        default:
            return nil
        }
    }

    private static func parseWebLink(
        _ components: URLComponents
    ) -> NavigationCommand? {
        guard components.host?.lowercased() == "tieba.baidu.com" else {
            return nil
        }

        if components.percentEncodedPath == "/f" {
            return forumCommand(queryName: "kw", components: components)
        }

        guard components.query == nil else {
            return nil
        }
        let segments = components.percentEncodedPath
            .split(separator: "/", omittingEmptySubsequences: true)
        guard segments.count == 2,
              segments[0] == "p",
              components.percentEncodedPath == "/p/\(segments[1])",
              let decodedID = String(segments[1]).removingPercentEncoding,
              let rawID = Int64(decodedID),
              let threadID = ThreadID(rawID) else {
            return nil
        }
        return .replaceRootDetail(
            root: .recommendations,
            route: .thread(threadID)
        )
    }

    private static func forumCommand(
        queryName: String,
        components: URLComponents
    ) -> NavigationCommand? {
        guard let value = singleQueryValue(
            named: queryName,
            components: components
        ),
        let forumRoute = ForumRoute(value) else {
            return nil
        }
        return .replaceRootDetail(
            root: .recommendations,
            route: .forum(forumRoute)
        )
    }

    private static func threadCommand(
        queryName: String,
        components: URLComponents
    ) -> NavigationCommand? {
        guard let value = singleQueryValue(
            named: queryName,
            components: components
        ),
        let rawID = Int64(value),
        let threadID = ThreadID(rawID) else {
            return nil
        }
        return .replaceRootDetail(
            root: .recommendations,
            route: .thread(threadID)
        )
    }

    private static func singleQueryValue(
        named name: String,
        components: URLComponents
    ) -> String? {
        guard let queryItems = components.queryItems,
              queryItems.count == 1,
              queryItems[0].name == name,
              let value = queryItems[0].value else {
            return nil
        }
        return value
    }
}
