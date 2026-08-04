import Foundation
import Security

struct KeychainItemKey: Equatable, Hashable, Sendable {
    let service: String
    let account: String
}

protocol KeychainDataStoring: Sendable {
    func read(_ key: KeychainItemKey) async throws -> Data?
    func write(_ data: Data, key: KeychainItemKey) async throws
    func delete(_ key: KeychainItemKey) async throws
}

enum KeychainDataStoreError: Error, Equatable, Sendable {
    case unexpectedStatus(OSStatus)
    case unexpectedValue
}

actor SecurityKeychainDataStore: KeychainDataStoring {
    func read(_ key: KeychainItemKey) throws -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw KeychainDataStoreError.unexpectedValue
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainDataStoreError.unexpectedStatus(status)
        }
    }

    func write(_ data: Data, key: KeychainItemKey) throws {
        let query = baseQuery(for: key)
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            update as CFDictionary
        )
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insertion = query
            insertion[kSecValueData as String] = data
            insertion[kSecAttrAccessible as String] =
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let insertionStatus = SecItemAdd(
                insertion as CFDictionary,
                nil
            )
            guard insertionStatus == errSecSuccess else {
                throw KeychainDataStoreError.unexpectedStatus(
                    insertionStatus
                )
            }
        default:
            throw KeychainDataStoreError.unexpectedStatus(updateStatus)
        }
    }

    func delete(_ key: KeychainItemKey) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainDataStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for key: KeychainItemKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.service,
            kSecAttrAccount as String: key.account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }
}

struct KeychainSessionCredentialStore: SessionCredentialStore {
    static let defaultService = "dev.local.tiebaliteios.session"
    static let defaultAccount = "primary"

    private struct Envelope: Codable {
        let version: Int
        let bduss: String
        let stoken: String
    }

    private let dataStore: any KeychainDataStoring
    private let key: KeychainItemKey

    init(
        dataStore: any KeychainDataStoring = SecurityKeychainDataStore(),
        service: String = defaultService,
        account: String = defaultAccount
    ) {
        self.dataStore = dataStore
        key = KeychainItemKey(service: service, account: account)
    }

    func load() async throws -> SessionCredential? {
        guard let data = try await dataStore.read(key) else {
            return nil
        }
        do {
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            guard envelope.version == 1,
                  let credential = SessionCredential(
                      bduss: envelope.bduss,
                      stoken: envelope.stoken
                  ) else {
                throw SessionCredentialStoreError.invalidPayload
            }
            return credential
        } catch is SessionCredentialStoreError {
            throw SessionCredentialStoreError.invalidPayload
        } catch {
            throw SessionCredentialStoreError.invalidPayload
        }
    }

    func save(_ credential: SessionCredential) async throws {
        let envelope = Envelope(
            version: 1,
            bduss: credential.bduss,
            stoken: credential.stoken
        )
        let data = try JSONEncoder().encode(envelope)
        try await dataStore.write(data, key: key)
    }

    func delete() async throws {
        try await dataStore.delete(key)
    }
}
