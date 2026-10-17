import Foundation

/// Coalesces metadata reads for visible own-content candidates. No login/write
/// preparation and no persistence of an additional credential or account copy.
@MainActor
final class ContentActionAccountProvider {
    let auth: SessionAuthContextProvider
    let store: CurrentAccountStore
    let profiles: LiveCurrentAccountRepository
    private var scope: AuthContext?
    private var cachedID: Int64?
    private var task: Task<Int64, Error>?
    init(auth: SessionAuthContextProvider, store: CurrentAccountStore, client: any HTTPClient) {
        self.auth = auth; self.store = store
        profiles = LiveCurrentAccountRepository(client: client, authContextProvider: auth)
    }
    func current() async throws -> Int64 {
        let context = auth.context()
        guard case .active = context else { task?.cancel(); task = nil; cachedID = nil; throw ContentActionFailure.loginRequired }
        if scope != context { task?.cancel(); task = nil; cachedID = nil; scope = context }
        store.updateContext(context)
        if let id = store.profile?.userID.rawValue { return id }
        if let cachedID { return cachedID }
        let running: Task<Int64, Error>
        if let task { running = task } else {
            running = Task { [profiles] in try await profiles.loadProfile(context: context).userID.rawValue }
            task = running
        }
        do {
            let id = try await running.value
            guard auth.context() == context, id > 0 else { throw CancellationError() }
            cachedID = id; task = nil
            return id
        } catch {
            if scope == context { task = nil }
            throw error
        }
    }
}
