/// PBPage read modes. They do not alter the native writing or upload contract.
enum ThreadReadingOrder: String, Codable, CaseIterable, Sendable {
    case ascending
    case descending
}

struct ThreadReadingQuery: Codable, Hashable, Sendable {
    var onlyAuthor = false
    var order: ThreadReadingOrder = .ascending

    var cacheKey: String { "\(onlyAuthor ? "author" : "all")-\(order.rawValue)" }

    func identity(threadID: Int64) -> ReadingCacheIdentity {
        .init(threadID: threadID, query: cacheKey)
    }
}

@MainActor
protocol ThreadReadingPreferences: AnyObject {
    var resumesThreadReading: Bool { get }
}
