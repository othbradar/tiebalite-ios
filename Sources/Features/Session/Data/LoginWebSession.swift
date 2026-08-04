import Foundation
import WebKit

@MainActor
final class LoginWebSession: SessionWebsiteDataCleaning {
    let loginURL: URL?
    private(set) var websiteDataStore = WKWebsiteDataStore.nonPersistent()

    init(loginURL: URL? = LoginWebNavigationPolicy.loginURL) {
        self.loginURL = loginURL
    }

    func prepareForLogin() {
        websiteDataStore = WKWebsiteDataStore.nonPersistent()
    }

    func clearSessionWebsiteData() async {
        let dataStore = websiteDataStore
        await withCheckedContinuation { continuation in
            dataStore.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: .distantPast
            ) {
                continuation.resume()
            }
        }
        websiteDataStore = WKWebsiteDataStore.nonPersistent()
    }
}
