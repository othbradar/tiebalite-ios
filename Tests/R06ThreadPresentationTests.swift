import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

struct R06ThreadPresentationTests {
    @Test
    func previewsKeepOnlyFirstThreeInServerOrder() {
        let source = ThreadContentSource(threadID: 42, postID: 100, scope: .post)
        let subposts = [9, 3, 7, 2, 1].map { id in
            ThreadReaderSubpost(
                parentPostID: 100, author: .init(rawUserID: Int64(id), displayName: "用户\(id)"),
                metadata: "固定时间",
                document: .init(source: .init(threadID: 42, postID: Int64(id), scope: .subPost),
                                availability: .available, nodes: [], poll: nil)
            )
        }
        let row = ThreadReaderPostRowModel(.init(
            floorNumber: 2, author: .init(rawUserID: 1, displayName: "作者"), metadata: "固定时间",
            document: .init(source: source, availability: .available, nodes: [], poll: nil),
            subposts: subposts, subpostTotal: 12
        ))
        #expect(row.inlineSubposts.map(\.id.postID) == [9, 3, 7])
        #expect(row.remainingSubpostCount == 9)
        #expect(row.totalSubpostCount == 12)
    }
    @Test
    func imageGroupsStopAtEveryNonImageAndKeepViewerIndex() throws {
        let post = R06ThreadFixtureRepository.post(threadID: 42, floor: 1, imageCount: 8)
        let pictures = Array(post.document.nodes.dropFirst())
        let separator = post.document.nodes[0]
        let blocks = ThreadContentBlock.make(Array(pictures.prefix(4)) + [separator] + pictures.suffix(4))
        #expect(blocks.count == 3)
        guard case let .images(first) = blocks[0], case let .images(second) = blocks[2] else {
            Issue.record("Expected two separate image groups")
            return
        }
        #expect(first.map(\.id.ordinal) == [1, 2, 3, 4])
        #expect(second.map(\.id.ordinal) == [5, 6, 7, 8])
        let selected = ThreadMediaID(sourceNodeID: second[2].id)
        let intent = try #require(ThreadContentBlock.mediaIntent(nodes: second, selecting: selected))
        #expect(intent.items.map(\.sourceNodeID.ordinal) == [5, 6, 7, 8])
        #expect(intent.items.firstIndex { $0.mediaID == intent.initialMediaID } == 2)
        #expect(ThreadContentBlock.mediaIntent(nodes: first, selecting: selected) == nil)
        // Every content node keeps its original identity in the media intent.
        #expect(post.document.mediaIntent(selecting: .init(sourceNodeID: pictures[7].id))?.items.count == 8)
    }

    @Test(arguments: [1, 2, 3, 4, 5, 8])
    func proportionalGridKeepsAllFramesInsideWidthAndPreservesRatios(count: Int) {
        let ratios = (0..<count).map { $0.isMultiple(of: 2) ? 1.5 : 1.125 }
        for width in [320.0, 680.0] {
            let grid = TiebaMediaGridGeometry(count: count, width: width, aspectRatios: ratios)
            #expect(grid.frames.count == count)
            #expect(grid.rowCounts.allSatisfy { $0 <= 4 })
            for (frame, ratio) in zip(grid.frames, ratios) {
                #expect(abs(frame.width / frame.height - ratio) < 0.001)
                #expect(frame.maxX <= width + 0.001)
                #expect(frame.maxY <= grid.height + 0.001)
            }
            if count == 4 { #expect(grid.rowCounts == [2, 2]) }
            if count == 5 { #expect(grid.rowCounts == [3, 2]) }
        }
    }

    @Test
    func floorFieldsComeFromPBPageAndMissingFieldsStayAbsent() throws {
        var response = Tieba_PbPage_PbPageResponse()
        response.data.thread.id = 42
        response.data.forum.id = 7
        response.data.forum.name = "真实字段吧"
        response.data.forum.avatar = "https://fixture.invalid/forum/7.png"
        response.data.page.currentPage = 1
        var author = Tieba_User()
        author.id = 8
        author.nameShow = "接口作者"
        author.portrait = "verified-token"
        author.levelID = 14
        author.ipAddress = "辽宁"
        author.isBawu = 1
        author.bawuType = "manager"
        response.data.thread.author = author
        response.data.firstFloorPost.id = 100
        response.data.firstFloorPost.floor = 1
        response.data.firstFloorPost.author = author
        response.data.firstFloorPost.agree.diffAgreeNum = 12
        let snapshot = try PBPageDomainMapper.map(response, request: .initial(threadID: 42))
        #expect(snapshot.forumAvatarResource == TiebaAvatarResource.forum(
            forumID: 7, avatar: "https://fixture.invalid/forum/7.png"
        ))
        let presentation = ThreadReaderListPresentation(snapshot: snapshot, pagination: .end)
        #expect(presentation.rows.map(\.id) == [.firstPost(threadID: 42, postID: 100), .end(threadID: 42)])
        let post = try #require(snapshot.posts.first)
        let row = ThreadReaderPostRowModel(post, threadAuthorID: 8)
        #expect(row.author.levelID == 14)
        #expect(row.author.portrait == "verified-token")
        #expect(row.author.ipLocation == "辽宁")
        #expect(row.author.moderatorLabel == "吧主")
        #expect(row.isThreadAuthor)
        #expect(row.agreeCount == 12)
        let missing = TiebaUserVisualMapper.map(Tieba_User())
        #expect(missing.levelID == nil && missing.ipLocation == nil && missing.avatarResource == nil)
        response.data.firstFloorPost.clearAgree()
        response.data.clearForum()
        let absent = try PBPageDomainMapper.map(response, request: .initial(threadID: 42))
        #expect(absent.posts.first?.agreeCount == nil)
        #expect(absent.forumAvatarResource == nil)
    }

    @Test
    func noAllRepliesLinkWhenAllThreeArePresent() {
        let post = R06ThreadFixtureRepository.post(threadID: 42, floor: 2, imageCount: 5)
        let row = ThreadReaderPostRowModel(post)
        #expect(row.inlineSubposts.count == 3)
        #expect(row.remainingSubpostCount == 0)
    }

}
