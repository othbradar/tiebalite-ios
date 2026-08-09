#if DEBUG && !UITESTING
import Foundation

enum DebugLiveProbeOutcome: String, Sendable {
    case authentication
    case cancelled
    case clientTerminal = "client-terminal"
    case decode
    case http
    case mapping
    case notRun = "not-run"
    case request
    case responseTooLarge = "response-too-large"
    case server
    case success
    case transport
    case unsupportedContent = "unsupported-content"
}

struct DebugLiveProbeResult: Sendable {
    let firstPage: DebugRecommendationPageProbeResult
    let secondPage: DebugRecommendationPageProbeResult
    let secondPageNewItemCount: Int?
    let outcome: DebugLiveProbeOutcome
    let durationMilliseconds: Int
    let thread: DebugThreadProbeResult

    static let pending = DebugLiveProbeResult(
        firstPage: .pending,
        secondPage: .notRun,
        secondPageNewItemCount: nil,
        outcome: .transport,
        durationMilliseconds: 0,
        thread: .notRun
    )
}

struct DebugRecommendationPageProbeResult: Sendable {
    let statusCode: Int?
    let mimeType: String
    let bodyByteCount: Int
    let decoded: Bool
    let mappedItemCount: Int?
    let personalizationItemCount: Int?
    let outcome: DebugLiveProbeOutcome

    static let pending = DebugRecommendationPageProbeResult(
        statusCode: nil,
        mimeType: "pending",
        bodyByteCount: 0,
        decoded: false,
        mappedItemCount: nil,
        personalizationItemCount: nil,
        outcome: .transport
    )

    static let notRun = DebugRecommendationPageProbeResult(
        statusCode: nil,
        mimeType: "not-run",
        bodyByteCount: 0,
        decoded: false,
        mappedItemCount: nil,
        personalizationItemCount: nil,
        outcome: .notRun
    )
}

struct DebugThreadProbeResult: Sendable {
    let statusCode: Int?
    let mimeType: String
    let bodyByteCount: Int
    let decoded: Bool
    let titlePresent: Bool
    let forumPresent: Bool
    let postCount: Int?
    let imageNodeCount: Int?
    let outcome: DebugLiveProbeOutcome
    let durationMilliseconds: Int

    static let notRun = DebugThreadProbeResult(
        statusCode: nil,
        mimeType: "not-run",
        bodyByteCount: 0,
        decoded: false,
        titlePresent: false,
        forumPresent: false,
        postCount: nil,
        imageNodeCount: nil,
        outcome: .notRun,
        durationMilliseconds: 0
    )
}

