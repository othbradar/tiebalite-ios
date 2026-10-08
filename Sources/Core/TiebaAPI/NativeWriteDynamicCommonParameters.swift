import Foundation

/// Native per-request Common transformation before business merge and signing.
/// The caller owns serialization, prepared providers, and request-metrics state.
enum NativeWriteDynamicCommonParameters {
    enum Branch: String, Codable, Sendable { case standard, optimized }

    static func branch(for input: NativeWriteDynamicCommonContext) -> Branch {
        let coveredForum = input.signForumOnly && [
            "c/f/forum/getforumlist", "c/c/forum/sign", "c/c/forum/msign"
        ].contains { input.api.contains($0) }
        return input.signOptimizationEnabled && (input.signAll || coveredForum) ? .optimized : .standard
    }

    static func prepare(staticFields: [String: String], business: [String: String],
                        context: NativeWriteDynamicCommonContext,
                        metrics: inout NativeWriteRequestMetrics) -> [String: String] {
        var writer = FieldWriter(fields: staticFields, branch: branch(for: context))
        writer.set("sample_id", context.sampleID ?? "")
        writer.set("cmode", context.hasBrowseModeProvider ? context.browseMode : "1")
        writer.set("_client_id", context.clientID ?? "0")
        writer.set("extra", context.extra ?? "")
        writer.set("personalized_rec_switch", nonempty(context.personalizedSwitch)
                   ?? nonempty(context.storedPersonalizedSwitch) ?? "")
        writer.setIfPresent("net_type", context.networkType)
        writer.setIfPresent("user_agent", context.userAgent)
        accountFields(context, business: business, writer: &writer)
        writer.setIfPresent("z_id", nonempty(context.opaqueSDKValue))
        writer.set("_timestamp", number(context.timestampSeconds * 1_000, format: "%.0f"))
        writer.set("active_timestamp", number(context.activeTimestampSeconds * 1_000, format: "%.0f"))
        if context.keepAlive { writer.set("ka", "open") }
        consumeMetrics(&metrics, writer: &writer)
        if context.smallFlow { writer.set("smallflow", "open") }
        writer.set("subapp_type", "tieba")
        writer.set("tbs", context.tbs ?? "(null)")
        writer.set("diac", context.diac)
        writer.set("start_scheme", context.launchScheme ?? "")
        writer.set("start_type", String(context.launchType))
        return writer.fields
    }

    private static func accountFields(_ input: NativeWriteDynamicCommonContext, business: [String: String],
                                      writer: inout FieldWriter) {
        if let logoutValue = business["BDUSS_LOGOUT"] {
            writer.set("BDUSS", logoutValue)
        } else if let value = input.sessionValue {
            writer.set("BDUSS", value)
            writer.set("stoken", input.secondaryValue)
        }
    }

    private static func consumeMetrics(_ metrics: inout NativeWriteRequestMetrics, writer: inout FieldWriter) {
        guard let api = metrics.api else { return }
        // Both branches use the ordinary setter for metrics, including an
        // empty API string. The optimized safe-string rule does not apply.
        writer.fields["m_api"] = api
        metrics.api = nil
        if metrics.logID != 0 {
            writer.fields["m_logid"] = String(metrics.logID)
            metrics.logID = 0
        }
        writer.fields["m_cost"] = number(metrics.cost, format: "%f")
        metrics.cost = 0
        if metrics.result != 0 {
            writer.fields["m_result"] = String(metrics.result)
            metrics.result = 0
        }
        if metrics.uploadBytes != 0 {
            writer.fields["m_size_u"] = String(metrics.uploadBytes)
            metrics.uploadBytes = 0
        }
        if metrics.downloadBytes != 0 {
            writer.fields["m_size_d"] = String(metrics.downloadBytes)
            metrics.downloadBytes = 0
        }
    }

    private static func nonempty(_ value: String?) -> String? {
        value.flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func number(_ value: Double, format: String) -> String {
        String(format: format, locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private struct FieldWriter {
        var fields: [String: String]
        let branch: Branch

        mutating func set(_ key: String, _ value: String?) {
            if branch == .optimized {
                // Native safeSetString leaves the existing key untouched when
                // the provider returns nil/empty. The standard setter differs.
                if let value = nonempty(value) { fields[key] = value }
            } else {
                fields[key] = value
            }
        }

        mutating func setIfPresent(_ key: String, _ value: String?) {
            if let value { set(key, value) }
        }
    }
}
