import Foundation

/// Only this app's prepared native account metadata. Kept in the existing
/// protected Keychain abstraction, never in content caches or preferences.
actor NativeWriteAccountVault {
    static let shared = NativeWriteAccountVault()

    private struct Record: Codable, Sendable {
        let version: Int
        let namespace: String
        let userID: String
        let tbs: String
        let name: String
        var response: StoredResponse?
    }

    private struct StoredResponse: Codable, Sendable {
        let state: NativeWriteResponseState
        let updatedAt: Date
    }

    private struct VolatileResponse: Sendable {
        let namespace: String
        let userID: String
        let value: StoredResponse?
    }

    private let dataStore: any KeychainDataStoring
    private let key = KeychainItemKey(service: "dev.local.tiebaliteios.native-write", account: "prepared-account-v1")
    private var tail: Task<Void, Never>?
    private var volatileResponse: VolatileResponse?
    private var lastBackgroundCleanup: Date?

    init(dataStore: any KeychainDataStoring = SecurityKeychainDataStore()) { self.dataStore = dataStore }

    func load(namespace: String) async throws -> TextWriteAccount? {
        try await serialized { store, key in
            guard let record = try await Self.record(store, key), record.namespace == namespace else { return nil }
            return TextWriteAccount(userID: record.userID, tbs: record.tbs, nameShow: record.name)
        }
    }

    func save(_ account: TextWriteAccount, namespace: String) async throws {
        guard !namespace.isEmpty, Int64(account.userID).map({ $0 > 0 }) == true else {
            throw RequestAuthorizationError.contextMismatch
        }
        try await serialized { store, key in
            let old = try await Self.record(store, key)
            let retained = if let old, old.namespace == namespace, old.userID == account.userID {
                await self.response(in: old)
            } else { nil as StoredResponse? }
            let value = Record(version: 1, namespace: namespace, userID: account.userID, tbs: account.tbs,
                               name: account.nameShow, response: retained)
            try await store.write(JSONEncoder().encode(value), key: key)
            await self.remember(value)
        }
    }

    func responseState(namespace: String, userID: String) async throws -> NativeWriteResponseState? {
        try await serialized { store, key in
            guard let record = try await Self.record(store, key), record.namespace == namespace,
                  record.userID == userID else { return nil }
            return await self.response(in: record)?.state
        }
    }

    /// Native cache policy 2 publishes memory before attempting durable storage.
    /// The caller must not reinterpret a disk failure as a failed remote write.
    func saveResponseState(_ state: NativeWriteResponseState, namespace: String, userID: String,
                           at date: Date = Date()) async throws {
        try await serialized { store, key in
            guard var record = try await Self.record(store, key), record.namespace == namespace,
                  record.userID == userID else { throw RequestAuthorizationError.contextMismatch }
            record.response = StoredResponse(state: state, updatedAt: date)
            await self.remember(record)
            try await store.write(JSONEncoder().encode(record), key: key)
        }
    }

    /// Event-driven cleanup, never a send timer or a lookup-time TTL. Mirrors
    /// the native fresh-cache default; remote IDPCache config is not fabricated.
    func enteredBackground(at date: Date = Date()) async throws {
        try await serialized { store, key in
            guard await self.beginBackgroundCleanup(at: date), var record = try await Self.record(store, key),
                  let response = await self.response(in: record),
                  date.timeIntervalSince(response.updatedAt) > 3_600 else { return }
            record.response = nil
            await self.remember(record)
            try await store.write(JSONEncoder().encode(record), key: key)
        }
    }

    func delete(namespace: String? = nil) async throws {
        try await serialized { store, key in
            if let namespace, try await Self.record(store, key)?.namespace != namespace { return }
            await self.forgetResponse()
            try await store.delete(key)
        }
    }

    private func response(in record: Record) -> StoredResponse? {
        if let volatileResponse, volatileResponse.namespace == record.namespace,
           volatileResponse.userID == record.userID { return volatileResponse.value }
        return record.response
    }

    private func remember(_ record: Record) {
        volatileResponse = .init(namespace: record.namespace, userID: record.userID, value: record.response)
    }

    private func forgetResponse() { volatileResponse = nil }

    private func beginBackgroundCleanup(at date: Date) -> Bool {
        guard lastBackgroundCleanup.map({ date.timeIntervalSince($0) > 600 }) ?? true else { return false }
        lastBackgroundCleanup = date
        return true
    }

    private static func record(_ store: any KeychainDataStoring, _ key: KeychainItemKey) async throws -> Record? {
        guard let data = try await store.read(key) else { return nil }
        let value = try JSONDecoder().decode(Record.self, from: data)
        guard value.version == 1, Int64(value.userID).map({ $0 > 0 }) == true else {
            throw SessionCredentialStoreError.invalidPayload
        }
        return value
    }

    // A conditional delete must finish its read+delete before a new owner's
    // write starts. Actor reentrancy alone does not make those awaits atomic.
    // Storage operations finish even if their caller is cancelled; send checks
    // its lease/cancellation again before issuing a write request.
    private func serialized<Value: Sendable>(
        _ operation: @escaping @Sendable (any KeychainDataStoring, KeychainItemKey) async throws -> Value
    ) async throws -> Value {
        let previous = tail
        let task = Task { [dataStore, key] in
            await previous?.value
            return try await operation(dataStore, key)
        }
        tail = Task { _ = await task.result }
        return try await task.value
    }
}

/// Explicit login/logout removes only this companion record, without altering
/// credential representation, Keychain access groups, or other user data.
struct NativeWriteCredentialStore: SessionCredentialStore {
    let base: any SessionCredentialStore
    let accounts: NativeWriteAccountVault

    func load() async throws -> SessionCredential? { try await base.load() }
    func save(_ credential: SessionCredential) async throws {
        try await accounts.delete()
        try await base.save(credential)
    }
    func delete() async throws {
        try await base.delete()
        try await accounts.delete()
    }
}
