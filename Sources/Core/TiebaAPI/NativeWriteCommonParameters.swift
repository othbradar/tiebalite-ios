/// Prepared native provider values. This boundary does not acquire runtime
/// identity, initialize SDKs, or select account values for the caller.
struct NativeWriteCommonContext: Sendable {
    let staticValues: NativeWriteStaticCommonContext
    let staticMode: NativeWriteStaticCommonParameters.Mode
    let dynamicValues: NativeWriteDynamicCommonContext
    let metadata: NativeWriteCommonMetadata
}

struct NativeWriteCommonParameters: Sendable {
    private var staticParameters = NativeWriteStaticCommonParameters()

    mutating func prepareImageUpload(_ context: NativeWriteCommonContext, business: [String: String],
                                     metrics: inout NativeWriteRequestMetrics) throws -> [String: String] {
        guard context.dynamicValues.api == NativeWriteAPI.imageUpload.rawValue else { throw NativeTBSError.invalidRequestContext }
        let fields = staticParameters.parameters(context.staticValues, mode: context.staticMode)
        let common = NativeWriteDynamicCommonParameters.prepare(
            staticFields: fields, business: business, context: context.dynamicValues, metrics: &metrics)
        return NativeWriteSigning.tbsForm(common, business: business)
    }

    mutating func prepare(_ context: NativeWriteCommonContext, business: [String: String],
                          metrics: inout NativeWriteRequestMetrics) -> [String: String] {
        let staticFields = staticParameters.parameters(context.staticValues, mode: context.staticMode)
        let common = NativeWriteDynamicCommonParameters.prepare(
            staticFields: staticFields, business: business, context: context.dynamicValues, metrics: &metrics
        )
        return NativeWriteSigning.common(common, business: business, metadata: context.metadata,
                                         branch: NativeWriteDynamicCommonParameters.branch(for: context.dynamicValues))
    }

    mutating func prepareTBS(_ context: NativeWriteCommonContext, authorization: SessionAuthorization,
                             metrics: inout NativeWriteRequestMetrics) throws -> [String: String] {
        guard context.dynamicValues.api == "/c/s/tbs" else { throw NativeTBSError.invalidRequestContext }
        let business = ["BDUSS": authorization.bduss]
        let staticFields = staticParameters.parameters(context.staticValues, mode: context.staticMode)
        let common = NativeWriteDynamicCommonParameters.prepare(
            staticFields: staticFields, business: business, context: context.dynamicValues, metrics: &metrics)
        return NativeWriteSigning.tbsForm(common, business: business)
    }

    mutating func prepareAccount(_ context: NativeWriteCommonContext, authorization: SessionAuthorization,
                                 firstLogin: Bool, metrics: inout NativeWriteRequestMetrics) throws -> [String: String] {
        guard context.dynamicValues.api == NativeWriteAPI.account.rawValue else { throw NativeTBSError.invalidRequestContext }
        var business = ["bdusstoken": authorization.bduss, "first_login": firstLogin ? "1" : "0"]
        if !authorization.stoken.isEmpty { business["stoken"] = authorization.stoken }
        let fields = staticParameters.parameters(context.staticValues, mode: context.staticMode)
        let common = NativeWriteDynamicCommonParameters.prepare(
            staticFields: fields, business: business, context: context.dynamicValues, metrics: &metrics)
        return NativeWriteSigning.tbsForm(common, business: business)
    }
}
