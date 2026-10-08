import Foundation

/// Metrics projection for the native JSON preparation envelope. This does not
/// decide whether an account/TBS is usable or change its business decoder.
enum NativePreparationResponseMetrics {
    static func decode(_ response: HTTPResponse, api: NativeWriteAPI,
                       measurement: NativeWriteTransferMeasurement) -> NativeWriteRequestMetrics? {
        guard [.account, .tbs, .imageUpload].contains(api), (200..<300).contains(response.statusCode) else { return nil }
        guard String(data: response.body, encoding: .utf8) != nil,
              let object = try? JSONSerialization.jsonObject(with: response.body),
              let fields = object as? [String: Any] else { return measurement.parseFailureMetrics(api: api.rawValue) }
        let primary = string(fields["error_code"])
        let nested = string((fields["error"] as? [String: Any])?["errno"])
        guard primary != nil || nested != nil else { return measurement.parseFailureMetrics(api: api.rawValue) }
        let primaryCode = primary.map { ($0 as NSString).intValue } ?? 0
        let code = primaryCode != 0 ? primaryCode : nested.map { ($0 as NSString).intValue } ?? 0
        return .init(api: String(api.rawValue.dropFirst()), logID: number(fields["logid"])?.uint64Value ?? 0,
                     cost: measurement.durationSeconds * 1_000,
                     result: code != 0 ? Int64(code) : (response.statusCode == 200 ? 0 : Int64(response.statusCode)),
                     uploadBytes: measurement.uploadBytes, downloadBytes: measurement.downloadBytes)
    }

    private static func string(_ value: Any?) -> String? {
        if let number = value as? NSNumber { return String(number.int64Value) }
        return value as? String
    }

    private static func number(_ value: Any?) -> NSNumber? {
        if let number = value as? NSNumber { return number }
        guard let text = value as? String else { return nil }
        // Native numberAtPath uses NSString.doubleValue even for digit strings.
        let double = (text as NSString).doubleValue
        return double.isFinite ? NSNumber(value: double) : nil
    }
}
