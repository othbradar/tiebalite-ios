import Observation

@MainActor @Observable
final class ProfileDetailsStore {
    let user: UserProfileRoute
    private(set) var relationship: ProfileRelationship?
    private(set) var changingFollow = false
    private(set) var relationshipFailed = false
    private(set) var followFailed = false
    var onRelationshipChanged: ((ContentCacheContext) async -> Void)?
    private let repository: any ProfileContentRepository
    private let context: @MainActor () -> ContentCacheContext
    private let accountID: @MainActor () -> Int64?
    private var scope: ContentCacheContext?
    private var task: Task<Void, Never>?
    private var followTask: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var lists: [ProfileSection: ProfileListStore] = [:]
    init(user: UserProfileRoute, repository: any ProfileContentRepository,
         context: @escaping @MainActor () -> ContentCacheContext, accountID: @escaping @MainActor () -> Int64?) {
        self.user = user; self.repository = repository; self.context = context; self.accountID = accountID
    }
    var isSelf: Bool { accountID() == user.userID.rawValue }
    var activationScope: ContentCacheContext { context() }
    var canFollow: Bool {
        !isSelf && scope?.namespace != nil && scope?.namespace != "anonymous"
            && relationship?.isFollowed != nil && relationship?.portrait != nil
    }
    func list(_ section: ProfileSection) -> ProfileListStore {
        if let store = lists[section] { return store }
        let store = ProfileListStore(route: .init(user: user, section: section), repository: repository, context: context)
        lists[section] = store
        return store
    }
    func activate() async {
        let scope = context()
        if self.scope != scope {
            cancel(); self.scope = scope; relationship = nil
            for store in lists.values { store.reset() }
        }
        if let task { await task.value; return }
        guard relationship == nil else { return }
        generation &+= 1
        let token = generation
        let operation = Task { @MainActor [weak self, repository, user] in
            do {
                let value = try await repository.relationship(user, scope: scope)
                guard let self, self.generation == token, self.context() == scope, !Task.isCancelled else { return }
                self.relationship = value; self.relationshipFailed = false
            } catch is CancellationError {
                if self?.generation == token { self?.task = nil }
                return
            } catch {
                guard let self, self.generation == token, self.context() == scope else { return }
                self.relationshipFailed = true
            }
            if self?.generation == token { self?.task = nil }
        }
        task = operation; await operation.value
    }
    func toggleFollowing() async {
        guard !changingFollow, canFollow, let prior = relationship, let followed = prior.isFollowed,
              let portrait = prior.portrait, let scope, context() == scope else { return }
        changingFollow = true; followFailed = false
        let token = generation
        relationship = .init(userID: prior.userID, portrait: portrait, isFollowed: !followed)
        let operation = Task { @MainActor [weak self, repository, user] in
            guard let self else { return }
            do {
                try await repository.setFollowing(!followed, user: user, portrait: portrait, scope: scope)
                guard self.generation == token, self.context() == scope, !Task.isCancelled else { return }
                await self.onRelationshipChanged?(scope)
            } catch {
                guard self.generation == token, self.context() == scope else { return }
                self.relationship = prior; self.followFailed = !(error is CancellationError)
            }
            if self.generation == token { self.changingFollow = false; self.followTask = nil }
        }
        followTask = operation; await operation.value
    }
    func cancel() {
        if changingFollow { relationship = nil }
        task?.cancel(); task = nil; followTask?.cancel(); followTask = nil; generation &+= 1; changingFollow = false
        for store in lists.values { store.cancel() }
    }
    func invalidateRelationship() {
        cancel(); relationship = nil; relationshipFailed = false
    }
}
