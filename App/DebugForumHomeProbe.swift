#if DEBUG && !UITESTING
import Foundation
import SwiftUI

enum DebugForumHomeProbeLaunch {
    static let flag = "--stage14-forum-home-probe"

    static func isRequested(arguments: [String]) -> Bool {
        arguments.filter { $0 == flag }.count == 1
    }
}

private actor DebugForumHomeCapturingHTTPClient: HTTPClient {
    private let base: any HTTPClient
    private var response: HTTPResponse?

    init(base: any HTTPClient) {
        self.base = base
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        let response = try await base.execute(request)
        self.response = response
        return response
    }

    func capturedResponse() -> HTTPResponse? {
        response
    }
}

@MainActor
struct DebugForumHomeProbeView: View {
    private let route: ForumRoute?
    private let client: DebugForumHomeCapturingHTTPClient
    @State private var store: ForumHomeStore?
    @State private var summary = "status=pending"

    init() {
        let route = ForumRoute("minecraft")
        let client = DebugForumHomeCapturingHTTPClient(
            base: URLSessionHTTPClient.production()
        )
        self.route = route
        self.client = client
        _store = State(
            initialValue: route.map {
                ForumHomeStore(
                    route: $0,
                    repository: LiveForumHomeRepository(client: client)
                )
            }
        )
    }

    @ViewBuilder
    var body: some View {
        if let route, let store {
            VStack(spacing: 0) {
                Text(summary)
                    .font(Typography.font(.caption))
                    .foregroundStyle(SemanticColor.secondaryText)
                    .padding(Spacing.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SemanticColor.surface)
                    .accessibilityIdentifier("forum-home.debug.probe-result")

                ForumHomeView(
                    store: store,
                    route: route,
                    onOpenThread: { _ in }
                )
            }
            .onChange(of: store.state) { _, state in
                guard state.isTerminalForProbe else {
                    return
                }
                Task { @MainActor in
                    summary = await sanitizedSummary(store: store)
                }
            }
        } else {
            Text("status=none outcome=invalid-static-route")
                .accessibilityIdentifier("forum-home.debug.probe-result")
        }
    }

    private func sanitizedSummary(store: ForumHomeStore) async -> String {
        guard let response = await client.capturedResponse() else {
            return "status=none mime=unavailable bytes=0 decoded=false " +
                "items=none typed-error=transport outcome=request"
        }
        let mime = response.headers.first { key, _ in
            key.caseInsensitiveCompare("content-type") == .orderedSame
        }?.value
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "unavailable"
        let inspection = FRSPageProtocol.inspectForDiagnostics(response.body)
        let itemCount: String
        let typedError: String
        let outcome: String
        switch store.state {
        case let .loaded(snapshot):
            itemCount = String(snapshot.threads.count)
            typedError = "none"
            outcome = "success"
        case .empty:
            itemCount = "0"
            typedError = "none"
            outcome = "success"
        case .initialFailure, .refreshFailure:
            itemCount = "none"
            if !(200..<300).contains(response.statusCode) {
                typedError = "http"
            } else if !FRSPageProtocol.allowedResponseMIMETypes.contains(mime) {
                typedError = "mime"
            } else if !inspection.decoded {
                typedError = "decode"
            } else if inspection.hasServerError {
                typedError = "server"
            } else {
                typedError = "mapping"
            }
            outcome = "failure"
        case .initialLoading, .refreshing:
            itemCount = "none"
            typedError = "cancelled"
            outcome = "cancelled"
        }
        return "status=\(response.statusCode) mime=\(mime) " +
            "bytes=\(response.body.count) decoded=\(inspection.decoded) " +
            "items=\(itemCount) typed-error=\(typedError) " +
            "outcome=\(outcome)"
    }
}

private extension ForumHomeState {
    var isTerminalForProbe: Bool {
        switch self {
        case .empty, .initialFailure, .loaded, .refreshFailure:
            true
        case .initialLoading, .refreshing:
            false
        }
    }
}
#endif
