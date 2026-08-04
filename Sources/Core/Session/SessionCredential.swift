import Foundation

struct SessionCredential: Codable, Equatable, Sendable,
    CustomStringConvertible, CustomDebugStringConvertible {
    let bduss: String
    let stoken: String

    init?(bduss: String?, stoken: String?) {
        guard let bduss,
              let stoken,
              Self.isValidCookieValue(bduss),
              Self.isValidCookieValue(stoken) else {
            return nil
        }
        self.bduss = bduss
        self.stoken = stoken
    }

    var description: String {
        "SessionCredential(redacted)"
    }

    var debugDescription: String {
        description
    }

    private static func isValidCookieValue(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && value.utf8.count <= 4_096
            && !value.contains("\r")
            && !value.contains("\n")
    }
}

protocol SessionCredentialStore: Sendable {
    func load() async throws -> SessionCredential?
    func save(_ credential: SessionCredential) async throws
    func delete() async throws
}

struct EmptySessionCredentialStore: SessionCredentialStore {
    func load() async throws -> SessionCredential? {
        nil
    }

    func save(_ credential: SessionCredential) async throws {
        throw SessionCredentialStoreError.unavailable
    }

    func delete() async throws {
    }
}

enum SessionCredentialStoreError: Error, Equatable, Sendable {
    case invalidPayload
    case unavailable
}
