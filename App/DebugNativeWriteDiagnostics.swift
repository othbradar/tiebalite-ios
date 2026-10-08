#if DEBUG
import Foundation
import OSLog

/// Observes only the existing native account/TBS/write transport. It never
/// constructs, retries or changes a request, nor changes response interpretation.
struct DebugNativeWriteDataLoader: HTTPDataLoading {
    let base: any HTTPDataLoading
    let diagnostics: DebugNativeWriteDiagnostics

    func data(for request: URLRequest, maximumByteCount: Int) async throws -> (Data, URLResponse) {
        guard let url = request.url, url.scheme == "https", url.host == "tiebac.baidu.com",
              request.httpMethod == "POST", let api = NativeWriteAPI(rawValue: url.path) else {
            return try await base.data(for: request, maximumByteCount: maximumByteCount)
        }
        do {
            let result = try await base.data(for: request, maximumByteCount: maximumByteCount)
            let response = result.1 as? HTTPURLResponse
            let metadata = response.map {
                NativeWriteResponseDiagnostic(
                    status: $0.statusCode,
                    contentType: $0.value(forHTTPHeaderField: "Content-Type"), body: result.0)
            }
            await diagnostics.record(api: api, response: metadata, failure: response == nil ? .nonHTTP : nil)
            return result
        } catch {
            await diagnostics.record(api: api, response: nil, failure: .classify(error))
            throw error
        }
    }
}

actor DebugNativeWriteDiagnostics {
    enum Failure: String, Codable, Sendable {
        case cancelled, timeout, offline, transport, oversized, nonHTTP, other

        static func classify(_ error: any Error) -> Self {
            if error is CancellationError { return .cancelled }
            if let error = error as? URLError {
                switch error.code {
                case .cancelled: return .cancelled
                case .timedOut: return .timeout
                case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost: return .offline
                default: return .transport
                }
            }
            if let error = error as? HTTPClientError {
                switch error {
                case .responseTooLarge: return .oversized
                case .offline: return .offline
                case .timedOut: return .timeout
                case .transport: return .transport
                default: return .other
                }
            }
            return .other
        }
    }

    struct Event: Codable, Sendable {
        let sequence: Int
        let time: Date
        let operation: String
        let response: NativeWriteResponseDiagnostic?
        let failure: Failure?
    }

    private let directory: URL?
    private var events: [Event] = []
    private var sequence = 0
    private let logger = Logger(subsystem: "dev.local.tiebaliteios", category: "native-write-diagnostics")

    init(directory: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first) {
        self.directory = directory
    }

    func record(api: NativeWriteAPI, response: NativeWriteResponseDiagnostic?, failure: Failure?) {
        sequence += 1
        let operation: String
        switch api {
        case .account: operation = "account"
        case .tbs: operation = "tbs"
        case .reply: operation = "reply"
        case .thread: operation = "thread"
        }
        events.append(.init(sequence: sequence, time: Date(), operation: operation, response: response, failure: failure))
        events = Array(events.suffix(8))
        guard let directory else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(events).write(
                to: directory.appendingPathComponent("NativeWriteDiagnostics-v1.json"), options: .atomic)
        } catch {
            logger.error("Could not persist sanitized native-write metadata")
        }
    }
}
#endif
