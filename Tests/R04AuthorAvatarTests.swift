import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

struct R04AuthorAvatarTests {
    private static let base = "http://tb.himg.baidu.com/sys/portrait/item/"

    @Test(arguments: ["tb.1.fixture_avatar-1", "tb.1.fixture_avatar-1?t=1700000000",
                      "http://tb.himg.baidu.com/sys/portrait/item/tb.1.fixture_avatar-1"])
    func dynamicAuthorPortraitBecomesTheAndroidAvatarRequest(_ portrait: String) throws {
        var thread = Tieba_ThreadInfo()
        thread.id = 101
        thread.author.id = 202
        thread.author.portrait = portrait
        var response = Tieba_PersonalizedResponse()
        response.data.threadList = [thread]
        let decoded = try PersonalizedProtocol.decode(response.serializedData())
        let item = try #require(PersonalizedProtocol.map(decoded, requestedPage: 1).items.first)
        let resource = try #require(item.author?.visuals?.avatarResource)
        #expect(resource.resourceID == "user.202.avatar")
        #expect(resource.candidateURLs == [portrait.hasPrefix("http://") ? portrait : Self.base + portrait])
    }

    @Test(arguments: [
        "", "..", "../other", "a/b", "a%2Fb", "a%2eb", "a#fragment", "a?other=1",
        "a?t=", "a?t=1&next=2", "a?t=-1", "a\\b", "//fixture.invalid/a",
        "http://fixture.invalid/sys/portrait/item/a",
        "http://sub.tb.himg.baidu.com/sys/portrait/item/a",
        "http://tb.himg.baidu.com.fixture.invalid/sys/portrait/item/a",
        "http://tb.himg.baidu.com/a", "http://tb.himg.baidu.com/sys/portraith/item/a",
        "http://tb.himg.baidu.com/sys/portrait/item/", "http://tb.himg.baidu.com/sys/portrait/item/a/b",
        "http://tb.himg.baidu.com/sys/portrait/item/%2e%2e",
        "http://tb.himg.baidu.com:80/sys/portrait/item/a",
        "http://user:pass@tb.himg.baidu.com/sys/portrait/item/a",
        "http://tb.himg.baidu.com/sys/portrait/item/a#fragment"
    ])
    func unapprovedPortraitAddressesStayUnavailable(_ value: String) {
        #expect(TiebaAvatarResource.user(userID: 202, portrait: value) == nil)
        if value.hasPrefix("http://") {
            #expect(!ImageResourceDescriptor(resourceID: "fixture.avatar", candidateURLs: [value]).isNetworkLoadable)
        }
    }

    @Test
    func avatarRequestUsesTheExistingAnonymousLoaderAndCache() async throws {
        let resource = try #require(TiebaAvatarResource.user(userID: 202, portrait: "tb.1.fixture_avatar-1"))
        let url = try #require(URL(string: Self.base + "tb.1.fixture_avatar-1"))
        let transport = HarnessImageDataLoader(outcomes: [url: [.response(
            statusCode: 200, headers: ["Content-Type": "image/png"],
            body: try TestImageFixtureFactory.png(width: 120, height: 120)
        )]])
        let loader = ProductionImageLoader(loader: transport)
        let request = ImageRequest(resource: resource, targetPixelSize: .init(width: 72, height: 72),
                                   purpose: .avatar, resizeMode: .fill)
        #expect(try await loader.load(request).decodedImage != nil)
        #expect(try await loader.load(request).decodedImage != nil)
        let requests = await transport.recordedRequests()
        #expect(requests.count == 1)
        let sent = try #require(requests.first)
        #expect(sent.url == url)
        #expect(sent.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(sent.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(!sent.httpShouldHandleCookies)
        let configuration = ProductionImageLoader.makeURLSessionConfiguration()
        #expect(configuration.httpCookieStorage == nil)
        #expect(!configuration.httpShouldSetCookies)
        #expect(configuration.urlCredentialStorage == nil)
    }

    @Test
    func completeHTTPSPortraitIsNeverDowngradedAndChangedPortraitInvalidatesOnlyItsImage() throws {
        let secure = "https://tb.himg.baidu.com/sys/portrait/item/fixture"
        #expect(TiebaAvatarResource.user(userID: 202, portrait: secure)?.candidateURLs == [secure])
        let first = try #require(TiebaAvatarResource.user(userID: 202, portrait: "fixture-a"))
        let second = try #require(TiebaAvatarResource.user(userID: 202, portrait: "fixture-b"))
        #expect(first.resourceID == second.resourceID)
        let target = ImageTargetPixelSize(width: 72, height: 72)
        let firstRequest = ImageRequest(resource: first, targetPixelSize: target, purpose: .avatar, resizeMode: .fill)
        let secondRequest = ImageRequest(resource: second, targetPixelSize: target, purpose: .avatar, resizeMode: .fill)
        #expect(firstRequest.stableCacheKey != secondRequest.stableCacheKey)
    }

    @Test(arguments: ["http://tb.himg.baidu.com/other/fixture",
                      "http://fixture.invalid/sys/portrait/item/fixture"])
    func directImageRequestsCannotBypassTheHTTPPathBoundary(_ candidate: String) async {
        let transport = HarnessImageDataLoader(outcomes: [:])
        let loader = ProductionImageLoader(loader: transport)
        await #expect(throws: ImageLoadingError.invalidCandidate) {
            _ = try await loader.load(ImageRequest(resourceID: "fixture.avatar", candidateURLs: [candidate], purpose: .avatar))
        }
        #expect(await transport.recordedRequests().isEmpty)
    }

    @Test
    func appTransportExceptionIsLimitedToTheApprovedHost() throws {
        let ats = try #require(Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") as? [String: Any])
        #expect(ats["NSAllowsArbitraryLoads"] == nil)
        #expect(ats["NSAllowsArbitraryLoadsInWebContent"] == nil)
        #expect(ats["NSAllowsArbitraryLoadsForMedia"] == nil)
        let domains = try #require(ats["NSExceptionDomains"] as? [String: [String: Any]])
        #expect(Set(domains.keys) == ["tb.himg.baidu.com"])
        let portrait = try #require(domains["tb.himg.baidu.com"])
        #expect(portrait["NSExceptionAllowsInsecureHTTPLoads"] as? Bool == true)
        #expect(portrait["NSIncludesSubdomains"] as? Bool == false)
    }
}
