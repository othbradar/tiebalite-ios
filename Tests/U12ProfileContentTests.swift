import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

struct U12ProfileContentTests {
    @Test func nativeDescriptorFixturesMatchEncodedRequestsByteForByte() throws {
        let root = try #require(Bundle(for: U12FixtureBundleToken.self).url(forResource: "Fixtures", withExtension: nil))
        let bytes = try Data(contentsOf: root.appendingPathComponent("API/UserProfile/native-ios.json"))
        let fixture = try JSONDecoder().decode(NativeFixture.self, from: bytes)
        let user = try #require(UserProfileRoute(userID: 42, fallbackDisplayName: "Fixture"))
        for sample in fixture.requests {
            let cursor: ProfileCursor? = sample.business["pn"] == "2" ? .init(page: 2, lastThreadTime: 1234) : nil
            #expect(try NativeProfileProtocol.business(.init(user: user, section: sample.section),
                                                       cursor: cursor, accountID: 42) == sample.business)
            #expect(try NativeProfileProtocol.encode(sample.business, common: sample.common) == Data(base64Encoded: sample.wireBase64))
        }
        let first = try #require(Data(base64Encoded: fixture.responses[0]))
        #expect(try NativeProfileProtocol.posts(first, section: .threads, cursor: nil).posts.map(\.id) == [110])
    }

    @Test func ownRepliesCannotBeRequestedForAnotherAccount() throws {
        let user = try #require(UserProfileRoute(userID: 42, fallbackDisplayName: "Fixture"))
        #expect(throws: ProfileContentFailure.privateContent) {
            try NativeProfileProtocol.business(.init(user: user, section: .replies), cursor: nil, accountID: 9)
        }
        let fields = try NativeProfileProtocol.business(.init(user: user, section: .threads), cursor: nil, accountID: 9)
        #expect(fields["is_thread"] == "1")
        #expect(fields["rn"] == "20")
    }

    @Test func replyIdentityAndPagingSurviveMissingFieldsAndDeletedRows() throws {
        var response = TiebaNativeProfiles_Response()
        response.error.errorno = 0
        var post = TiebaNativeProfiles_Post()
        post.threadID = 110; post.postID = 111; post.userID = 42; post.title = "Fixture"
        var second = post
        second.postID = 112
        var image = Tieba_Media()
        image.bigPic = "https://fixture.invalid/image.png"
        post.media = [try image.serializedData()]; second.media = post.media
        var deleted = post
        deleted.postID = 113; deleted.isPostDeleted = 1
        response.data.postList = [post, second, deleted]
        let page = try NativeProfileProtocol.posts(response.serializedData(), section: .replies, cursor: nil)
        #expect(page.posts.map(\.id) == [111, 112])
        #expect(page.posts.map(\.summary.threadID) == [110, 110])
        #expect(page.next?.page == 2)
        #expect(page.posts[0].summary.thumbnailResources.first?.resourceID
                != page.posts[1].summary.thumbnailResources.first?.resourceID)
    }

    @Test func privateContentAndMissingRelationshipAreNotSuccessfulEmptyStates() throws {
        var response = TiebaNativeProfiles_Response()
        response.data.hidePost = 1
        #expect(throws: ProfileContentFailure.privateContent) {
            try NativeProfileProtocol.posts(response.serializedData(), section: .threads, cursor: nil)
        }
        let bytes = Data(#"{"error_code":"0","user":{"id":"42","fans_num":"999"}}"#.utf8)
        let relation = try NativeProfileProtocol.relationship(bytes, userID: 42)
        #expect(relation.isFollowed == nil)
        #expect(relation.portrait == nil)
    }

    private struct NativeFixture: Decodable {
        let requests: [NativeProfileRequestFixture]
        let responses: [String]
    }
}

private final class U12FixtureBundleToken: NSObject {}
private struct NativeProfileRequestFixture: Decodable {
    let section: ProfileSection
    let business: [String: String]
    let common: [String: String]
    let wireBase64: String
}
