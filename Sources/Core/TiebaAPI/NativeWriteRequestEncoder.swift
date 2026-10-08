import Foundation
import GeneratedProtobuf
import SwiftProtobuf

/// The native IDL boundary. Account preparation and request signing supply these
/// dictionaries; this component neither invents context nor performs network work.
enum NativeWriteRequestEncoder {
    static func command(for kind: TextComposeTarget.Kind) -> Int {
        kind == .thread ? 309730 : 309731
    }

    static func encode(kind: TextComposeTarget.Kind, business: [String: String],
                       common: [String: String]) throws -> Data {
        var fields: [String: Any] = business
        var encodedCommon = common
        // TBCIDLBaseTransform's int32 setter uses NSString.intValue. The
        // standard Common builder emits an empty string when this setting is
        // unavailable; native IDL writes a present zero. Normalize only at the
        // wire boundary, after signing the original (empty-string) dictionary.
        if encodedCommon["personalized_rec_switch"]?.isEmpty == true {
            encodedCommon["personalized_rec_switch"] = "0"
        }
        fields["common"] = encodedCommon
        let json = try JSONSerialization.data(withJSONObject: ["data": fields], options: [.sortedKeys])
        // The reference dictionary also contains signing-only keys such as floor.
        // Numeric values remain strings here to preserve integers larger than 2^53.
        var options = JSONDecodingOptions()
        options.ignoreUnknownFields = true
        if kind == .thread {
            return try TiebaNativeWrite_ThreadRequest(jsonUTF8Bytes: json, options: options).serializedData()
        }
        return try TiebaNativeWrite_PostRequest(jsonUTF8Bytes: json, options: options).serializedData()
    }
}
