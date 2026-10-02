import Foundation

/// Ordinary local preferences; independent of content/image caches and authentication.
struct ForumSortPreferences: Codable, Equatable, Sendable {
    var defaultOrder: ForumSortOrder = .lastReply
    private var ordersByID: [String: ForumSortOrder] = [:]
    private var ordersByName: [String: ForumSortOrder] = [:]
    private var aliases: [String: Int64] = [:]
    private var ambiguousNames: Set<String> = []

    static func normalizedName(_ name: String) -> String {
        // Do not strip “吧”, fold diacritics or transliterate different names.
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping.lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    func identity(for route: ForumRoute) -> ForumQueryIdentity.Forum {
        if let id = route.forumID?.rawValue { return .id(id) }
        let name = Self.normalizedName(route.forumName.rawValue)
        if let id = aliases[name], !ambiguousNames.contains(name) { return .id(id) }
        return .name(name)
    }

    func override(for route: ForumRoute) -> ForumSortOrder? {
        switch identity(for: route) {
        case let .id(id):
            if let order = ordersByID[String(id)] { return order }
            let name = Self.normalizedName(route.forumName.rawValue)
            guard aliases[name] == nil, !ambiguousNames.contains(name) else { return nil }
            return ordersByName[name]
        case let .name(name):
            return ordersByName[name]
        }
    }

    func order(for route: ForumRoute) -> ForumSortOrder {
        override(for: route) ?? defaultOrder
    }

    mutating func set(_ order: ForumSortOrder?, for route: ForumRoute) {
        if let id = route.forumID?.rawValue {
            associate(route: route, forumID: id, canonicalName: route.forumName.rawValue)
        }
        switch identity(for: route) {
        case let .id(id): ordersByID[String(id)] = order
        case let .name(name): ordersByName[name] = order
        }
    }

    mutating func associate(route: ForumRoute, forumID: Int64, canonicalName: String) {
        guard forumID > 0, route.forumID == nil || route.forumID?.rawValue == forumID else { return }
        for name in [route.forumName.rawValue, canonicalName].map(Self.normalizedName) {
            guard !ambiguousNames.contains(name) else { continue }
            if let existing = aliases[name], existing != forumID {
                aliases[name] = nil
                ordersByName[name] = nil
                ambiguousNames.insert(name)
                continue
            }
            if let pending = ordersByName.removeValue(forKey: name), ordersByID[String(forumID)] == nil {
                ordersByID[String(forumID)] = pending
            }
            aliases[name] = forumID
        }
    }
}

@MainActor
protocol ForumSortPreferenceProviding: AnyObject {
    var forumSortPreferences: ForumSortPreferences { get }
    func loadIfNeeded() async
    func updateForumSort(_ order: ForumSortOrder?, for route: ForumRoute)
    func associateForumSort(route: ForumRoute, forumID: Int64, canonicalName: String)
}

/// Content identity only. Future personalized caches must additionally include an account/session scope.
struct ForumQueryIdentity: Hashable, Sendable {
    enum Forum: Hashable, Sendable {
        case id(Int64)
        case name(String)
    }

    enum Selection: Hashable, Sendable {
        case latest(ForumSortOrder)
        case good(Int32)
        case category(id: Int32, sort: Int32)
    }

    let forum: Forum
    let selection: Selection

    init(route: ForumRoute, query: ForumThreadQuery, preferences: ForumSortPreferences = .init()) {
        forum = preferences.identity(for: route)
        switch query {
        case let .latest(order): selection = .latest(order)
        case let .good(id): selection = .good(id)
        case let .category(category, sort): selection = .category(id: category.id, sort: sort)
        }
    }
}
