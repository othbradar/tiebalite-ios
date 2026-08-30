#if DEBUG
import SwiftUI

enum DebugSearchProbeLaunch {
    static let flag = "--stage16-search-probe"

    static func isRequested(arguments: [String]) -> Bool {
        arguments.contains(flag)
    }
}

struct DebugSearchEndpointResult: Equatable, Sendable {
    let statusCode: Int?
    let mimeType: String?
    let bodySize: Int
    let decoded: Bool
    let resultCount: Int
    let typedError: String

    static let pending = DebugSearchEndpointResult(
        statusCode: nil,
        mimeType: nil,
        bodySize: 0,
        decoded: false,
        resultCount: 0,
        typedError: "pending"
    )

    var sanitizedSummary: String {
        let status = statusCode.map(String.init) ?? "none"
        return "http=\(status) mime=\(mimeType ?? "none") " +
            "bytes=\(bodySize) decoded=\(decoded) " +
            "count=\(resultCount) error=\(typedError)"
    }
}

struct DebugSearchProbeResult: Equatable, Sendable {
    let forum: DebugSearchEndpointResult
    let thread: DebugSearchEndpointResult
    let secondThreadPage: DebugSearchEndpointResult
    let secondPageNewCount: Int

    static let pending = DebugSearchProbeResult(
        forum: .pending,
        thread: .pending,
        secondThreadPage: .pending,
        secondPageNewCount: 0
    )
}

private enum DebugSearchEndpoint: Hashable, Sendable {
    case forum
    case thread(page: Int)
}

private struct DebugSearchCapturedResponse: Sendable {
    let statusCode: Int
    let mimeType: String?
    let bodySize: Int
    let inspection: SearchWireInspection
}

private actor DebugSearchCapturingHTTPClient: HTTPClient {
    private let base: any HTTPClient
    private var responses: [DebugSearchEndpoint: DebugSearchCapturedResponse] = [:]

    init(base: any HTTPClient) {
        self.base = base
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        let response = try await base.execute(request)
        guard let endpoint = Self.endpoint(for: request.url) else {
            return response
        }
        let inspection: SearchWireInspection
        switch endpoint {
        case .forum:
            inspection = SearchWebProtocol.inspectForumForDiagnostics(
                response.body
            )
        case .thread:
            inspection = SearchWebProtocol.inspectThreadForDiagnostics(
                response.body
            )
        }
        responses[endpoint] = DebugSearchCapturedResponse(
            statusCode: response.statusCode,
            mimeType: Self.mimeType(from: response.headers),
            bodySize: response.body.count,
            inspection: inspection
        )
        return response
    }

    func response(
        for endpoint: DebugSearchEndpoint
    ) -> DebugSearchCapturedResponse? {
        responses[endpoint]
    }

    private static func endpoint(for url: URL) -> DebugSearchEndpoint? {
        switch url.path {
        case "/mo/q/search/forum":
            return .forum
        case "/mo/q/search/thread":
            let page = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )?.queryItems?.first(where: { $0.name == "pn" })?.value
                .flatMap(Int.init) ?? 0
            return .thread(page: page)
        default:
            return nil
        }
    }

    private static func mimeType(from headers: [String: String]) -> String? {
        headers.first { key, _ in
            key.caseInsensitiveCompare("content-type") == .orderedSame
        }?.value.split(separator: ";", maxSplits: 1).first.map(String.init)
    }
}

struct DebugSearchProbe: Sendable {
    let client: any HTTPClient

