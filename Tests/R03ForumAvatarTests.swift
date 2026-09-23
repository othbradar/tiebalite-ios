import Foundation
import Testing
@testable import TiebaLite

struct R03ForumAvatarTests {
    private let source = "http://tiebapic.baidu.com/forum/w=120;h=120/sign=synthetic/sample.jpg?size=120&v=a%2Bb"

    @Test
    func verifiedForumCDNUsesHTTPSWithoutChangingResourcePathOrQuery() throws {
        let resource = try #require(TiebaAvatarResource.forum(forumID: 8, avatar: source))
        #expect(resource.resourceID == "forum.8.avatar")
        #expect(resource.candidateURLs == ["https:" + source.dropFirst(5)])
        #expect(TiebaAvatarResource.user(userID: 8, portrait: source) == nil)
        let direct = "https://other.fixture.invalid/already-secure.png"
        #expect(TiebaAvatarResource.forum(forumID: 8, avatar: direct)?.candidateURLs == [direct])
    }

    @Test(arguments: [
        "portrait-token",
        "http://unknown.fixture.invalid/forum/w=120;h=120/sample.jpg",
        "http://tiebapic.baidu.com.evil.invalid/forum/w=120;h=120/sample.jpg",
        "http://tiebapic.baidu.com/unverified/sample.jpg",
        "http://tiebapic.baidu.com:8080/forum/w=120;h=120/sample.jpg",
        "http://user:pass@tiebapic.baidu.com/forum/w=120;h=120/sample.jpg",
        "http://tiebapic.baidu.com/forum/w=120;h=120/sample.jpg#fragment"
    ])
    func unverifiedOrAmbiguousAddressesStayAbsent(_ address: String) {
        #expect(TiebaAvatarResource.forum(forumID: 8, avatar: address) == nil)
    }

    @Test
    func percentEncodedForumGuidePathKeepsItsExactBytes() throws {
        let encoded = source.replacingOccurrences(of: "w=120;h=120", with: "w%3D120%3Bh%3D120")
        let resource = try #require(TiebaAvatarResource.forum(forumID: 8, avatar: encoded))
        #expect(resource.candidateURLs == ["https:" + encoded.dropFirst(5)])
    }

    @Test
    func legacyForumCDNUsesItsExistingPathOverHTTPS() throws {
        let legacy = "http://imgsrc.baidu.com/forum/pic/item/synthetic.jpg?source=fixture%2Bsample"
        let resource = try #require(TiebaAvatarResource.forum(forumID: 9, avatar: legacy))
        #expect(resource.candidateURLs == ["https:" + legacy.dropFirst(5)])
        #expect(TiebaAvatarResource.forum(forumID: 9, avatar: "http://imgsrc.baidu.com/unknown/a.jpg") == nil)
        #expect(TiebaAvatarResource.forum(forumID: 9, avatar: "http://tiebapic.baidu.com/forum/pic/a.jpg") == nil)
        #expect(TiebaAvatarResource.user(userID: 9, portrait: legacy) == nil)
    }

    @Test
    func mappedForumImageUsesExistingAnonymousLoader() async throws {
        let resource = try #require(TiebaAvatarResource.forum(forumID: 8, avatar: source))
        let candidate = try #require(resource.candidateURLs.first)
        let url = try #require(URL(string: candidate))
        let transport = HarnessImageDataLoader(outcomes: [
            url: [.response(statusCode: 200, headers: ["Content-Type": "image/png"],
                            body: try TestImageFixtureFactory.png(width: 40, height: 40))]
        ])
        let loader = ProductionImageLoader(loader: transport)
        let payload = try await loader.load(ImageRequest(
            resource: resource, targetPixelSize: ImageTargetPixelSize(width: 40, height: 40),
            purpose: .avatar, resizeMode: .fill
        ))
        #expect(payload.decodedImage != nil)
        let requests = await transport.recordedRequests()
        let request = try #require(requests.first)
        #expect(requests.count == 1)
        #expect(request.url == url)
        #expect(request.url?.scheme == "https")
        #expect(request.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(!request.httpShouldHandleCookies)
    }
}
