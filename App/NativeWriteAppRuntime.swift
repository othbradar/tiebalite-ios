import Foundation
import UIKit
import WebKit

/// Runtime for the explicitly limited iOS text trial. Missing proprietary
/// providers stay absent, rather than borrowing Android/official-app IDs.
@MainActor
final class NativeWriteAppRuntime: NativeWriteRuntimeProviding {
    static let protocolVersion = "22.11.1"
    var requestMetrics = NativeWriteRequestMetrics(api: nil, logID: 0, cost: 0, result: 0, uploadBytes: 0, downloadBytes: 0)
    private var systemUserAgent: String?
    private let startedAt = Date().timeIntervalSince1970

    init(systemUserAgent: String? = nil) { self.systemUserAgent = systemUserAgent }

    func prepare() async throws {
        try Task.checkCancellation()
        guard systemUserAgent == nil else { return }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        // Empty local page only: no URL load, cookies, injected account code or
        // access to the user's login WebView. Obtain this device's actual UA.
        let agent: String = try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript("navigator.userAgent") { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let value = value as? String, !value.isEmpty {
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(throwing: HTTPClientError.unavailable)
                }
            }
        }
        try Task.checkCancellation()
        withExtendedLifetime(webView) { systemUserAgent = agent }
    }

    func context(for api: NativeWriteAPI, authorization: SessionAuthorization,
                 account: TextWriteAccount?) throws -> NativeWriteRuntimeContext {
        guard let systemUserAgent else { throw NativeTextWriteClientError.invalidRuntimeContext }
        let agent = systemUserAgent + " tieba/\(Self.protocolVersion) uniqueId/(null) skin/(null)"
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let device = UIDevice.current
        let values = NativeWriteStaticCommonContext(
            clientVersion: Self.protocolVersion, systemVersion: device.systemVersion, deviceScore: nil,
            deviceFamily: device.model, devicePlatform: machine(), channel: nil, cuid: nil,
            legoVersion: nil, browserCuid: nil, browserInstanceID: nil, advertisingID: nil, sampleID: nil,
            vendorID: device.identifierForVendor?.uuidString, mac: nil, eventDay: nil, sdkVersion: nil,
            frameworkVersion: nil, gameVersion: nil, pureMode: nil, miniAppMode: nil, privacyPolicyShown: false,
            screenWidth: Double(scene?.screen.bounds.width ?? 0), screenHeight: Double(scene?.screen.bounds.height ?? 0),
            screenScale: Double(scene?.screen.scale ?? 0), imageQuality: 0)
        let dynamic = NativeWriteDynamicCommonContext(
            api: api.rawValue, sampleID: nil, hasBrowseModeProvider: false, browseMode: nil,
            clientID: nil, extra: nil, personalizedSwitch: nil, storedPersonalizedSwitch: nil,
            networkType: nil, userAgent: agent, sessionValue: authorization.bduss, secondaryValue: authorization.stoken,
            opaqueSDKValue: nil, tbs: account?.tbs, diac: nil, launchScheme: nil, launchType: 0,
            timestampSeconds: Date().timeIntervalSince1970, activeTimestampSeconds: startedAt,
            signOptimizationEnabled: false, signForumOnly: false, signAll: false, keepAlive: false, smallFlow: false)
        return NativeWriteRuntimeContext(
            common: .init(staticValues: values, staticMode: .recomputed, dynamicValues: dynamic,
                          metadata: .init(packageVersion: nil, experimentHits: nil, experimentMisses: nil)),
            http: .init(userAgent: agent, acceptLanguage: Locale.preferredLanguages.prefix(6).joined(separator: ", "),
                        clientLogID: 0, timeout: 25, responseState: nil,
                        cookies: .init(networkStatus: 0, wifiKeepAlive: false, cellularKeepAlive: false,
                                       smallFlow: false, smallFlowValue: nil)),
            multipartBoundary: String(format: "Boundary+%08X%08X", UInt32.random(in: .min ... .max), UInt32.random(in: .min ... .max)))
    }

    private func machine() -> String {
        var info = utsname()
        guard uname(&info) == 0 else { return UIDevice.current.model }
        return withUnsafeBytes(of: &info.machine) { bytes in
            String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8) ?? UIDevice.current.model
        }
    }
}

extension NativeLiveTextWriteRepository {
    static func production(auth: any AuthContextProviding) -> NativeLiveTextWriteRepository {
        let preferences = UserDefaults.standard
        let key = "nativeIOSWrite.didPrepareAccount.v1"
        let loader: any HTTPDataLoading
        let base = URLSessionDataLoader(configuration: URLSessionHTTPClient.makeEphemeralConfiguration())
#if DEBUG
        loader = DebugNativeWriteDataLoader(base: base, diagnostics: DebugNativeWriteDiagnostics())
#else
        loader = base
#endif
        return NativeLiveTextWriteRepository(
            auth: auth, loader: loader,
            runtime: NativeWriteAppRuntime(), firstLogin: { !preferences.bool(forKey: key) },
            didPrepareAccount: { preferences.set(true, forKey: key) })
    }
}
