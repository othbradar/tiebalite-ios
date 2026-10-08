import Foundation

/// Explicit native-provider outputs for one HTTPS/Protobuf request. These are
/// inputs, not replacements for the account, SDK, consent, or device providers.
struct NativeWriteDynamicCommonContext: Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let api: String
    let sampleID: String?
    let hasBrowseModeProvider: Bool
    let browseMode: String?
    let clientID: String?
    let extra: String?
    let personalizedSwitch: String?
    let storedPersonalizedSwitch: String?
    let networkType: String?
    let userAgent: String?
    let sessionValue: String?
    let secondaryValue: String?
    let opaqueSDKValue: String?
    let tbs: String?
    let diac: String?
    let launchScheme: String?
    let launchType: UInt64
    let timestampSeconds: Double
    let activeTimestampSeconds: Double
    let signOptimizationEnabled: Bool
    let signForumOnly: Bool
    let signAll: Bool
    let keepAlive: Bool
    let smallFlow: Bool

    var description: String { "NativeWriteDynamicCommonContext(redacted)" }
    var debugDescription: String { description }
}

/// Consumed only when a previous API is present, as in the native Common builder.
struct NativeWriteRequestMetrics: Codable, Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    var api: String?
    var logID: UInt64
    var cost: Double
    var result: Int64
    var uploadBytes: UInt32
    var downloadBytes: UInt32

    enum CodingKeys: String, CodingKey {
        case api, cost, result, uploadBytes, downloadBytes
        case logID = "logid"
    }

    var description: String { "NativeWriteRequestMetrics(redacted)" }
    var debugDescription: String { description }
}
