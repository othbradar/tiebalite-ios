#if DEBUG && !UITESTING
import Foundation
import SwiftUI

enum DebugStage15ThreadProbeLaunch {
    static let flag = "--stage15-thread-probe"

    static func isRequested(arguments: [String]) -> Bool {
        arguments.filter { $0 == flag }.count == 1
    }
}

enum DebugStage15LongThreadLabLaunch {
    static let flag = "--stage15-long-thread-lab"

    static func isRequested(arguments: [String]) -> Bool {
        arguments.filter { $0 == flag }.count == 1
    }
}

@MainActor
struct DebugStage15LongThreadLabView: View {
    @State private var store: ThreadReaderStore
    @State private var mediaPresentation: MediaViewerPresentation?

    init() {
        _store = State(
            initialValue: ThreadReaderStore(
                threadID: 990_015,
                repository: Stage15LongThreadFixtureRepository(
                    threadID: 990_015,
                    totalPostCount: 1_000,
                    pageSize: 200
                )
            )
        )
    }

    var body: some View {
        NavigationStack {
            ThreadReaderView(
                store: store,
                imageLoader: FixtureReadingImageLoader(),
                onOpenMedia: openMedia
            )
        }
        .accessibilityIdentifier("thread-reader.debug.long-fixture")
        .fullScreenCover(item: $mediaPresentation) { presentation in
            MediaViewer(
                presentation: presentation,
                imageLoader: FixtureReadingImageLoader(),
                close: {
                    mediaPresentation = nil
                }
            )
        }
    }

    private func openMedia(_ intent: ThreadMediaIntent) {
        mediaPresentation = MediaViewerPresentation(intent: intent)
    }
}

private actor DebugStage15CapturingHTTPClient: HTTPClient {
    private let base: any HTTPClient
    private var responses: [HTTPResponse] = []

    init(base: any HTTPClient) {
        self.base = base
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        let response = try await base.execute(request)
        responses.append(response)
        return response
    }

    func capturedResponses() -> [HTTPResponse] {
        responses
    }
}

@MainActor
struct DebugStage15ThreadProbeView: View {
    @State private var summary = "status=pending"

    var body: some View {
        ZStack {
            SemanticColor.background
            Text(summary)
                .font(Typography.font(.caption))
                .foregroundStyle(SemanticColor.primaryText)
                .padding(Spacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("thread-reader.debug.probe-result")
        }
        .task {
            summary = await DebugStage15ThreadProbe().run()
        }
    }
}

private struct DebugStage15ThreadProbe: Sendable {
    func run() async -> String {
        guard let route = ForumRoute("minecraft") else {
            return failureSummary(
                responses: [],
                typedError: "invalid-static-route"
            )
        }
        let client = DebugStage15CapturingHTTPClient(
            base: URLSessionHTTPClient.production()
        )
        do {
            let forum = try await LiveForumHomeRepository(client: client)
                .loadForumHome(route: route)
            let candidates = forum.threads.filter { !$0.isPinned }
            guard let thread = candidates.filter({
                $0.replyCount > 60
            }).max(by: {
                $0.replyCount < $1.replyCount
            }) ?? candidates.filter({
                $0.replyCount > 30
            }).max(by: {
                $0.replyCount < $1.replyCount
            }) else {
                return failureSummary(
                    responses: await client.capturedResponses(),
                    typedError: "empty-frs"
                )
            }

            let pages = try await loadThreePages(
                client: client,
                threadID: thread.threadID
            )
            return successSummary(
                responses: await client.capturedResponses(),
                pages: pages,
                outcome: "success"
            )
        } catch is CancellationError {
            return failureSummary(
                responses: await client.capturedResponses(),
                typedError: "cancelled"
            )
        } catch let error as DebugStage15ThreadProbeError {
            return failureSummary(
                responses: await client.capturedResponses(),
                typedError: error.diagnostic
            )
        } catch is PBPageProtocolError {
            return failureSummary(
                responses: await client.capturedResponses(),
                typedError: "pb-mapping"
            )
        } catch is FRSPageProtocolError {
            return failureSummary(
                responses: await client.capturedResponses(),
                typedError: "frs-mapping"
            )
        } catch let error as EndpointExecutionError {
            let responses = await client.capturedResponses()
            let stage = responses.count > 1 ? "pb" : "frs"
            return failureSummary(
                responses: responses,
                typedError: "\(stage)-\(endpointCategory(error))"
            )
        } catch {
            return failureSummary(
                responses: await client.capturedResponses(),
                typedError: "request"
            )
        }
    }

    private func loadThreePages(
        client: DebugStage15CapturingHTTPClient,
        threadID: Int64
    ) async throws -> [ThreadReaderSnapshot] {
        let repository = LiveThreadReaderRepository(client: client)
        let firstRequest = ThreadReaderPageRequest.initial(
            threadID: threadID
        )
        let first = try await loadPage(
            repository: repository,
            client: client,
            request: firstRequest
        )
        guard first.currentPage == 1 else {
            throw DebugStage15ThreadProbeError.pageMismatch
        }
        var pages = [first]
        var loadedPostIDs = Set(
            first.posts.map(\.document.source.postID)
        )
        while pages.count < 3 {
            guard let current = pages.last,
                  current.hasMore,
                  let cursor = current.nextPostID else {
                throw DebugStage15ThreadProbeError.terminalBeforeThirdPage
            }
            let request = ThreadReaderPageRequest(
                threadID: threadID,
                pageNumber: current.currentPage + 1,
                postID: cursor,
                loadedPostIDs: loadedPostIDs
            )
            let next = try await loadPage(
                repository: repository,
                client: client,
                request: request
            )
            guard next.currentPage == request.pageNumber else {
                throw DebugStage15ThreadProbeError.pageMismatch
            }
            let nextPostIDs = Set(
                next.posts.map(\.document.source.postID)
            )
            guard !nextPostIDs.subtracting(loadedPostIDs).isEmpty else {
                throw DebugStage15ThreadProbeError.noProgress
            }
            pages.append(next)
            loadedPostIDs.formUnion(nextPostIDs)
        }
        return pages
    }

