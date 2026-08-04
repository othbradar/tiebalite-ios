import SwiftUI
import WebKit

@MainActor
struct LoginWebView: UIViewRepresentable {
    let session: LoginWebSession
    let onCookiesDetected: (LoginCookieValues) -> Void
    let onIncompleteCookies: () -> Void
    let onNavigationFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCookiesDetected: onCookiesDetected,
            onIncompleteCookies: onIncompleteCookies,
            onNavigationFailure: onNavigationFailure
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = session.websiteDataStore
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = true
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.accessibilityIdentifier = SessionAccessibilityID.loginWebView
        if let loginURL = session.loginURL {
            webView.load(URLRequest(url: loginURL))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
    }

    static func dismantleUIView(
        _ webView: WKWebView,
        coordinator: Coordinator
    ) {
        coordinator.cancel()
        webView.stopLoading()
        webView.navigationDelegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onCookiesDetected: (LoginCookieValues) -> Void
        private let onIncompleteCookies: () -> Void
        private let onNavigationFailure: () -> Void
        private var completed = false

        init(
            onCookiesDetected: @escaping (LoginCookieValues) -> Void,
            onIncompleteCookies: @escaping () -> Void,
            onNavigationFailure: @escaping () -> Void
        ) {
            self.onCookiesDetected = onCookiesDetected
            self.onIncompleteCookies = onIncompleteCookies
            self.onNavigationFailure = onNavigationFailure
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else {
                return .cancel
            }
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
            if !isMainFrame, url.scheme?.lowercased() == "about" {
                return .allow
            }
            return LoginWebNavigationPolicy.allows(url) ? .allow : .cancel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            guard !completed,
                  let url = webView.url,
                  LoginWebNavigationPolicy.isCompletion(url) else {
                return
            }
            webView.configuration.websiteDataStore.httpCookieStore
                .getAllCookies { [weak self] cookies in
                    let records = Array(
                        cookies.lazy.filter { cookie in
                            let name = cookie.name.uppercased()
                            return name == "BDUSS" || name == "STOKEN"
                        }.map { cookie in
                            LoginCookieRecord(
                                name: cookie.name,
                                value: cookie.value,
                                domain: cookie.domain,
                                path: cookie.path,
                                isSecure: cookie.isSecure
                            )
                        }
                    )
                    Task { @MainActor [weak self] in
                        self?.consume(
                            LoginCookieValues.select(
                                from: records,
                                completionURL: url
                            )
                        )
                    }
                }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation?,
            withError error: any Error
        ) {
            reportNavigationFailure(error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation?,
            withError error: any Error
        ) {
            reportNavigationFailure(error)
        }

        private func consume(_ values: LoginCookieValues) {
            guard !completed else {
                return
            }
            guard values.credential != nil else {
                onIncompleteCookies()
                return
            }
            completed = true
            onCookiesDetected(values)
        }

        func cancel() {
            completed = true
        }

        private func reportNavigationFailure(_ error: any Error) {
            let error = error as NSError
            guard !completed,
                  error.domain != NSURLErrorDomain
                    || error.code != NSURLErrorCancelled else {
                return
            }
            onNavigationFailure()
        }
    }
}
