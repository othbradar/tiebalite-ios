import Foundation

enum ProfileContentOperation: Sendable {
    case list(ProfileListRoute, ProfileCursor?)
    case relationship(UserProfileRoute)
    case following(Bool, UserProfileRoute, String)
}

actor CachedProfileContentRepository: ProfileContentRepository {
    private let execute: @Sendable (ProfileContentOperation, ContentCacheContext) async throws -> HTTPResponse
    private let cache: ContentPageCache
    private let scheduler: ContentLoadScheduler
    private let context: @MainActor @Sendable () -> ContentCacheContext
    private var revisions: [String: UInt64] = [:]
    private var activeWrites = Set<String>()

    init(cache: ContentPageCache, scheduler: ContentLoadScheduler,
         context: @escaping @MainActor @Sendable () -> ContentCacheContext,
         execute: @escaping @Sendable (ProfileContentOperation, ContentCacheContext) async throws -> HTTPResponse) {
        self.cache = cache; self.scheduler = scheduler; self.context = context; self.execute = execute
    }

    func cached(_ route: ProfileListRoute, scope: ContentCacheContext) async -> ProfileContentPage? {
        guard await context() == scope else { return nil }
        let epoch = await cache.epoch, revision = revisions[identity(route.user.userID.rawValue, scope), default: 0]
        guard let bytes = await cache.read(key: key(route, nil, scope)),
              let record = try? JSONDecoder().decode(ProfilePageRecord.self, from: bytes), record.version == 1,
              Date().timeIntervalSince(record.date) < 7 * 24 * 60 * 60,
              await cache.epoch == epoch, await context() == scope,
              revisions[identity(route.user.userID.rawValue, scope), default: 0] == revision else { return nil }
        return record.page
    }

    func load(_ route: ProfileListRoute, cursor: ProfileCursor?, scope: ContentCacheContext) async throws -> ProfileContentPage {
        guard await context() == scope else { throw CancellationError() }
        let epoch = await cache.epoch, id = identity(route.user.userID.rawValue, scope)
        let revision = revisions[id, default: 0]
        let pageKey = key(route, cursor, scope)
        let flight = "\(pageKey):\(epoch):\(scope.revision):\(revision)"
        let response = try await scheduler.load(key: flight, priority: .foreground) { [execute] in
            try await execute(.list(route, cursor), scope)
        }
        let page = route.section == .forums ? try NativeProfileProtocol.forums(response.body, cursor: cursor)
            : try NativeProfileProtocol.posts(response.body, section: route.section, cursor: cursor)
        try await validate(scope, epoch, id, revision)
        _ = await cache.write(try JSONEncoder().encode(ProfilePageRecord(page)), key: pageKey, epoch: epoch)
        try await validate(scope, epoch, id, revision)
        return page
    }

    func relationship(_ user: UserProfileRoute, scope: ContentCacheContext) async throws -> ProfileRelationship {
        let id = identity(user.userID.rawValue, scope), revision = revisions[identity(user.userID.rawValue, scope), default: 0]
        let response = try await execute(.relationship(user), scope)
        guard await context() == scope, revisions[id, default: 0] == revision else { throw CancellationError() }
        return try NativeProfileProtocol.relationship(response.body, userID: user.userID.rawValue)
    }

    func setFollowing(_ followed: Bool, user: UserProfileRoute, portrait: String, scope: ContentCacheContext) async throws {
        guard scope.namespace != nil, scope.namespace != "anonymous", await context() == scope else {
            throw ProfileContentFailure.loginRequired
        }
        let id = identity(user.userID.rawValue, scope)
        guard activeWrites.insert(id).inserted else { throw ProfileContentFailure.relationshipUnavailable }
        defer { activeWrites.remove(id) }
        let response = try await execute(.following(followed, user, portrait), scope)
        guard await context() == scope else { throw CancellationError() }
        try NativeProfileProtocol.confirm(response.body)
        await invalidate(userID: user.userID.rawValue, scope: scope)
    }

    func invalidate(userID: Int64, scope: ContentCacheContext) async {
        revisions[identity(userID, scope), default: 0] &+= 1
        guard let user = UserProfileRoute(userID: userID, fallbackDisplayName: "") else { return }
        for section in ProfileSection.allCases { await cache.remove(key: key(.init(user: user, section: section), nil, scope)) }
    }

    private func validate(_ scope: ContentCacheContext, _ epoch: UInt64, _ id: String, _ revision: UInt64) async throws {
        try Task.checkCancellation()
        guard await context() == scope, await cache.epoch == epoch,
              revisions[id, default: 0] == revision else {
            throw CancellationError()
        }
    }
    private func identity(_ userID: Int64, _ scope: ContentCacheContext) -> String {
        "\(scope.namespace ?? "unavailable"):\(userID)"
    }
    private func key(_ route: ProfileListRoute, _ cursor: ProfileCursor?, _ scope: ContentCacheContext) -> String {
        "profile-v1:\(identity(route.user.userID.rawValue, scope)):\(route.section.rawValue):"
            + "\(cursor?.page ?? 1):\(cursor?.lastThreadTime ?? 0)"
    }
}

private struct ProfilePageRecord: Codable {
    let version: Int
    let date: Date
    let posts: [Post]
    let forums: [Forum]
    let next: ProfileCursor?
    init(_ page: ProfileContentPage) {
        version = 1; date = Date(); posts = page.posts.map(Post.init); forums = page.forums.map(Forum.init); next = page.next
    }
    var page: ProfileContentPage { .init(posts: posts.map(\.value), forums: forums.map(\.value), next: next) }
    struct Post: Codable {
        let id: Int64
        let postID: Int64?
        let thread: ForumPageDTO.Thread
        init(_ value: ProfilePost) { id = value.id; postID = value.postID; thread = .init(value.summary) }
        var value: ProfilePost { .init(id: id, postID: postID, summary: thread.summary) }
    }
    struct Forum: Codable {
        let id: Int64
        let name: String
        let avatar: String?
        let members: Int
        let threads: Int
        let level: Int?
        let signed: Bool
        init(_ value: FollowedForum) {
            id = value.id; name = value.name; avatar = value.avatarResourceID; members = value.memberCount
            threads = value.threadCount; level = value.levelID; signed = value.isSignedToday
        }
        var value: FollowedForum {
            .init(forumID: id, name: name, avatarResourceID: avatar, hotCount: 0, memberCount: members,
                  threadCount: threads, levelID: level, levelName: nil, isSignedToday: signed)
        }
    }
}