    func run() async -> DebugSearchProbeResult {
        guard let keyword = SearchKeyword("minecraft") else {
            let failure = Self.failure(code: "invalid-probe-keyword")
            return DebugSearchProbeResult(
                forum: failure,
                thread: failure,
                secondThreadPage: failure,
                secondPageNewCount: 0
            )
        }
        let capturingClient = DebugSearchCapturingHTTPClient(base: client)
        let repository = LiveSearchRepository(client: capturingClient)
        do {
            let snapshot = try await repository.search(keyword: keyword)
            let forum = await Self.result(
                captured: capturingClient.response(for: .forum),
                mappedCount: snapshot.forums.count
            )
            let thread = await Self.result(
                captured: capturingClient.response(for: .thread(page: 1)),
                mappedCount: snapshot.threads.count
            )
            guard snapshot.hasMoreThreads,
                  let request = SearchThreadPageRequest(
                    keyword: keyword,
                    page: 2
                  ) else {
                return DebugSearchProbeResult(
                    forum: forum,
                    thread: thread,
                    secondThreadPage: Self.failure(code: "not-requested"),
                    secondPageNewCount: 0
                )
            }
            let page = try await repository.loadThreadPage(request)
            let firstIDs = Set(snapshot.threads.map(\.threadID))
            let newCount = page.items.filter {
                !firstIDs.contains($0.threadID)
            }.count
            let secondPage = await Self.result(
                captured: capturingClient.response(for: .thread(page: 2)),
                mappedCount: page.items.count
            )
            return DebugSearchProbeResult(
                forum: forum,
                thread: thread,
                secondThreadPage: secondPage,
                secondPageNewCount: newCount
            )
        } catch {
            let code = debugSearchErrorCode(error)
            return DebugSearchProbeResult(
                forum: await Self.result(
                    captured: capturingClient.response(for: .forum),
                    errorCode: code
                ),
                thread: await Self.result(
                    captured: capturingClient.response(
                        for: .thread(page: 1)
                    ),
                    errorCode: code
                ),
                secondThreadPage: await Self.result(
                    captured: capturingClient.response(
                        for: .thread(page: 2)
                    ),
                    errorCode: code
                ),
                secondPageNewCount: 0
            )
        }
    }

    private static func result(
        captured: DebugSearchCapturedResponse?,
        mappedCount: Int? = nil,
        errorCode: String = "none"
    ) -> DebugSearchEndpointResult {
        guard let captured else {
            return failure(code: errorCode)
        }
        return DebugSearchEndpointResult(
            statusCode: captured.statusCode,
            mimeType: captured.mimeType,
            bodySize: captured.bodySize,
            decoded: captured.inspection.decoded,
            resultCount: mappedCount ?? captured.inspection.itemCount,
            typedError: errorCode
        )
    }

    private static func failure(code: String) -> DebugSearchEndpointResult {
        DebugSearchEndpointResult(
            statusCode: nil,
            mimeType: nil,
            bodySize: 0,
            decoded: false,
            resultCount: 0,
            typedError: code
        )
    }
}

@MainActor
struct DebugSearchProbeView: View {
    let client: any HTTPClient
    @State private var result = DebugSearchProbeResult.pending

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                Text("Stage 16A Search Probe")
                    .font(Typography.font(.title))
                Text("Forum: \(result.forum.sanitizedSummary)")
                    .accessibilityIdentifier("debug.search-probe.forum")
                Text("Thread 1: \(result.thread.sanitizedSummary)")
                    .accessibilityIdentifier("debug.search-probe.thread-1")
                Text(
                    "Thread 2: \(result.secondThreadPage.sanitizedSummary) " +
                        "new=\(result.secondPageNewCount)"
                )
                .accessibilityIdentifier("debug.search-probe.thread-2")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.large)
        }
        .background(SemanticColor.background)
        .task {
            result = await DebugSearchProbe(client: client).run()
        }
    }
}

private func debugSearchErrorCode(_ error: any Error) -> String {
    if error is CancellationError {
        return "cancelled"
    }
    if let error = error as? EndpointExecutionError {
        switch error {
        case .authentication:
            return "authentication"
        case .decode:
            return "decode"
        case let .http(statusCode):
            return "http-\(statusCode)"
        case .mapping:
            return "mapping"
        case let .responseTooLarge(limit):
            return "response-too-large-\(limit)"
        case let .server(code):
            return "server-\(code)"
        case .transport:
            return "transport"
        case .unsupportedContent:
            return "unsupported-content"
        }
    }
    return "request"
}
#endif