private actor DebugStage156CapturingHTTPClient: HTTPClient {
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

struct DebugLiveRecommendationProbe: Sendable {
    private let client: any HTTPClient
    private let authContextProvider: any AuthContextProviding

    init(
        client: any HTTPClient,
        authContextProvider: any AuthContextProviding
    ) {
        self.client = client
        self.authContextProvider = authContextProvider
    }

    func run() async -> DebugLiveProbeResult {
        let clock = ContinuousClock()
        let started = clock.now
        let capturing = DebugStage156CapturingHTTPClient(base: client)
        let repository = LiveRecommendationRepository(
            client: capturing,
            authContextProvider: authContextProvider
        )
        do {
            let firstPage = try await repository.loadPage(.initial)
            let firstResult = try await capturedPageResult(
                from: capturing,
                index: 0,
                mappedItemCount: firstPage.items.count
            )
            return await loadSecondPage(
                repository: repository,
                capturing: capturing,
                firstPage: firstPage,
                firstResult: firstResult,
                started: started
            )
        } catch {
            return await failure(
                error: error,
                capturing: capturing,
                firstPage: .notRun,
                started: started
            )
        }
    }

    private func loadSecondPage(
        repository: LiveRecommendationRepository,
        capturing: DebugStage156CapturingHTTPClient,
        firstPage: RecommendationRepositoryPage,
        firstResult: DebugRecommendationPageProbeResult,
        started: ContinuousClock.Instant
    ) async -> DebugLiveProbeResult {
        guard firstPage.nextPageCandidate == 2 else {
            return result(
                firstPage: firstResult,
                secondPage: .notRun,
                newItemCount: nil,
                outcome: .mapping,
                started: started
            )
        }
        do {
            let secondPage = try await repository.loadPage(
                RecommendationPageRequest(loadKind: .nextPage, page: 2)
            )
            let firstIDs = Set(firstPage.items.map(\.threadID))
            let newCount = secondPage.items.filter {
                !firstIDs.contains($0.threadID)
            }.count
            let outcome: DebugLiveProbeOutcome = newCount > 0
                ? .success
                : .clientTerminal
            let secondResult = try await capturedPageResult(
                from: capturing,
                index: 1,
                mappedItemCount: secondPage.items.count,
                outcome: outcome
            )
            return result(
                firstPage: firstResult,
                secondPage: secondResult,
                newItemCount: newCount,
                outcome: outcome,
                started: started
            )
        } catch {
            return await failure(
                error: error,
                capturing: capturing,
                firstPage: firstResult,
                started: started
            )
        }
    }

    private func capturedPageResult(
        from capturing: DebugStage156CapturingHTTPClient,
        index: Int,
        mappedItemCount: Int,
        outcome: DebugLiveProbeOutcome = .success
    ) async throws -> DebugRecommendationPageProbeResult {
        let responses = await capturing.capturedResponses()
        guard responses.indices.contains(index) else {
            throw DebugStage156ProbeError.missingResponse
        }
        return pageResult(
            response: responses[index],
            mappedItemCount: mappedItemCount,
            outcome: outcome
        )
    }

    private func failure(
        error: any Error,
        capturing: DebugStage156CapturingHTTPClient,
        firstPage: DebugRecommendationPageProbeResult,
        started: ContinuousClock.Instant
    ) async -> DebugLiveProbeResult {
        let outcome = stage156Outcome(for: error)
        let responses = await capturing.capturedResponses()
        let responseIndex = firstPage.outcome == .notRun ? 0 : 1
        let failedPage = responses.indices.contains(responseIndex)
            ? pageResult(
                response: responses[responseIndex],
                mappedItemCount: nil,
                outcome: outcome
            )
            : unavailablePage(outcome: outcome)
        return result(
            firstPage: firstPage.outcome == .notRun ? failedPage : firstPage,
            secondPage: firstPage.outcome == .notRun ? .notRun : failedPage,
            newItemCount: nil,
            outcome: outcome,
            started: started
        )
    }

    private func pageResult(
        response: HTTPResponse,
        mappedItemCount: Int?,
        outcome: DebugLiveProbeOutcome
    ) -> DebugRecommendationPageProbeResult {
        let wire = try? PersonalizedProtocol.decode(response.body)
        return DebugRecommendationPageProbeResult(
            statusCode: response.statusCode,
            mimeType: stage156SafeMIMEType(response.headers),
            bodyByteCount: response.body.count,
            decoded: wire != nil,
            mappedItemCount: mappedItemCount,
            personalizationItemCount: wire.flatMap {
                $0.hasData ? $0.data.threadPersonalized.count : nil
            },
            outcome: outcome
        )
    }

    private func unavailablePage(
        outcome: DebugLiveProbeOutcome
    ) -> DebugRecommendationPageProbeResult {
        DebugRecommendationPageProbeResult(
            statusCode: nil,
            mimeType: "unavailable",
            bodyByteCount: 0,
            decoded: false,
            mappedItemCount: nil,
            personalizationItemCount: nil,
            outcome: outcome
        )
    }

    private func result(
        firstPage: DebugRecommendationPageProbeResult,
        secondPage: DebugRecommendationPageProbeResult,
        newItemCount: Int?,
        outcome: DebugLiveProbeOutcome,
        started: ContinuousClock.Instant
    ) -> DebugLiveProbeResult {
        DebugLiveProbeResult(
            firstPage: firstPage,
            secondPage: secondPage,
            secondPageNewItemCount: newItemCount,
            outcome: outcome,
            durationMilliseconds: stage156Milliseconds(
                from: started.duration(to: ContinuousClock().now)
            ),
            thread: .notRun
        )
    }
}

private enum DebugStage156ProbeError: Error {
    case missingResponse
}

private func stage156Outcome(for error: any Error) -> DebugLiveProbeOutcome {
    if error is CancellationError {
        return .cancelled
    }
    if error is RequestAuthorizationError {
        return .authentication
    }
    guard let endpointError = error as? EndpointExecutionError else {
        return error is DebugStage156ProbeError ? .transport : .request
    }
    switch endpointError {
    case .authentication:
        return .authentication
    case .decode:
        return .decode
    case .http:
        return .http
    case .mapping:
        return .mapping
    case .responseTooLarge:
        return .responseTooLarge
    case .server:
        return .server
    case .transport:
        return .transport
    case .unsupportedContent:
        return .unsupportedContent
    }
}

private func stage156SafeMIMEType(_ headers: [String: String]) -> String {
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

private func stage156Milliseconds(from duration: Duration) -> Int {
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
#endif
