import Observation

/// Scene-owned public presentation, shared by Home and My. Credentials remain in the existing session provider.
@MainActor
@Observable
final class CurrentAccountStore {
    private(set) var profile: UserProfile?
    private(set) var isLoading = false
    private(set) var failed = false
    @ObservationIgnored private let repository: any CurrentAccountRepository
    @ObservationIgnored private var context: AuthContext = .anonymous
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var attemptedLoad = false

    init(repository: any CurrentAccountRepository) { self.repository = repository }

    func updateContext(_ value: AuthContext) {
        guard value != context else { return }
        task?.cancel(); task = nil
        generation &+= 1
        context = value
        profile = nil
        isLoading = false
        failed = false
        attemptedLoad = false
    }

    func loadIfNeeded() async {
        guard !attemptedLoad else { return }
        await refresh()
    }

    func refresh() async {
        guard case .active = context, task == nil else { return }
        attemptedLoad = true
        isLoading = true
        failed = false
        generation &+= 1
        let token = generation
        let operation = Task { @MainActor [weak self, repository, context] in
            do {
                let profile = try await repository.loadProfile(context: context)
                try Task.checkCancellation()
                guard let self, self.generation == token else { return }
                self.profile = profile
            } catch is CancellationError {
                guard let self, self.generation == token else { return }
                self.attemptedLoad = false
            } catch {
                guard let self, self.generation == token else { return }
                self.failed = true
            }
            guard let self, self.generation == token else { return }
            self.isLoading = false
            self.task = nil
        }
        task = operation
        await operation.value
    }
}
