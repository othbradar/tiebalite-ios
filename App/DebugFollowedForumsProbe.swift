#if DEBUG
import Foundation
import Observation
import SwiftUI

struct DebugFollowedForumsProbe: Sendable {
    let client: any HTTPClient
    let authContextProvider: any AuthContextProviding

    func run() async -> DebugAuthenticatedProbeResult {
        let context = await authContextProvider.context()
        do {
            let authorization = try await authContextProvider.authorization(
                for: context
            )
            let endpoint = try ForumGuideProtocol.makeDescriptor(
                host: "tiebac.baidu.com"
            )
            let request = try await EndpointRequestBuilder(
                authorizer: ActiveSessionRequestAuthorizer(
                    authContextProvider: authContextProvider
                )
            ).makeRequest(
                endpoint: endpoint,
                authentication: context,
                body: try ForumGuideProtocol.makeAuthenticatedRequestBody(
                    authorization: authorization
                )
            )
            let response = try await client.execute(request)
            try Task.checkCancellation()
            _ = try await authContextProvider.authorization(for: context)
            return Self.map(response: response, endpoint: endpoint)
        } catch is CancellationError {
            return Self.empty(outcome: .cancelled)
        } catch is RequestAuthorizationError {
            return Self.empty(outcome: .authentication)
        } catch let error as HTTPClientError {
            return Self.empty(outcome: Self.outcome(for: error))
        } catch {
            return Self.empty(outcome: .request)
        }
    }

    static func map(
        response: HTTPResponse,
        endpoint: EndpointDescriptor
    ) -> DebugAuthenticatedProbeResult {
        let mimeType = normalizedMIMEType(response.headers)
        guard (200..<300).contains(response.statusCode) else {
            return result(
                response: response,
                mimeType: mimeType,
                decoded: false,
                itemCount: nil,
                outcome: .http
            )
        }
        guard response.body.count <= endpoint.responseBodyLimit else {
            return result(
                response: response,
                mimeType: mimeType,
                decoded: false,
                itemCount: nil,
                outcome: .responseTooLarge
            )
        }
        guard endpoint.allowedResponseMIMETypes.contains(mimeType) else {
            return result(
                response: response,
                mimeType: mimeType,
                decoded: false,
                itemCount: nil,
                outcome: .unsupportedContent
            )
        }

        do {
            let wire = try ForumGuideProtocol.decode(response.body)
            do {
                let forums = try ForumGuideProtocol.map(wire)
                return result(
                    response: response,
                    mimeType: mimeType,
                    decoded: true,
                    itemCount: forums.count,
                    outcome: .success
                )
            } catch {
                return result(
                    response: response,
                    mimeType: mimeType,
                    decoded: true,
                    itemCount: nil,
                    outcome: .mapping
                )
            }
        } catch is EndpointWireFailure {
            return result(
                response: response,
                mimeType: mimeType,
                decoded: true,
                itemCount: nil,
                outcome: .server
            )
        } catch {
            return result(
                response: response,
                mimeType: mimeType,
                decoded: false,
                itemCount: nil,
                outcome: .decode
            )
        }
    }

    private static func result(
        response: HTTPResponse,
        mimeType: String,
        decoded: Bool,
        itemCount: Int?,
        outcome: DebugAuthenticatedProbeOutcome
    ) -> DebugAuthenticatedProbeResult {
        DebugAuthenticatedProbeResult(
            statusCode: response.statusCode,
            mimeType: mimeType,
            responseBytes: response.body.count,
            decoded: decoded,
            itemCount: itemCount,
            outcome: outcome
        )
    }

    private static func empty(
        outcome: DebugAuthenticatedProbeOutcome
    ) -> DebugAuthenticatedProbeResult {
        DebugAuthenticatedProbeResult(
            statusCode: nil,
            mimeType: "unavailable",
            responseBytes: 0,
            decoded: false,
            itemCount: nil,
            outcome: outcome
        )
    }

    private static func outcome(
        for error: HTTPClientError
    ) -> DebugAuthenticatedProbeOutcome {
        switch error {
        case .malformedResponse:
            return .malformedResponse
        case .offline:
            return .offline
        case .responseTooLarge:
            return .responseTooLarge
        case .server:
            return .http
        case .timedOut:
            return .timedOut
        case .transport:
            return .transport
        case .unavailable:
            return .unavailable
        }
    }

    private static func normalizedMIMEType(
        _ headers: [String: String]
    ) -> String {
        let value = headers.first { key, _ in
            key.caseInsensitiveCompare("content-type") == .orderedSame
        }?.value
        return value?
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "unavailable"
    }
}

@MainActor
@Observable
private final class DebugFollowedForumsProbeStore {
    enum State: Equatable {
        case idle
        case result(DebugAuthenticatedProbeResult)
        case running
    }

    private(set) var state: State = .idle
    private var task: Task<Void, Never>?
    private let probe: DebugFollowedForumsProbe

    init(
        client: any HTTPClient,
        authContextProvider: any AuthContextProviding
    ) {
        probe = DebugFollowedForumsProbe(
            client: client,
            authContextProvider: authContextProvider
        )
    }

    func run() {
        task?.cancel()
        state = .running
        let probe = probe
        task = Task { @MainActor [weak self] in
            let result = await probe.run()
            guard !Task.isCancelled else {
                return
            }
            self?.state = .result(result)
            self?.task = nil
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        if state == .running {
            state = .idle
        }
    }
}

@MainActor
struct DebugFollowedForumsProbeView: View {
    @Bindable var sessionStore: SessionStore
    @State private var probeStore: DebugFollowedForumsProbeStore

    init(
        sessionStore: SessionStore,
        client: any HTTPClient,
        authContextProvider: any AuthContextProviding
    ) {
        self.sessionStore = sessionStore
        _probeStore = State(
            initialValue: DebugFollowedForumsProbeStore(
                client: client,
                authContextProvider: authContextProvider
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Button("运行关注吧 Debug Probe") {
                probeStore.run()
            }
            .disabled(
                sessionStore.state != .signedIn || probeStore.state == .running
            )
            .accessibilityIdentifier("followed-forums.debug.probe")

            Text(summary)
                .font(Typography.font(.caption))
                .foregroundStyle(SemanticColor.secondaryText)
                .accessibilityIdentifier("followed-forums.debug.probe-result")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onDisappear {
            probeStore.cancel()
        }
        .onChange(of: sessionStore.state) { _, newState in
            if newState != .signedIn {
                probeStore.cancel()
            }
        }
    }

    private var summary: String {
        switch probeStore.state {
        case .idle:
            return "未运行；只显示脱敏响应元数据。"
        case .running:
            return "请求中…"
        case let .result(result):
            return "status=\(result.statusCode.map(String.init) ?? "none") " +
                "mime=\(result.mimeType) bytes=\(result.responseBytes) " +
                "decoded=\(result.decoded) " +
                "items=\(result.itemCount.map(String.init) ?? "none") " +
                "outcome=\(result.outcome.rawValue)"
        }
    }
}
#endif