    private func loadPage(
        repository: LiveThreadReaderRepository,
        client: DebugStage15CapturingHTTPClient,
        request: ThreadReaderPageRequest
    ) async throws -> ThreadReaderSnapshot {
        do {
            return try await repository.loadPage(request)
        } catch EndpointExecutionError.mapping {
            guard let response = await client.capturedResponses().last,
                  let wire = try? PBPageProtocol.decode(response.body) else {
                throw EndpointExecutionError.mapping
            }
            do {
                return try PBPageProtocol.map(wire, request: request)
            } catch let error as PBPageProtocolError {
                throw DebugStage15ThreadProbeError.mapping(error)
            }
        }
    }

    private func successSummary(
        responses: [HTTPResponse],
        pages: [ThreadReaderSnapshot],
        outcome: String
    ) -> String {
        let pbResponses = Array(responses.suffix(pages.count))
        let status = pbResponses.map { String($0.statusCode) }.joined(
            separator: ","
        )
        let mime = pbResponses.map { safeMIME($0.headers) }.joined(
            separator: ","
        )
        let bytes = pbResponses.map { String($0.body.count) }.joined(
            separator: ","
        )
        let decoded = pbResponses.allSatisfy {
            (try? PBPageProtocol.decode($0.body)) != nil
        }
        let mappedCounts = pages.map { String($0.posts.count) }.joined(
            separator: ","
        )
        let pageNumbers = pages.map { String($0.currentPage) }.joined(
            separator: ","
        )
        let hasMore = pages.map { $0.hasMore ? "1" : "0" }.joined(
            separator: ","
        )
        let cursorPresent = pages.map {
            ($0.nextPostID ?? 0) > 0 ? "1" : "0"
        }.joined(separator: ",")
        let uniquePostCount = Set(
            pages.flatMap { $0.posts.map(\.document.source.postID) }
        ).count
        return "requests=\(responses.count) status=\(status) " +
            "mime=\(mime) bytes=\(bytes) " +
            "decoded=\(decoded) pages=\(pageNumbers) " +
            "mapped=\(mappedCounts) unique=\(uniquePostCount) " +
            "has-more=\(hasMore) cursor=\(cursorPresent) " +
            "typed-error=none outcome=\(outcome)"
    }

    private func failureSummary(
        responses: [HTTPResponse],
        typedError: String
    ) -> String {
        let response = responses.last
        let decoded: Bool
        if responses.count > 1 {
            decoded = response.flatMap {
                try? PBPageProtocol.decode($0.body)
            } != nil
        } else {
            decoded = response.map {
                FRSPageProtocol.inspectForDiagnostics($0.body).decoded
            } ?? false
        }
        return "requests=\(responses.count) " +
            "status=\(response.map { String($0.statusCode) } ?? "none") " +
            "mime=\(response.map { safeMIME($0.headers) } ?? "unavailable") " +
            "bytes=\(response?.body.count ?? 0) decoded=\(decoded) " +
            "pages=none mapped=0 unique=0 has-more=none cursor=none " +
            "typed-error=\(typedError) outcome=failure"
    }

    private func endpointCategory(_ error: EndpointExecutionError) -> String {
        switch error {
        case .authentication:
            "authentication"
        case .decode:
            "decode"
        case .http:
            "http"
        case .mapping:
            "mapping"
        case .responseTooLarge:
            "response-too-large"
        case .server:
            "server"
        case .transport:
            "transport"
        case .unsupportedContent:
            "mime"
        }
    }

    private func safeMIME(_ headers: [String: String]) -> String {
        headers.first { key, _ in
            key.caseInsensitiveCompare("content-type") == .orderedSame
        }?.value
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "unavailable"
    }
}

private enum DebugStage15ThreadProbeError: Error {
    case terminalBeforeThirdPage
    case mapping(PBPageProtocolError)
    case noProgress
    case pageMismatch

    var diagnostic: String {
        switch self {
        case .terminalBeforeThirdPage:
            "terminal-before-page3"
        case let .mapping(error):
            "pb-\(Self.mappingCategory(error))"
        case .noProgress:
            "pb-no-progress"
        case .pageMismatch:
            "pb-page-mismatch"
        }
    }

    private static func mappingCategory(
        _ error: PBPageProtocolError
    ) -> String {
        switch error {
        case .emptyBody:
            "empty"
        case .invalidStaticConfiguration:
            "configuration"
        case .invalidPageNumber:
            "page"
        case .invalidPostID:
            "post-id"
        case .invalidThreadID:
            "thread-id"
        case .missingData:
            "missing-data"
        case .missingFirstPost:
            "missing-first-post"
        case .missingPage:
            "missing-page"
        case .missingThread:
            "missing-thread"
        case .pageIdentityMismatch:
            "page-mismatch"
        case .threadIdentityMismatch:
            "thread-mismatch"
        }
    }
}
#endif
