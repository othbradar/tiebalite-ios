#if DEBUG && !UITESTING
import Foundation
import SwiftUI

enum DebugLiveAPIProbeLaunch {
    static let flag = "--stage11-live-recommendations-probe"

    static func isRequested(arguments: [String]) -> Bool {
        arguments.filter { $0 == flag }.count == 1
    }
}

private actor DebugLiveProbeCapturingHTTPClient: HTTPClient {
    private let base: any HTTPClient
    private var latestResponse: HTTPResponse?

    init(base: any HTTPClient) {
        self.base = base
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        let response = try await base.execute(request)
        latestResponse = response
        return response
    }

    func capturedResponse() -> HTTPResponse? {
        latestResponse
    }
}

private struct DebugLiveThreadProbe: Sendable {
    let client: any HTTPClient

    func run(threadID: Int64) async -> DebugThreadProbeResult {
        let clock = ContinuousClock()
        let started = clock.now
        let capturingClient = DebugLiveProbeCapturingHTTPClient(base: client)
        do {
            let snapshot = try await LiveThreadReaderRepository(
                client: capturingClient
            ).loadThread(threadID: threadID)
            guard let response = await capturingClient.capturedResponse() else {
                return failure(
                    outcome: .transport,
                    response: nil,
                    started: started,
                    clock: clock
                )
            }
            return makeResult(
                response: response,
                snapshot: snapshot,
                outcome: .success,
                started: started,
                clock: clock
            )
        } catch is CancellationError {
            return failure(
                outcome: .cancelled,
                response: await capturingClient.capturedResponse(),
                started: started,
                clock: clock
            )
        } catch let error as EndpointExecutionError {
            return failure(
                outcome: debugOutcome(for: error),
                response: await capturingClient.capturedResponse(),
                started: started,
                clock: clock
            )
        } catch {
            return failure(
                outcome: .request,
                response: await capturingClient.capturedResponse(),
                started: started,
                clock: clock
            )
        }
    }

    private func makeResult(
        response: HTTPResponse,
        snapshot: ThreadReaderSnapshot?,
        outcome: DebugLiveProbeOutcome,
        started: ContinuousClock.Instant,
        clock: ContinuousClock
    ) -> DebugThreadProbeResult {
        let mimeType = debugSafeMIMEType(response.headers)
        let decoded: Bool
        do {
            _ = try PBPageProtocol.decode(response.body)
            decoded = true
        } catch {
            decoded = false
        }
        return DebugThreadProbeResult(
            statusCode: response.statusCode,
            mimeType: mimeType,
            bodyByteCount: response.body.count,
            decoded: decoded,
            titlePresent: snapshot?.title.isEmpty == false,
            forumPresent: snapshot?.forumName.isEmpty == false,
            postCount: snapshot?.posts.count,
            imageNodeCount: snapshot.map(Self.imageNodeCount),
            outcome: outcome,
            durationMilliseconds: debugMilliseconds(
                from: started.duration(to: clock.now)
            )
        )
    }

    private static func imageNodeCount(_ snapshot: ThreadReaderSnapshot) -> Int {
        snapshot.posts.reduce(into: 0) { result, post in
            result += post.document.nodes.reduce(into: 0) { count, node in
                if case .image = node.payload {
                    count += 1
                }
            }
        }
    }

    private func failure(
        outcome: DebugLiveProbeOutcome,
        response: HTTPResponse?,
        started: ContinuousClock.Instant,
        clock: ContinuousClock
    ) -> DebugThreadProbeResult {
        if let response {
            return makeResult(
                response: response,
                snapshot: nil,
                outcome: outcome,
                started: started,
                clock: clock
            )
        }
        return DebugThreadProbeResult(
            statusCode: nil,
            mimeType: "unavailable",
            bodyByteCount: 0,
            decoded: false,
            titlePresent: false,
            forumPresent: false,
            postCount: nil,
            imageNodeCount: nil,
            outcome: outcome,
            durationMilliseconds: debugMilliseconds(
                from: started.duration(to: clock.now)
            )
        )
    }
}

private func debugOutcome(
    for error: EndpointExecutionError
) -> DebugLiveProbeOutcome {
    switch error {
    case .authentication:
        .authentication
    case .decode:
        .decode
    case .http:
        .http
    case .mapping:
        .mapping
    case .responseTooLarge:
        .responseTooLarge
    case .server:
        .server
    case .transport:
        .transport
    case .unsupportedContent:
        .unsupportedContent
    }
}

