import Foundation

struct CacheKey: Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

protocol DataCaching: Sendable {
    func data(for key: CacheKey) async -> Data?
    func store(_ data: Data, for key: CacheKey) async
}

struct NoStoreDataCache: DataCaching {
    func data(for key: CacheKey) async -> Data? {
        _ = key
        return nil
    }

    func store(_ data: Data, for key: CacheKey) async {
        _ = data
        _ = key
    }
}
