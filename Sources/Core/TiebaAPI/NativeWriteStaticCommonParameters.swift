import Foundation

/// Values supplied by the native runtime providers. No real provider, consent,
/// identity, SDK version, or device value is synthesized by this component.
struct NativeWriteStaticCommonContext: Codable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let clientVersion: String?
    let systemVersion: String?
    let deviceScore: String?
    let deviceFamily: String?
    let devicePlatform: String?
    let channel: String?
    let cuid: String?
    let legoVersion: String?
    let browserCuid: String?
    let browserInstanceID: String?
    let advertisingID: String?
    let sampleID: String?
    let vendorID: String?
    let mac: String?
    let eventDay: String?
    let sdkVersion: String?
    let frameworkVersion: String?
    let gameVersion: String?
    let pureMode: String?
    let miniAppMode: String?
    let privacyPolicyShown: Bool
    let screenWidth: Double
    let screenHeight: Double
    let screenScale: Double
    let imageQuality: Int64

    var description: String { "NativeWriteStaticCommonContext(redacted)" }
    var debugDescription: String { description }
}

/// Value-state equivalent of the two native static-Common construction paths.
/// Its owner must serialize access and supply the actual configuration branch.
struct NativeWriteStaticCommonParameters: Sendable {
    enum Mode: String, Codable, Sendable { case cached, recomputed }
    private var cached: [String: String]?

    mutating func parameters(_ input: NativeWriteStaticCommonContext, mode: Mode) -> [String: String] {
        var fields = mode == .cached ? cached ?? Self.initial(input) : Self.initial(input)
        if fields["shoubai_cuid"] == nil || fields["shoubai_iid"] != nil {
            if input.privacyPolicyShown {
                fields["shoubai_cuid"] = input.browserCuid
                fields.removeValue(forKey: "shoubai_iid")
            }
        }
        if let value = input.advertisingID, !value.isEmpty {
            if fields["idfa"] != nil || input.privacyPolicyShown { fields["idfa"] = value }
        } else {
            fields.removeValue(forKey: "idfa")
        }
        fields["pure_mode"] = input.pureMode
        fields["xcx_mode"] = input.miniAppMode
        if mode == .cached { cached = fields }
        return fields
    }

    private static func initial(_ input: NativeWriteStaticCommonContext) -> [String: String] {
        var fields: [String: String?] = [
            "_client_type": "1", "_client_version": input.clientVersion, "_os_version": input.systemVersion,
            "device_score": input.deviceScore, "brand": input.deviceFamily,
            "brand_type": input.devicePlatform, "model": input.devicePlatform,
            "from": input.channel, "cuid": input.cuid, "lego_lib_version": input.legoVersion,
            "shoubai_iid": input.browserInstanceID, "sample_id": input.sampleID,
            "idfv": input.vendorID, "mac": input.mac, "event_day": input.eventDay,
            "sdk_ver": input.sdkVersion, "framework_ver": input.frameworkVersion,
            "naws_game_ver": input.gameVersion, "q_type": String(input.imageQuality),
            "scr_w": decimal(input.screenWidth), "scr_h": decimal(input.screenHeight),
            "scr_dip": decimal(input.screenScale)
        ]
        if input.privacyPolicyShown {
            fields["shoubai_cuid"] = input.browserCuid
            fields["idfa"] = input.advertisingID
        }
        return fields.compactMapValues { $0 }
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
