import Observation

enum ProfileRowID: Hashable, Sendable { case post(Int64), forum(Int64), footer }
struct ProfileListRow: Identifiable, Equatable, Sendable {
    enum Content: Equatable, Sendable { case post(ProfilePost), forum(FollowedForum), footer(PaginationFooterState) }
    let id: ProfileRowID
    let content: Content
}

@MainActor @Observable
final class ProfileListStore {
    enum State {
        case idle, loading, loaded, empty, failed, refreshing, refreshFailure, loadingMore, nextFailure, privateContent, contentUnavailable
    }
    let route: ProfileListRoute
    private(set) var state = State.idle
    private(set) var posts: [ProfilePost] = []
    private(set) var forums: [FollowedForum] = []
    private(set) var next: ProfileCursor?
    private(set) var anchor: ProfileRowID?
    private(set) var rows: [ProfileListRow] = []
    private var blocked = Set<Int64>()
    private let repository: any ProfileContentRepository
    private let context: @MainActor () -> ContentCacheContext
    private var scope: ContentCacheContext?
    private var generation: UInt64 = 0
    private var task: Task<Void, Never>?
    var activationScope: ContentCacheContext { context() }
    init(route: ProfileListRoute, repository: any ProfileContentRepository, context: @escaping @MainActor () -> ContentCacheContext) {
        self.route = route; self.repository = repository; self.context = context
    }
    func activate() async {
        if scope != context() { reset(); scope = context() }
        guard state == .idle else { return }
        await load(restore: true)
    }
    func refresh() async { cancel(); await load() }
    func loadMore() async { guard task == nil, let next else { return }; await load(cursor: next) }
    func setAnchor(_ id: ProfileRowID?) { if let id, id != .footer { anchor = id } }
    func setBlocked(_ ids: Set<Int64>) { blocked = ids; project() }
    func reset() { cancel(); posts = []; forums = []; next = nil; anchor = nil; rows = []; scope = nil; state = .idle }
    func cancel() {
        task?.cancel(); task = nil; generation &+= 1
        if state == .loading || state == .refreshing || state == .loadingMore {
            state = posts.isEmpty && forums.isEmpty ? .idle : .loaded
            project()
        }
    }

    private func load(cursor: ProfileCursor? = nil, restore: Bool = false) async {
        guard task == nil else { return }
        let scope = context()
        self.scope = scope; generation &+= 1
        let token = generation
        state = cursor != nil ? .loadingMore : posts.isEmpty && forums.isEmpty ? .loading : .refreshing
        project()
        let operation = Task { @MainActor [weak self, repository, route] in
            guard let self else { return }
            do {
                if restore, let cached = await repository.cached(route, scope: scope), self.valid(token, scope) {
                    self.apply(cached, append: false)
                }
                let page = try await repository.load(route, cursor: cursor, scope: scope)
                guard self.valid(token, scope) else { return }
                self.apply(page, append: cursor != nil)
            } catch is CancellationError {
                guard self.generation == token else { return }
                self.state = self.posts.isEmpty && self.forums.isEmpty ? .idle : .loaded; self.project()
            } catch {
                guard self.valid(token, scope) else { return }
                let failure = error as? ProfileContentFailure
                if failure == .privateContent || failure == .contentUnavailable {
                    self.posts = []; self.forums = []; self.next = nil; self.anchor = nil
                    self.state = failure == .privateContent ? .privateContent : .contentUnavailable
                    self.project()
                    await repository.invalidate(userID: route.user.userID.rawValue, scope: scope)
                    guard self.valid(token, scope) else { return }
                } else {
                    self.state = cursor != nil ? .nextFailure : self.posts.isEmpty && self.forums.isEmpty ? .failed : .refreshFailure
                    self.project()
                }
            }
            if self.generation == token { self.task = nil }
        }
        task = operation; await operation.value
    }
    private func valid(_ token: UInt64, _ scope: ContentCacheContext) -> Bool {
        generation == token && context() == scope && !Task.isCancelled
    }
    private func apply(_ page: ProfileContentPage, append: Bool) {
        if !append { posts = []; forums = [] }
        var postIDs = Set(posts.map(\.id)), forumIDs = Set(forums.map(\.id))
        posts += page.posts.filter { postIDs.insert($0.id).inserted }
        forums += page.forums.filter { forumIDs.insert($0.id).inserted }
        next = page.next; state = posts.isEmpty && forums.isEmpty ? .empty : .loaded
        project()
    }
    private func project() {
        rows = posts.filter { !blocked.contains($0.summary.author?.rawUserID ?? 0) }.map { .init(id: .post($0.id), content: .post($0)) }
        rows += forums.map { .init(id: .forum($0.id), content: .forum($0)) }
        let footer: PaginationFooterState = state == .loadingMore ? .loading : state == .nextFailure ? .failure : next == nil ? .end : .idle
        if !rows.isEmpty || next != nil { rows.append(.init(id: .footer, content: .footer(footer))) }
    }
}
