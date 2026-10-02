import Foundation

/// Non-secret local account slot. Restoring a login reuses it; an explicit new login replaces it.
/// It is never derived from cookies, so updating credential values does not change the stored identifier.
@MainActor
protocol ContentCacheAccountNamespaceStoring {
    func restored() -> String
    func newAccount() -> String
    func revoke()
}

@MainActor
final class LocalContentCacheAccountNamespace: ContentCacheAccountNamespaceStoring {
    private let defaults: UserDefaults?
    private var value: String?
    private let key = "dev.tiebalite.content-cache.account-slot"

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        value = defaults?.string(forKey: key)
    }

    func restored() -> String {
        if let value { return value }
        return newAccount()
    }

    func newAccount() -> String {
        let identifier = UUID().uuidString
        value = identifier
        defaults?.set(identifier, forKey: key)
        return identifier
    }

    func revoke() {
        value = nil
        defaults?.removeObject(forKey: key)
    }
}
