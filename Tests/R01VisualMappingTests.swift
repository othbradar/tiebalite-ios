import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

struct R01VisualMappingTests {
    @Test
    func protobufAuthorPreservesRealFieldsAndAbsentLevel() {
        let user = makeUser()
        let author = TiebaUserVisualMapper.map(user)
        #expect(author.rawUserID == 101)
        #expect(author.displayName == "显示名称")
        #expect(author.portrait == user.portrait)
        #expect(author.levelID == 14)
        #expect(author.moderatorLabel == "吧主")
        #expect(author.isThreadAuthor(101))
        #expect(!author.isThreadAuthor(102))
        #expect(TiebaUserVisualMapper.map(Tieba_User()).levelID == nil)
    }

    @Test
    func personalizedRetainsAuthorAndForumImageWithoutChangingFeedIdentity() throws {
        var thread = Tieba_ThreadInfo()
        thread.id = 201
        thread.threadID = 301
        thread.author = makeUser()
        thread.forumID = 401
        thread.forumInfo.avatar = "https://images.fixture.invalid/forum.jpg"
        var response = Tieba_PersonalizedResponse()
        response.data.threadList = [thread]
        let page = try PersonalizedProtocol.map(response, requestedPage: 1)
        let item = try #require(page.items.first)
        #expect(item.rawFeedID == 201)
        #expect(item.rawThreadID == 301)
        #expect(item.author?.visuals?.levelID == 14)
        #expect(item.author?.visuals?.avatarResource?.isNetworkLoadable == true)
        #expect(item.forumAvatarResource?.candidateURLs == ["https://images.fixture.invalid/forum.jpg"])
    }

    @Test
    func pbPageAuthorsKeepPortraitLevelAndRolesAcrossUserListFallback() throws {
        var response = Tieba_PbPage_PbPageResponse()
        response.data.thread.id = 301
        response.data.thread.author = makeUser()
        response.data.page.currentPage = 1
        response.data.page.hasMore_p = 0
        var post = Tieba_Post()
        post.id = 501
        post.floor = 1
        post.authorID = 101
        response.data.userList = [makeUser()]
        response.data.postList = [post]
        let mapped = try PBPageDomainMapper.map(response, request: .initial(threadID: 301))
        #expect(mapped.author.levelID == 14)
        #expect(mapped.posts.first?.author == mapped.author)
        #expect(mapped.posts.first?.author.portrait == makeUser().portrait)
        #expect(mapped.posts.first?.author.moderatorLabel == "吧主")
    }

    @Test
    func frsKeepsRealForumLevelAndAuthorLookupPriority() throws {
        let route = try #require(ForumRoute(forumID: 401, forumName: "样本吧"))
        var response = Tieba_FrsPage_FrsPageResponse()
        response.data.forum.id = 401
        response.data.forum.name = "样本吧"
        response.data.forum.avatar = "https://images.fixture.invalid/forum.jpg"
        response.data.forum.userLevel = 8
        response.data.forum.levelName = "八级"
        response.data.forum.memberNum = 321
        var thread = Tieba_ThreadInfo()
        thread.id = 201
        thread.threadID = 301
        thread.authorID = 101
        thread.author = makeUser()
        thread.author.levelID = 18
        response.data.threadList = [thread]
        response.data.userList = [makeUser()]
        let mapped = try FRSPageProtocol.map(response, requestedRoute: route)
        #expect(mapped.forum.levelID == 8)
        #expect(mapped.forum.levelName == "八级")
        #expect(mapped.forum.memberCount == 321)
        #expect(mapped.threads.first?.id == 301)
        #expect(mapped.threads.first?.author?.levelID == 14)
        response.data.forum.userLevel = 0
        response.data.userList = []
        response.data.threadList[0].clearAuthor()
        let absent = try FRSPageProtocol.map(response, requestedRoute: route)
        #expect(absent.forum.levelID == nil)
        #expect(absent.threads.first?.author?.rawUserID == 101)
        #expect(absent.threads.first?.author?.levelID == nil)
    }

    @Test
    func profileKeepsPublicVisualFieldsOnly() throws {
        let route = try #require(UserProfileRoute(userID: 101, fallbackDisplayName: "样本"))
        var response = Tieba_Profile_ProfileResponse()
        response.data.user = makeUser()
        let profile = try ProfileProtocol.map(response, requestedRoute: route)
        #expect(profile.visuals?.levelID == 14)
        #expect(profile.visuals?.portrait == profile.portraitResourceID)
        response.data.user.name = ""
        response.data.user.nameShow = ""
        response.data.user.portrait = ""
        let fallbackRoute = try #require(UserProfileRoute(
            userID: 101, fallbackDisplayName: "路由名称",
            portraitResourceID: "https://images.fixture.invalid/route.jpg"
        ))
        let fallback = try ProfileProtocol.map(response, requestedRoute: fallbackRoute)
        #expect(fallback.visuals?.displayName == fallback.displayName)
        #expect(fallback.visuals?.portrait == fallback.portraitResourceID)
    }

    @Test
    func searchMapsOnlyProvidedIdentityAndHTTPSImagesWithNoInventedLevel() throws {
        let forums = Data("""
        {"no":0,"data":{"exactMatch":{"forum_id":401,"forum_name":"样本吧",
        "avatar":"https://images.fixture.invalid/forum.jpg"},"fuzzyMatch":[]}}
        """.utf8)
        #expect(try SearchWebProtocol.mapForumFixture(forums).first?.avatarResource?.isNetworkLoadable == true)
        let threads = Data("""
        {"no":0,"data":{"current_page":1,"has_more":0,"post_list":[
        {"tid":"301","forum_id":401,"forum_name":"样本吧","user":{"user_id":"101",
        "show_nickname":"显示名称","portrait":"https://images.fixture.invalid/user.jpg"},
        "forum_info":{"avatar":"https://images.fixture.invalid/forum.jpg"}},
        {"tid":"302"}]}}
        """.utf8)
        let keyword = try #require(SearchKeyword("样本"))
        let page = try SearchWebProtocol.mapThreadFixture(threads, keyword: keyword, requestedPage: 1)
        #expect(page.items[0].author?.rawUserID == 101)
        #expect(page.items[0].author?.levelID == nil)
        #expect(page.items[0].author?.avatarResource?.isNetworkLoadable == true)
        #expect(page.items[0].forumAvatarResource?.isNetworkLoadable == true)
        #expect(page.items[1].author == nil)
        #expect(page.items[1].forumAvatarResource == nil)
    }

    private func makeUser() -> Tieba_User {
        var user = Tieba_User()
        user.id = 101
        user.name = "wire_name"
        user.nameShow = "显示名称"
        user.portrait = "https://images.fixture.invalid/user.jpg"
        user.levelID = 14
        user.isBawu = 1
        user.bawuType = "manager"
        return user
    }
}
