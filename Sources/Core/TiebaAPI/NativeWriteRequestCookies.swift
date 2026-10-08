import Foundation

/// Only the native request's explicitly selected configuration cookies. This
/// type never reads a global cookie jar or persists account/session material.
struct NativeWriteRequestCookies: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    struct Entry: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
        let name: String
        let value: String

        var description: String { "NativeWriteCookieEntry(redacted)" }
        var debugDescription: String { description }
    }

    let entries: [Entry]

    init(networkStatus: Int, wifiKeepAlive: Bool, cellularKeepAlive: Bool,
         smallFlow: Bool, smallFlowValue: String?) {
        var entries: [Entry] = []
        let keepAlive = (networkStatus == 1 && wifiKeepAlive) || (networkStatus == 2 && cellularKeepAlive)
        if keepAlive { entries.append(Entry(name: "ka", value: "open")) }
        if smallFlow, let value = smallFlowValue { entries.append(Entry(name: "pub_env", value: value)) }
        self.entries = entries
    }

    func headerFields() throws -> [String: String] {
        guard !entries.isEmpty else { return [:] }
        let cookies = try entries.map { entry in
            guard !entry.value.contains("\r"), !entry.value.contains("\n"),
                  let cookie = HTTPCookie(properties: [
                    .domain: ".baidu.com", .path: "/", .name: entry.name, .value: entry.value
                  ]) else { throw HTTPRequestValidationError.invalidHeader }
            return cookie
        }
        return HTTPCookie.requestHeaderFields(with: cookies)
    }

    var description: String { "NativeWriteRequestCookies(redacted)" }
    var debugDescription: String { description }
}
