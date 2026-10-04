import Foundation

enum ContentPrefetchMode: String, Codable, CaseIterable, Sendable {
    case off, unmetered, allNetworks
    var title: String {
        switch self {
        case .off: "关闭"
        case .unmetered: "仅非昂贵连接"
        case .allNetworks: "所有网络"
        }
    }
    func permits(connected: Bool, expensive: Bool, constrained: Bool, lowPower: Bool, active: Bool) -> Bool {
        self != .off && connected && !constrained && !lowPower && active && (self == .allNetworks || !expensive)
    }
}

protocol ThreadContentPrefetching: Sendable {
    func prefetchThread(_ request: ThreadReaderPageRequest) async throws
}
protocol ForumContentPrefetching: Sendable {
    func prefetchForum(_ request: ForumHomePageRequest) async throws
}

/// A page-owned, bounded set of candidates. Completion never schedules more candidates.
@MainActor
final class ContentPrefetchScope {
    private let allowed: @MainActor () -> Bool
    private var tasks: [String: Task<Void, Never>] = [:]
    private var candidates: Set<String> = []
    private var generations: [String: UInt64] = [:]
    private var nextGeneration: UInt64 = 0

    init(allowed: @escaping @MainActor () -> Bool) { self.allowed = allowed }

    func submit(_ jobs: [(String, @Sendable () async throws -> Void)]) {
        guard allowed() else { cancel(); return }
        let bounded = Array(jobs.prefix(3)) // Two nearby threads plus, at most, one next page.
        let selected = Set(bounded.map(\.0))
        for key in candidates.subtracting(selected) {
            tasks.removeValue(forKey: key)?.cancel()
            generations[key] = nil
        }
        for (key, operation) in bounded where !candidates.contains(key) {
            nextGeneration &+= 1
            let generation = nextGeneration
            generations[key] = generation
            tasks[key] = Task { [weak self] in
                do { try await operation() } catch {
                    // A later boundary event may retry; completion itself never schedules more work.
                    guard self?.generations[key] == generation else { return }
                    self?.candidates.remove(key)
                    self?.generations[key] = nil
                    self?.tasks[key] = nil
                }
            }
        }
        candidates = selected
    }

    func submitOne(key: String, makeOperation: () -> (@Sendable () async throws -> Void)) {
        guard allowed() else { cancel(); return }
        guard candidates != [key] else { return }
        submit([(key, makeOperation())])
    }

    func cancel() {
        tasks.values.forEach { $0.cancel() }
        tasks = [:]
        candidates = []
        generations = [:]
    }

    deinit { tasks.values.forEach { $0.cancel() } }
}
