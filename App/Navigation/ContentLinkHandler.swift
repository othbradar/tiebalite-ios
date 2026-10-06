import SwiftUI

/// Content navigation stays in the caller's stack, including search sheets and notifications.
/// Unknown web paths use the system browser; non-web schemes are never executed here.
@MainActor
enum ContentLinkHandler {
    @discardableResult
    static func open(
        _ url: URL, openRoute: (RouteIdentity) -> Void, openWeb: (URL) -> Void
    ) -> Bool {
        guard url.baseURL == nil, url.absoluteString.utf8.count <= 2_048,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host?.isEmpty == false, components.user == nil, components.password == nil else { return false }

        // Both public web schemes identify the same native route. Other URL bytes
        // remain subject to the existing strict parser; no guessed query semantics.
        components.scheme = "https"
        if let canonical = components.url,
           case let .replaceRootDetail(_, route) = DeepLinkParser.parse(canonical) {
            openRoute(route)
        } else {
            openWeb(url)
        }
        return true
    }

    static func action(openRoute: @escaping (RouteIdentity) -> Void) -> OpenURLAction {
        OpenURLAction { url in
            var result: OpenURLAction.Result = .discarded
            open(url, openRoute: {
                openRoute($0)
                result = .handled
            }, openWeb: { result = .systemAction($0) })
            return result
        }
    }
}
