import Observation

@MainActor
@Observable
final class SessionStore {
    private(set) var state: SessionState
    private(set) var isBusy = false

    private let credentialStore: any SessionCredentialStore
    private let authContextProvider: SessionAuthContextProvider
    private let websiteDataCleaner: any SessionWebsiteDataCleaning
    private let restoresOnLaunch: Bool

    @ObservationIgnored private var hasAttemptedRestore: Bool
    @ObservationIgnored private var operationTask: Task<Void, Never>?
    @ObservationIgnored private var activeGeneration: UInt64?
    @ObservationIgnored private var nextGeneration: UInt64 = 0

    init(
        credentialStore: any SessionCredentialStore,
        authContextProvider: SessionAuthContextProvider,
        websiteDataCleaner: any SessionWebsiteDataCleaning,
        initialState: SessionState = .signedOut,
        restoresOnLaunch: Bool = true
    ) {
        self.credentialStore = credentialStore
        self.authContextProvider = authContextProvider
        self.websiteDataCleaner = websiteDataCleaner
        self.restoresOnLaunch = restoresOnLaunch
        state = initialState
        hasAttemptedRestore = !restoresOnLaunch
    }

    func restoreIfNeeded() async {
        guard restoresOnLaunch,
              !hasAttemptedRestore,
              state == .signedOut else {
            return
        }
        await restore()
    }

    func restore() async {
        hasAttemptedRestore = true
        let generation = beginOperation()
        let credentialStore = credentialStore
        let task = Task { @MainActor [weak self] in
            do {
                let credential = try await credentialStore.load()
                try Task.checkCancellation()
                guard let self,
                      self.activeGeneration == generation else {
                    return
                }
                if let credential {
                    self.authContextProvider.install(credential)
                    self.state = .signedIn
                } else {
                    self.authContextProvider.revoke()
                    self.state = .signedOut
                }
                self.finishOperation(generation: generation)
            } catch is CancellationError {
                self?.finishRestoreCancellation(generation: generation)
            } catch {
                guard let self,
                      self.activeGeneration == generation else {
                    return
                }
                self.authContextProvider.revoke()
                self.state = .failed(.credentialStore)
                self.finishOperation(generation: generation)
            }
        }
        operationTask = task
        await awaitOperation(task)
    }

    func beginSignIn() {
        guard state != .signingOut else {
            return
        }
        hasAttemptedRestore = true
        cancelCurrentOperation()
        state = .signingIn
    }

    func completeLogin(_ cookies: LoginCookieValues) async {
        guard !isBusy,
              state == .signingIn
                || state == .failed(.loginIncomplete) else {
            return
        }
        guard let credential = cookies.credential else {
            cancelCurrentOperation()
            state = .failed(.loginIncomplete)
            return
        }
        let generation = beginOperation()
        state = .signingIn
        let credentialStore = credentialStore
        let task = Task { @MainActor [weak self] in
            do {
                try await credentialStore.save(credential)
                try Task.checkCancellation()
                guard let self,
                      self.activeGeneration == generation else {
                    return
                }
                self.authContextProvider.install(credential)
                self.state = .signedIn
                self.finishOperation(generation: generation)
            } catch is CancellationError {
                self?.finishCancellation(generation: generation)
            } catch {
                guard let self,
                      self.activeGeneration == generation else {
                    return
                }
                self.authContextProvider.revoke()
                self.state = .failed(.credentialStore)
                self.finishOperation(generation: generation)
            }
        }
        operationTask = task
        await awaitOperation(task)
    }

    func cancelSignIn() async {
        let pendingTask = cancelCurrentOperation()
        authContextProvider.revoke()
        state = .signingOut
        isBusy = true
        await pendingTask?.value
        let cleared = await clearPersistedSession()
        state = cleared ? .signedOut : .failed(.logout)
        isBusy = false
    }

    func markExpired(context: AuthContext) async {
        guard authContextProvider.expire(context: context) else {
            return
        }
        let generation = beginOperation()
        state = .expired
        let credentialStore = credentialStore
        let websiteDataCleaner = websiteDataCleaner
        let task = Task { @MainActor [weak self] in
            let cleared = await Self.clearPersistedSession(
                credentialStore: credentialStore,
                websiteDataCleaner: websiteDataCleaner
            )
            guard !Task.isCancelled else {
                self?.finishCancellation(generation: generation)
                return
            }
            guard let self,
                  self.activeGeneration == generation else {
                return
            }
            self.state = cleared ? .expired : .failed(.credentialStore)
            self.finishOperation(generation: generation)
        }
        operationTask = task
        await awaitOperation(task)
    }

    func logout() async {
        let generation = beginOperation()
        authContextProvider.revoke()
        state = .signingOut
        let credentialStore = credentialStore
        let websiteDataCleaner = websiteDataCleaner
        let task = Task { @MainActor [weak self] in
            let cleared = await Self.clearPersistedSession(
                credentialStore: credentialStore,
                websiteDataCleaner: websiteDataCleaner
            )
            guard !Task.isCancelled else {
                self?.finishCancellation(generation: generation)
                return
            }
            guard let self,
                  self.activeGeneration == generation else {
                return
            }
            self.state = cleared ? .signedOut : .failed(.logout)
            self.finishOperation(generation: generation)
        }
        operationTask = task
        await awaitOperation(task)
    }

    private func beginOperation() -> UInt64 {
        operationTask?.cancel()
        nextGeneration &+= 1
        activeGeneration = nextGeneration
        isBusy = true
        return nextGeneration
    }

    @discardableResult
    private func cancelCurrentOperation() -> Task<Void, Never>? {
        let pendingTask = operationTask
        pendingTask?.cancel()
        nextGeneration &+= 1
        activeGeneration = nil
        operationTask = nil
        isBusy = false
        return pendingTask
    }

    private func finishOperation(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        activeGeneration = nil
        operationTask = nil
        isBusy = false
    }

    private func finishCancellation(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        authContextProvider.revoke()
        state = .signedOut
        finishOperation(generation: generation)
    }

    private func finishRestoreCancellation(generation: UInt64) {
        guard activeGeneration == generation else {
            return
        }
        authContextProvider.revoke()
        state = .signedOut
        hasAttemptedRestore = false
        finishOperation(generation: generation)
    }

    private func clearPersistedSession() async -> Bool {
        await Self.clearPersistedSession(
            credentialStore: credentialStore,
            websiteDataCleaner: websiteDataCleaner
        )
    }

    private static func clearPersistedSession(
        credentialStore: any SessionCredentialStore,
        websiteDataCleaner: any SessionWebsiteDataCleaning
    ) async -> Bool {
        let credentialWasDeleted: Bool
        do {
            try await credentialStore.delete()
            credentialWasDeleted = true
        } catch {
            credentialWasDeleted = false
        }
        await websiteDataCleaner.clearSessionWebsiteData()
        return credentialWasDeleted
    }

    private func awaitOperation(_ task: Task<Void, Never>) async {
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
