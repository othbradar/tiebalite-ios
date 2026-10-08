import CryptoKit
import Foundation

struct NativeWriteCommonMetadata: Sendable {
    let packageVersion: String?
    let experimentHits: String?
    let experimentMisses: String?
}

/// The native HTTPS/Protobuf signing boundary after account and device values
/// have been prepared. It does not fabricate or acquire that runtime context.
enum NativeWriteSigning {
    static func common(_ common: [String: String], business: [String: String],
                       metadata: NativeWriteCommonMetadata,
                       branch: NativeWriteDynamicCommonParameters.Branch = .standard) -> [String: String] {
        let parameters = common.merging(business) { _, businessValue in businessValue }
        var result = common
        result["sign"] = signature(parameters)
        // addExtraParamsWithRequestParams returns before the standard branch's
        // package/experiment annotations. Neither branch signs those additions.
        guard branch == .standard else { return result }
        if let version = metadata.packageVersion { result["package_version"] = version }
        result["abtest_config_intervention"] =
            "\(metadata.experimentHits ?? "(null)")^\(metadata.experimentMisses ?? "(null)")"
        // The native optional common.sig is dropped by its IDL descriptor. Do
        // not manufacture it or move it into the distinct business data.sig.
        return result
    }

    /// Ordinary TBS forms return the merged parameters before the Protobuf
    /// metadata suffix. The TBS path is outside the native extra-sig/rename lists.
    static func tbsForm(_ common: [String: String], business: [String: String]) -> [String: String] {
        var result = common.merging(business) { _, businessValue in businessValue }
        result["sign"] = signature(result)
        return result
    }

    private static func signature(_ parameters: [String: String]) -> String {
        let keys = parameters.keys.sorted { $0.compare($1, options: .literal) == .orderedAscending }
        let raw = keys.map { "\($0)=\(parameters[$0] ?? "")" }.joined() + "tiebaclient!!!"
        return Insecure.MD5.hash(data: Data(raw.utf8)).map { String(format: "%02X", $0) }.joined()
    }
}
