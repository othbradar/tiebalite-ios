import Foundation

enum NativeTBSError: Error, Equatable, Sendable {
    case alreadyPreparing
    case invalidRequestContext
    case malformedResponse
    case missingValue
    case serverRejected(Int32)
    case superseded
}

struct NativeTBSHTTPContext: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let userAgent: String
    let acceptLanguage: String?
    let clientLogID: Int64
    let cookies: NativeWriteRequestCookies

    var description: String { "NativeTBSHTTPContext(redacted)" }
    var debugDescription: String { description }
}

enum NativeTBSRequest {
    static func make(parameters: [String: String], context: NativeTBSHTTPContext) throws -> HTTPRequest {
        guard !context.userAgent.isEmpty else { throw HTTPRequestValidationError.invalidHeader }
        guard parameters["BDUSS"]?.isEmpty == false, parameters["sign"]?.isEmpty == false else {
            throw NativeTBSError.invalidRequestContext
        }
        var headers = try context.cookies.headerFields()
        headers["User-Agent"] = context.userAgent
        headers["Accept-Language"] = context.acceptLanguage
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        if context.clientLogID != 0 && context.clientLogID != -1 {
            headers["client_logid"] = String(context.clientLogID)
        }
        guard let url = URL(string: "https://tiebac.baidu.com/c/s/tbs") else {
            throw EndpointRequestBuilderError.invalidURL
        }
        // IDPServerAPI's BBA form branch chooses 10 seconds for net_type="1",
        // otherwise 25. Its earlier initializer's 20 is not the final timeout.
        return try HTTPRequest(method: .post, url: url, headers: headers, body: encode(parameters),
                               timeout: parameters["net_type"] == "1" ? 10 : 25,
                               responseBodyLimit: 1_024 * 1_024)
    }

    static func encode(_ parameters: [String: String]) throws -> Data {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        // Native NSDictionary enumeration has no promised order. Sort locally
        // for reproducibility; signing is independently sorted before encoding.
        let pairs = try parameters.keys.sorted().map { key in
            guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed),
                  let encodedValue = parameters[key]?.addingPercentEncoding(withAllowedCharacters: allowed) else {
                throw NativeTBSError.invalidRequestContext
            }
            return "\(encodedKey)=\(encodedValue)"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }
}
