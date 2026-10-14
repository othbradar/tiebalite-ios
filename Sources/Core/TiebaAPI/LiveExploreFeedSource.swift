import Foundation
#if DEBUG
import OSLog
#endif

protocol ExplorePageLoading: Sendable {
    func load(_ feed: ExploreFeed, cursor: ExploreCursor?) async throws -> ExplorePage
}

struct LiveExploreFeedSource: ExplorePageLoading {
    let client: any HTTPClient
    let auth: any AuthContextProviding
    let prepare: @Sendable (ExploreFeed, ExploreCursor?, AuthContext) async throws -> HTTPRequest

    func load(_ feed: ExploreFeed, cursor: ExploreCursor?) async throws -> ExplorePage {
        let context = await auth.context()
        if feed == .following, case .anonymous = context { throw ExploreFailure.loginRequired }
        let request = try await prepare(feed, cursor, context)
        try await validate(context)
#if DEBUG
        let logger = Logger(subsystem: "dev.local.tiebaliteios", category: "explore-read")
        logger.info("native feed=\(feed.rawValue, privacy: .public) request=start")
#endif
        do {
            let response = try await client.execute(request)
            try await validate(context)
            guard (200..<300).contains(response.statusCode) else { throw HTTPClientError.server(statusCode: response.statusCode) }
            let page = try ExploreFeedProtocol.decode(response.body, feed: feed)
#if DEBUG
            logger.info("native feed=\(feed.rawValue, privacy: .public) result=success count=\(page.items.count) more=\(page.next != nil)")
#endif
            return page
        } catch {
#if DEBUG
            // Counts and typed errors only: no body, headers, account or thread IDs.
            let category = error is CancellationError ? "cancelled" : (error is EndpointWireFailure ? "business" : "transport-or-decode")
            logger.error("native feed=\(feed.rawValue, privacy: .public) failure=\(category, privacy: .public)")
#endif
            throw error
        }
    }

    private func validate(_ context: AuthContext) async throws {
        try Task.checkCancellation()
        guard await auth.context() == context else { throw CancellationError() }
        if case .active = context { _ = try await auth.authorization(for: context) }
    }
}