private func debugSafeMIMEType(_ headers: [String: String]) -> String {
    guard let rawValue = headers.first(where: { name, _ in
        name.caseInsensitiveCompare("content-type") == .orderedSame
    })?.value else {
        return "missing"
    }
    let value = rawValue
        .split(separator: ";", maxSplits: 1)
        .first?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased() ?? ""
    guard (1...64).contains(value.utf8.count),
          value.utf8.allSatisfy({ byte in
              switch byte {
              case 43, 45, 46, 47, 48...57, 97...122:
                  true
              default:
                  false
              }
          }) else {
        return "invalid"
    }
    return value
}

private func debugPositiveThreadID(_ value: Int64) -> Int64? {
    value > 0 ? value : nil
}

private func debugMilliseconds(from duration: Duration) -> Int {
    let components = duration.components
    let seconds = max(0, components.seconds)
    let milliseconds = seconds.multipliedReportingOverflow(by: 1_000)
    guard !milliseconds.overflow else {
        return 1_000_000
    }
    let fractional = max(
        0,
        components.attoseconds / 1_000_000_000_000_000
    )
    return min(1_000_000, Int(milliseconds.partialValue) + Int(fractional))
}

@MainActor
struct DebugLiveAPIProbeView: View {
    let sessionStore: SessionStore
    let client: any HTTPClient
    let authContextProvider: any AuthContextProviding

    @State private var hasStarted = false
    @State private var result = DebugLiveProbeResult.pending

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("Stage 15.6 Live Pagination Probe")
                    .font(Typography.font(.title))
                Text("endpoint=recommendations.personalized")
                recommendationPageSummary(
                    result.firstPage,
                    prefix: "page1"
                )
                recommendationPageSummary(
                    result.secondPage,
                    prefix: "page2"
                )
                Text(
                    "page2-new-items="
                        + "\(result.secondPageNewItemCount.map(String.init) ?? "none")"
                )
                Text("typed-outcome=\(result.outcome.rawValue)")
                Text("duration-ms=\(result.durationMilliseconds)")
                Divider()
                Text("endpoint=thread.pbPage")
                Text(
                    "thread-status="
                        + "\(result.thread.statusCode.map(String.init) ?? "none")"
                )
                Text("thread-mime=\(result.thread.mimeType)")
                Text("thread-bytes=\(result.thread.bodyByteCount)")
                Text(
                    "thread-proto-decoded="
                        + (result.thread.decoded ? "yes" : "no")
                )
                Text(
                    "thread-title-present="
                        + (result.thread.titlePresent ? "yes" : "no")
                )
                Text(
                    "thread-forum-present="
                        + (result.thread.forumPresent ? "yes" : "no")
                )
                Text(
                    "thread-posts="
                        + "\(result.thread.postCount.map(String.init) ?? "none")"
                )
                Text(
                    "thread-image-nodes="
                        + "\(result.thread.imageNodeCount.map(String.init) ?? "none")"
                )
                Text("thread-outcome=\(result.thread.outcome.rawValue)")
                Text(
                    "thread-duration-ms=\(result.thread.durationMilliseconds)"
                )
            }
            .font(Typography.font(.body))
            .foregroundStyle(SemanticColor.primaryText)
            .padding(Spacing.large)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(SemanticColor.background)
        .task {
            guard !hasStarted else {
                return
            }
            hasStarted = true
            await sessionStore.restoreIfNeeded()
            result = await DebugLiveRecommendationProbe(
                client: client,
                authContextProvider: authContextProvider
            ).run()
        }
    }

    @ViewBuilder
    private func recommendationPageSummary(
        _ page: DebugRecommendationPageProbeResult,
        prefix: String
    ) -> some View {
        Text(
            "\(prefix)-status="
                + "\(page.statusCode.map(String.init) ?? "none")"
        )
        Text("\(prefix)-mime=\(page.mimeType)")
        Text("\(prefix)-bytes=\(page.bodyByteCount)")
        Text("\(prefix)-proto-decoded=\(page.decoded ? "yes" : "no")")
        Text(
            "\(prefix)-mapped-items="
                + "\(page.mappedItemCount.map(String.init) ?? "none")"
        )
        Text(
            "\(prefix)-personalization-items="
                + "\(page.personalizationItemCount.map(String.init) ?? "none")"
        )
        Text("\(prefix)-outcome=\(page.outcome.rawValue)")
    }
}
#endif
