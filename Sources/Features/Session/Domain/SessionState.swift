import Foundation

enum SessionFailure: Error, Equatable, Sendable {
    case credentialStore
    case loginIncomplete
    case logout
}

enum SessionState: Equatable, Sendable {
    case expired
    case failed(SessionFailure)
    case signedIn
    case signedOut
    case signingIn
    case signingOut
}

struct LoginCookieValues: Equatable, Sendable {
    let bduss: String?
    let stoken: String?

    var credential: SessionCredential? {
        SessionCredential(bduss: bduss, stoken: stoken)
    }

    static func select(
        from records: [LoginCookieRecord],
        completionURL: URL
    ) -> LoginCookieValues {
        LoginCookieValues(
            bduss: resolvedValue(
                named: "BDUSS",
                records: records,
                completionURL: completionURL
            ),
            stoken: resolvedValue(
                named: "STOKEN",
                records: records,
                completionURL: completionURL
            )
        )
    }

    private static func resolvedValue(
        named name: String,
        records: [LoginCookieRecord],
        completionURL: URL
    ) -> String? {
        let candidates = records.filter { record in
            record.name.uppercased() == name
                && !record.value.isEmpty
                && record.applies(to: completionURL)
        }
        guard let longestPath = candidates.map(\.normalizedPath.count).max()
        else {
            return nil
        }
        let pathMatches = candidates.filter {
            $0.normalizedPath.count == longestPath
        }
        guard let mostSpecificDomain = pathMatches
            .map(\.normalizedDomain.count)
            .max() else {
            return nil
        }
        let values = Set(
            pathMatches
                .filter {
                    $0.normalizedDomain.count == mostSpecificDomain
                }
                .map(\.value)
        )
        guard values.count == 1 else {
            return nil
        }
        return values.first
    }
}

struct LoginCookieRecord: Equatable, Sendable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let isSecure: Bool

    var normalizedDomain: String {
        domain.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    var normalizedPath: String {
        path.hasPrefix("/") ? path : "/"
    }

    func applies(to url: URL) -> Bool {
        guard let host = url.host?.lowercased(),
              url.scheme?.lowercased() == "https",
              !normalizedDomain.isEmpty,
              host == normalizedDomain
                || host.hasSuffix(".\(normalizedDomain)") else {
            return false
        }
        if isSecure, url.scheme?.lowercased() != "https" {
            return false
        }
        let requestPath = url.path.isEmpty ? "/" : url.path
        if requestPath == normalizedPath {
            return true
        }
        guard requestPath.hasPrefix(normalizedPath) else {
            return false
        }
        if normalizedPath.hasSuffix("/") {
            return true
        }
        let boundaryIndex = requestPath.index(
            requestPath.startIndex,
            offsetBy: normalizedPath.count
        )
        return boundaryIndex < requestPath.endIndex
            && requestPath[boundaryIndex] == "/"
    }
}

@MainActor
protocol SessionWebsiteDataCleaning: AnyObject {
    func clearSessionWebsiteData() async
}
