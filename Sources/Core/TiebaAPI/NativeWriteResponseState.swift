import Foundation

/// The one response value the native write models carry to the next request.
/// Never retain or forward the complete Set-Cookie header.
struct NativeWriteResponseState: Codable, Equatable, Sendable,
    CustomStringConvertible, CustomDebugStringConvertible {
    private let value: String

    init?(headerValue: String?) {
        guard let headerValue,
              let match = headerValue.range(of: "__ymg_scsc=([^;]+)", options: .regularExpression) else { return nil }
        value = String(headerValue[match].dropFirst("__ymg_scsc=".count))
    }

    var requestHeaders: [String: String] { ["svcp_stk": value] }
    var description: String { "NativeWriteResponseState(redacted)" }
    var debugDescription: String { description }
}
