/// PBPage read modes. They do not alter the native writing or upload contract.
enum ThreadReadingOrder: String, Codable, CaseIterable, Sendable {
    case hot
    case ascending
    case descending

    var requestValue: Int32 {
        switch self {
        case .ascending: 0
        case .descending: 1
        case .hot: 2
        }
    }

    var title: String {
        switch self {
        case .hot: "热门"
        case .ascending: "正序"
        case .descending: "倒序"
        }
    }
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

/// Shared application preference; explicit post-ID navigation may temporarily override it.
@MainActor
protocol ThreadReplyPreferences: AnyObject, Sendable {
    var replyQuery: ThreadReadingQuery { get }
    func setReplyQuery(_ query: ThreadReadingQuery)
}
