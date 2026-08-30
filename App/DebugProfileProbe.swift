#if DEBUG && !UITESTING
import Foundation
import SwiftUI

enum DebugProfileProbeLaunch {
    static let flag = "--stage16b-profile-probe"

    static func isRequested(arguments: [String]) -> Bool {
        arguments.filter { $0 == flag }.count == 1
    }
}

struct DebugProfileProbeResult: Equatable, Sendable {
    let statusCode: Int?
    let mimeType: String
    let bodyByteCount: Int
    let decoded: Bool
    let displayFieldCount: Int
    let typedError: String

    static let pending = DebugProfileProbeResult(
        statusCode: nil,
        mimeType: "pending",
        bodyByteCount: 0,
        decoded: false,
        displayFieldCount: 0,
        typedError: "pending"
    )

    var sanitizedSummary: String {
        let status = statusCode.map(String.init) ?? "none"
        return "http=\(status) " +
            "mime=\(mimeType) bytes=\(bodyByteCount) " +
            "decoded=\(decoded) fields=\(displayFieldCount) " +
            "error=\(typedError)"
    }
}

private actor DebugProfileCapturingHTTPClient: HTTPClient {
    private let base: any HTTPClient
    private var profileResult: DebugProfileProbeResult?

    init(base: any HTTPClient) {
        self.base = base
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        let response = try await base.execute(request)
        if request.url.path == "/c/u/user/profile" {
            let inspection = ProfileProtocol.inspectForDiagnostics(
                response.body
            )
            profileResult = DebugProfileProbeResult(
                statusCode: response.statusCode,
                mimeType: Self.mimeType(response.headers),
                bodyByteCount: response.body.count,
                decoded: inspection.decoded,
                displayFieldCount: inspection.displayFieldCount,
                typedError: "none"
            )
        }
        return response
    }

    func result() -> DebugProfileProbeResult? {
        profileResult
    }

    private static func mimeType(_ headers: [String: String]) -> String {
        headers.first { key, _ in
            key.caseInsensitiveCompare("content-type") == .orderedSame
        }?.value
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "unavailable"
    }
}

struct DebugProfileProbe: Sendable {
    func run() async -> DebugProfileProbeResult {
        let client = DebugProfileCapturingHTTPClient(
            base: URLSessionHTTPClient.production()
        )
        do {
            guard let forumRoute = ForumRoute("minecraft") else {
                return Self.failure("invalid-static-route")
            }
            let forum = try await LiveForumHomeRepository(client: client)
                .loadForumHome(route: forumRoute)
            guard let thread = forum.threads.first(where: { !$0.isPinned }) else {
                return Self.failure("empty-forum")
            }
            let snapshot = try await LiveThreadReaderRepository(client: client)
                .loadPage(.initial(threadID: thread.threadID))
            guard let route = UserProfileRoute(
                userID: snapshot.author.rawUserID,
                fallbackDisplayName: "公开用户"
            ) else {
                return Self.failure("missing-public-author-id")
            }
            _ = try await LiveUserProfileRepository(client: client)
                .loadProfile(route: route)
            return await client.result() ?? Self.failure("missing-response")
        } catch is CancellationError {
            return await failure(
                "cancelled",
                captured: client.result()
            )
        } catch let error as EndpointExecutionError {
            return await failure(
                Self.endpointErrorCode(error),
                captured: client.result()
            )
        } catch is ProfileProtocolError {
            return await failure(
                "profile-mapping",
                captured: client.result()
            )
        } catch is PBPageProtocolError {
            return Self.failure("thread-mapping")
        } catch is FRSPageProtocolError {
            return Self.failure("forum-mapping")
        } catch {
            return await failure(
                "request",
                captured: client.result()
            )
        }
    }

    private func failure(
        _ code: String,
        captured: DebugProfileProbeResult?
    ) -> DebugProfileProbeResult {
        guard let captured else {
            return Self.failure(code)
        }
        return DebugProfileProbeResult(
            statusCode: captured.statusCode,
            mimeType: captured.mimeType,
            bodyByteCount: captured.bodyByteCount,
            decoded: captured.decoded,
            displayFieldCount: captured.displayFieldCount,
            typedError: code
        )
    }

    private static func failure(_ code: String) -> DebugProfileProbeResult {
        DebugProfileProbeResult(
            statusCode: nil,
            mimeType: "unavailable",
            bodyByteCount: 0,
            decoded: false,
            displayFieldCount: 0,
            typedError: code
        )
    }

    private static func endpointErrorCode(
        _ error: EndpointExecutionError
    ) -> String {
        switch error {
        case .authentication:
            "authentication"
        case .decode:
            "decode"
        case let .http(statusCode):
            "http-\(statusCode)"
        case .mapping:
            "mapping"
        case .responseTooLarge:
            "response-too-large"
        case let .server(code):
            "server-\(code)"
        case .transport:
            "transport"
        case .unsupportedContent:
            "unsupported-content"
        }
    }
}

@MainActor
struct DebugProfileProbeView: View {
    @State private var result = DebugProfileProbeResult.pending

    var body: some View {
        ZStack {
            SemanticColor.background
            Text(result.sanitizedSummary)
                .font(Typography.font(.caption))
                .foregroundStyle(SemanticColor.primaryText)
                .padding(Spacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("debug.profile-probe.result")
        }
        .task {
            result = await DebugProfileProbe().run()
        }
    }
}
#endif
