import Foundation

/// Values must come from the current native request context, never a copied
/// official-app identity. This type does not create or persist that context.
struct NativeWriteHTTPContext: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let userAgent: String
    let acceptLanguage: String?
    let clientLogID: Int64
    let timeout: TimeInterval
    let responseState: NativeWriteResponseState?
    let cookies: NativeWriteRequestCookies

    var description: String { "NativeWriteHTTPContext(redacted)" }
    var debugDescription: String { description }
}

enum NativeWriteHTTPRequest {
    static func makeRequest(kind: TextComposeTarget.Kind, business: [String: String], common: [String: String],
                            context: NativeWriteHTTPContext, boundary: String) throws -> HTTPRequest {
        guard !context.userAgent.isEmpty else { throw HTTPRequestValidationError.invalidHeader }
        let bytes = try NativeWriteRequestEncoder.encode(kind: kind, business: business, common: common)
        let path = kind == .thread ? "/c/c/thread/add" : "/c/c/post/add"
        return try protobufRequest(endpoint: (path, NativeWriteRequestEncoder.command(for: kind)), bytes: bytes,
                                   context: context, boundary: boundary, responseBodyLimit: 1_024 * 1_024)
    }

    /// Shared native short-connection envelope, including CMD309751 reads.
    /// Callers supply an evidence-backed command and its matching native IDL.
    static func protobufRequest(endpoint: (path: String, command: Int), bytes: Data, context: NativeWriteHTTPContext,
                                boundary: String, responseBodyLimit: Int) throws -> HTTPRequest {
        guard !context.userAgent.isEmpty else { throw HTTPRequestValidationError.invalidHeader }
        let body = EndpointRequestBody.multipartBinary(
            boundary: boundary, fields: [],
            part: MultipartBinaryPart(name: "data", filename: "data", mimeType: "image/jpeg", data: bytes))
        let encoded = try EndpointRequestBuilder.encode(body, codec: .multipartBinary)
        var headers = context.responseState?.requestHeaders ?? [:]
        headers.merge(try context.cookies.headerFields()) { _, cookieValue in cookieValue }
        headers["User-Agent"] = context.userAgent
        headers["x_bd_data_type"] = "protobuf"
        headers["Retry-Count"] = "0"
        headers["Content-Type"] = encoded.contentType
        headers["Content-Length"] = String(encoded.data?.count ?? 0)
        headers["Accept-Language"] = context.acceptLanguage
        if context.clientLogID != 0 && context.clientLogID != -1 {
            headers["client_logid"] = String(context.clientLogID)
        }
        // TBCBaseModel's short-connection Proto branch routes the binary body
        // by command and requests the matching Protobuf response on the URL.
        guard let url = URL(string: "https://tiebac.baidu.com\(endpoint.path)?cmd=\(endpoint.command)&format=protobuf") else {
            throw EndpointRequestBuilderError.invalidURL
        }
        // Native multipart does not infer an outgoing Accept header from the
        // decoder's response MIME policy, nor duplicate Common in form fields.
        return try HTTPRequest(method: .post, url: url, headers: headers, body: encoded.data,
                               timeout: context.timeout, responseBodyLimit: responseBodyLimit)
    }
}
