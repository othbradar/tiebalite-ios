import Foundation

enum RootID: String, CaseIterable, Codable, Hashable, Sendable {
    case recommendations
    case followedForums = "followed-forums"

    var tab: AppTab {
        switch self {
        case .recommendations:
            .recommendations
        case .followedForums:
            .followedForums
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case recommendations
    case followedForums = "followed-forums"
    case settings

    var id: String {
        rawValue
    }

    var rootID: RootID? {
        switch self {
        case .recommendations:
            .recommendations
        case .followedForums:
            .followedForums
        case .settings:
            nil
        }
    }
}

struct ForumName: Codable, Hashable, Sendable {
    static let maximumUTF8Length = 256

    let rawValue: String

    init?(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.utf8.count <= Self.maximumUTF8Length,
              trimmed.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            return nil
        }
        rawValue = trimmed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let validated = Self(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid forum name"
            )
        }
        self = validated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ThreadID: Codable, Hashable, Sendable {
    let rawValue: Int64

    init?(_ value: Int64) {
        guard value > 0 else {
            return nil
        }
        rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int64.self)
        guard let validated = Self(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid thread ID"
            )
        }
        self = validated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct PostID: Codable, Hashable, Sendable {
    let rawValue: Int64

    init?(_ value: Int64) {
        guard value > 0 else {
            return nil
        }
        rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Int64.self)
        guard let validated = Self(value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid post ID"
            )
        }
        self = validated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum RouteIdentity: Codable, Hashable, Sendable {
    case forum(ForumName)
    case subposts(threadID: ThreadID, postID: PostID)
    case thread(ThreadID)
}

enum SettingsRoute: Codable, Hashable, Sendable {
    case componentGallery
}

enum NavigationCommand: Equatable, Sendable {
    case replaceRootDetail(root: RootID, route: RouteIdentity)
}

enum AppShellLayout: Equatable, Sendable {
    case compact
    case regular
}

struct AppNavigationProjection: Equatable, Sendable {
    let activeRoot: RootID?
    let fullPath: [RouteIdentity]
    let detailRoot: RouteIdentity?
    let detailTail: [RouteIdentity]
}

struct AppNavigationState: Equatable, Sendable {
    private(set) var selectedTab: AppTab
    private(set) var routesByRoot: [RootID: [RouteIdentity]]
    private(set) var settingsPath: [SettingsRoute]

    init(
        selectedTab: AppTab = .recommendations,
        routesByRoot: [RootID: [RouteIdentity]] = [:],
        settingsPath: [SettingsRoute] = []
    ) {
        self.selectedTab = selectedTab
        self.settingsPath = Array(settingsPath.prefix(1))
        self.routesByRoot = Dictionary(
            uniqueKeysWithValues: RootID.allCases.map { root in
                let candidate = routesByRoot[root] ?? []
                let routes = RouteGrammar.isValid(candidate, for: root)
                    ? candidate
                    : []
                return (root, routes)
            }
        )
    }

    func routes(for root: RootID) -> [RouteIdentity] {
        routesByRoot[root] ?? []
    }

    func projection(for layout: AppShellLayout) -> AppNavigationProjection {
        guard let activeRoot = selectedTab.rootID else {
            return AppNavigationProjection(
                activeRoot: nil,
                fullPath: [],
                detailRoot: nil,
                detailTail: []
            )
        }

        let routes = routes(for: activeRoot)
        switch layout {
        case .compact:
            return AppNavigationProjection(
                activeRoot: activeRoot,
                fullPath: routes,
                detailRoot: nil,
                detailTail: []
            )
        case .regular:
            return AppNavigationProjection(
                activeRoot: activeRoot,
                fullPath: routes,
                detailRoot: routes.first,
                detailTail: Array(routes.dropFirst())
            )
        }
    }

    mutating func selectTab(_ tab: AppTab) {
        selectedTab = tab
    }

    mutating func replaceRoutes(
        _ routes: [RouteIdentity],
        for root: RootID
    ) {
        routesByRoot[root] = routes
    }

    mutating func replaceSettingsPath(_ path: [SettingsRoute]) {
        settingsPath = Array(path.prefix(1))
    }
}

enum RouteGrammar {
    static func isValid(_ routes: [RouteIdentity], for root: RootID) -> Bool {
        guard routes.count <= 3, Set(routes).count == routes.count else {
            return false
        }

        guard !routes.isEmpty else {
            return true
        }

        switch root {
        case .recommendations:
            return isValidRecommendationsChain(routes)
        case .followedForums:
            return isValidFollowedForumsChain(routes)
        }
    }

    private static func isValidRecommendationsChain(
        _ routes: [RouteIdentity]
    ) -> Bool {
        switch routes.count {
        case 1:
            return isForum(routes[0]) || threadID(from: routes[0]) != nil
        case 2:
            if isForum(routes[0]), threadID(from: routes[1]) != nil {
                return true
            }
            return matchingThreadAndSubposts(routes[0], routes[1])
        case 3:
            return isForum(routes[0])
                && matchingThreadAndSubposts(routes[1], routes[2])
        default:
            return false
        }
    }

    private static func isValidFollowedForumsChain(
        _ routes: [RouteIdentity]
    ) -> Bool {
        switch routes.count {
        case 1:
            return isForum(routes[0])
        case 2:
            return isForum(routes[0]) && threadID(from: routes[1]) != nil
        case 3:
            return isForum(routes[0])
                && matchingThreadAndSubposts(routes[1], routes[2])
        default:
            return false
        }
    }

    private static func matchingThreadAndSubposts(
        _ threadRoute: RouteIdentity,
        _ subpostsRoute: RouteIdentity
    ) -> Bool {
        guard let threadID = threadID(from: threadRoute) else {
            return false
        }
        switch subpostsRoute {
        case let .subposts(childThreadID, _):
            return threadID == childThreadID
        case .forum, .thread:
            return false
        }
    }

    private static func isForum(_ route: RouteIdentity) -> Bool {
        if case .forum = route {
            return true
        }
        return false
    }

    private static func threadID(from route: RouteIdentity) -> ThreadID? {
        if case let .thread(threadID) = route {
            return threadID
        }
        return nil
    }
}
