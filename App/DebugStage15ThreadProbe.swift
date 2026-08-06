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
            guard let thread = forum.threads.first(where: {
                !$0.isPinned && $0.replyCount > 15
            }) ?? forum.threads.first else {
                return failureSummary(
                    responses: await client.capturedResponses(),
                    typedError: "empty-frs"
                )
            }

            let repository = LiveThreadReaderRepository(client: client)
            let first = try await repository.loadPage(
                .initial(threadID: thread.threadID)
            )
            guard first.hasMore else {
                return successSummary(
                    responses: await client.capturedResponses(),
                    first: first,
                    second: nil,
                    outcome: "terminal-first-page"
                )
            }
            let second = try await repository.loadPage(
                ThreadReaderPageRequest(
                    threadID: thread.threadID,
                    pageNumber: first.currentPage + 1,
                    postID: first.nextPostID ?? 0
                )
            )
            return successSummary(
                responses: await client.capturedResponses(),
                first: first,
                second: second,
                outcome: "success"
            )
        } catch is CancellationError {
            return failureSummary(
                responses: await client.capturedResponses(),
                typedError: "cancelled"
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
        } catch is EndpointExecutionError {
            return failureSummary(
                responses: await client.capturedResponses(),
                typedError: "endpoint"
            )
        } catch {
            return failureSummary(
                responses: await client.capturedResponses(),
                typedError: "request"
            )
        }
    }

    private func successSummary(
        responses: [HTTPResponse],
        first: ThreadReaderSnapshot,
        second: ThreadReaderSnapshot?,
        outcome: String
    ) -> String {
        let pbResponses = Array(responses.dropFirst())
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
        let ordinaryCount = first.posts.filter {
            $0.document.source.scope == .post
        }.count
        let subpostCount = first.posts.reduce(0) {
            $0 + $1.subposts.count
        }
        let secondCount = second?.posts.filter {
            $0.document.source.scope == .post
        }.count
        return "status=\(status) mime=\(mime) bytes=\(bytes) " +
            "decoded=\(decoded) title=\(!first.title.isEmpty) " +
            "first-floor=\(first.posts.first?.floorNumber == 1) " +
            "ordinary=\(ordinaryCount) subposts=\(subpostCount) " +
            "has-next=\(first.hasMore) page2-ordinary=\(secondCount ?? 0) " +
            "typed-error=none outcome=\(outcome)"
    }

    private func failureSummary(
        responses: [HTTPResponse],
        typedError: String
    ) -> String {
        let response = responses.last
        let decoded = response.flatMap {
            try? PBPageProtocol.decode($0.body)
        } != nil
        return "status=\(response.map { String($0.statusCode) } ?? "none") " +
            "mime=\(response.map { safeMIME($0.headers) } ?? "unavailable") " +
            "bytes=\(response?.body.count ?? 0) decoded=\(decoded) " +
            "title=false first-floor=false ordinary=0 subposts=0 " +
            "has-next=false page2-ordinary=0 " +
            "typed-error=\(typedError) outcome=failure"
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
#endif
