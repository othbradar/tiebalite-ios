#if DEBUG
import Foundation
import GeneratedProtobuf

/// Closed metadata only. Never retains response bytes, IDs, messages or headers.
struct NativeWriteResponseDiagnostic: Codable, Equatable, Sendable {
    enum MediaType: String, Codable, Sendable { case protobuf, json, html, binary, other, absent }
    enum IdentifierState: String, Codable, Sendable { case absent, invalid, positive }

    let status: Int
    let mediaType: MediaType
    let byteCount: Int
    let isJSONObject: Bool
    let jsonErrorCode: Int32?
    let nestedJSONErrorCode: Int32?
    let protobufDecoded: Bool
    let hasError: Bool
    let protobufErrorCode: Int32?
    let hasPayload: Bool
    let threadID: IdentifierState
    let postID: IdentifierState

    init(status: Int, contentType: String?, body: Data) {
        self.status = status
        mediaType = Self.classify(contentType)
        byteCount = body.count
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        isJSONObject = json != nil
        jsonErrorCode = Self.code(json?["error_code"])
        nestedJSONErrorCode = Self.code((json?["error"] as? [String: Any])?["errno"])
        let envelope = body.isEmpty ? nil : try? TiebaNativeWrite_Response(serializedBytes: body)
        protobufDecoded = envelope != nil
        hasError = envelope?.hasError == true
        protobufErrorCode = envelope?.error.hasErrorno == true ? envelope?.error.errorno : nil
        hasPayload = envelope?.hasData == true
        threadID = Self.identifier(envelope?.data.tid)
        postID = Self.identifier(envelope?.data.pid)
    }

    private static func identifier(_ value: String?) -> IdentifierState {
        guard let value, !value.isEmpty else { return .absent }
        return Int64(value).map { $0 > 0 } == true ? .positive : .invalid
    }

    private static func code(_ value: Any?) -> Int32? {
        if let value = value as? String { return Int32(value) }
        if let value = value as? NSNumber { return Int32(exactly: value.int64Value) }
        return nil
    }

    private static func classify(_ value: String?) -> MediaType {
        guard let value else { return .absent }
        switch value.lowercased().split(separator: ";", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) {
        case "application/protobuf", "application/x-protobuf": return .protobuf
        case "application/json", "text/json": return .json
        case "text/html": return .html
        case "application/octet-stream": return .binary
        default: return .other
        }
    }
}
#endif
