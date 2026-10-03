import Foundation

struct ReadingPageLocator: Codable, Equatable, Sendable {
    let page: Int
    let postID: Int64
    var responsePage: Int { max(1, page) }
}

struct ReadingCacheIdentity: Codable, Hashable, Sendable {
    let threadID: Int64
    var parentPostID: Int64?
    var query = "all-ascending"

    var key: String { "thread-v1|\(threadID)|\(parentPostID.map(String.init) ?? "thread")|\(query)" }
}

/// Only written by an actually displayed reader, never by fetching or prefetching a page.
struct ReadingPosition: Codable, Equatable, Sendable {
    let identity: ReadingCacheIdentity
    let postID: Int64
    let locator: ReadingPageLocator
}

struct ReadingCacheTicket: Equatable, Sendable {
    let context: ContentCacheContext
    let epoch: UInt64
}

struct CachedReadingPage<Page: Codable & Sendable>: Codable, Sendable {
    let locator: ReadingPageLocator
    let fetchedAt: Date
    let value: Page
}

struct CachedReading<Page: Codable & Sendable>: Sendable {
    let pages: [CachedReadingPage<Page>]
    let position: ReadingPosition?
    let ticket: ReadingCacheTicket
    let isFresh: Bool
}

protocol ReadingContentCacheAccess: ThreadReaderRepository, SubpostsRepository {
    @MainActor var cacheContext: ContentCacheContext { get }
    func ticket() async -> ReadingCacheTicket
    func isValid(_ ticket: ReadingCacheTicket) async -> Bool
    func restoreThread(_ threadID: Int64) async -> CachedReading<ThreadReaderSnapshot>?
    func restoreSubposts(_ route: SubpostsRoute) async -> CachedReading<SubpostsPage>?
    func refreshThread(_ request: ThreadReaderPageRequest) async throws -> ThreadReaderSnapshot
    func refreshSubposts(_ route: SubpostsRoute, page: Int) async throws -> SubpostsPage
    func checkpoint(_ position: ReadingPosition, ticket: ReadingCacheTicket) async
}

extension EndpointExecutionError {
    /// Only explicit HTTP/auth evidence revokes cached authorization. Unknown wire codes remain retryable.
    var invalidatesReadingCache: Bool {
        switch self {
        case .authentication, .http(401), .http(403), .http(404), .http(410): true
        default: false
        }
    }
}

struct ReadingContentRevoked: Error, Sendable {
    static func isConfirmed(_ error: any Error) -> Bool {
        error is ReadingContentRevoked || (error as? EndpointExecutionError)?.invalidatesReadingCache == true
    }
}

extension ThreadReaderSnapshot {
    var hasRevokedFirstPost: Bool {
        posts.contains { post in
            guard post.floorNumber == 1 else { return false }
            switch post.document.availability {
            case .unavailable(.blocked), .unavailable(.deletedFirstPost): return true
            default: return false
            }
        }
    }
}
