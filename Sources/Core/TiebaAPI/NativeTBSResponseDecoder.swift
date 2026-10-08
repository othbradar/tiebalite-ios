import Foundation

enum NativeTBSResponseDecoder {
    static func decode(_ response: HTTPResponse) throws -> String {
        guard (200..<300).contains(response.statusCode) else {
            throw HTTPClientError.server(statusCode: response.statusCode)
        }
        guard String(data: response.body, encoding: .utf8) != nil,
              let json = try? JSONSerialization.jsonObject(with: response.body),
              let fields = json as? [String: Any] else { throw NativeTBSError.malformedResponse }
        let primary = string(fields["error_code"])
        let nested = string((fields["error"] as? [String: Any])?["errno"])
        guard primary != nil || nested != nil else { throw NativeTBSError.malformedResponse }
        let primaryCode = primary.map { ($0 as NSString).intValue } ?? 0
        let code = primaryCode != 0 ? primaryCode : nested.map { ($0 as NSString).intValue } ?? 0
        // The native JSON path rejects any nonzero code, unlike its Protobuf
        // path. A nonempty tbs cannot turn that failure into a successful fetch.
        guard code == 0 else { throw NativeTBSError.serverRejected(code) }
        guard let value = string(fields["tbs"]), !value.isEmpty else { throw NativeTBSError.missingValue }
        return value
    }

    private static func string(_ value: Any?) -> String? {
        // IDPExtension.stringAtPath uses NSNumber.longLongValue, NSString as-is,
        // and nil for all other JSON types. Do not trim or search nested data.
        if let number = value as? NSNumber { return String(number.int64Value) }
        return value as? String
    }
}
