import Observation

@MainActor @Observable
final class LocalBlockingStore {
    private(set) var entries: [BlockedProfile] = []
    private(set) var error = false
    private(set) var revision: UInt64 = 0
    var didChange: ((Set<Int64>) -> Void)?
    private let repository: LocalBlockingRepository
    private let context: @MainActor () -> ContentCacheContext
    private var scope: ContentCacheContext?
    private var generation: UInt64 = 0
    private var writing = false
    init(repository: LocalBlockingRepository, context: @escaping @MainActor () -> ContentCacheContext) {
        self.repository = repository; self.context = context
    }
    var ids: Set<Int64> { Set(entries.map(\.id)) }
    func activate() async {
        let scope = context()
        guard self.scope != scope else { return }
        self.scope = scope; generation &+= 1; entries = []; error = false
        publish()
        let token = generation
        do {
            let values = try await repository.load(namespace: scope.namespace ?? "anonymous")
            guard generation == token, context() == scope else { return }
            entries = values; publish()
        } catch { if generation == token { self.error = true } }
    }
    func set(_ entry: BlockedProfile, blocked: Bool) async {
        await activate()
        guard !writing, let scope, context() == scope else { return }
        writing = true
        let token = generation
        do {
            let values = try await repository.set(entry, blocked: blocked, namespace: scope.namespace ?? "anonymous")
            guard generation == token, context() == scope else { writing = false; return }
            entries = values; error = false; publish()
        } catch { if generation == token { self.error = true } }
        writing = false
    }
    private func publish() { revision &+= 1; didChange?(ids) }
}
