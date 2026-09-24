import Foundation
import GeneratedProtobuf
import SwiftProtobuf

// Fixed synthetic wire messages; no captured personal data or service dependency.
enum R08PBFloorFixture {
    static func bytes(page: Int) throws -> Data {
        var response = Tieba_PbFloor_PbFloorResponse()
        response.data.page.currentPage = Int32(page)
        response.data.page.totalPage = 2
        response.data.page.totalCount = 30
        response.data.page.hasMore_p = 0  // Android uses current/total; contradictory hint must not truncate page 1.
        response.data.thread.id = 8_001
        response.data.thread.author = user(91)
        response.data.forum.id = 90
        response.data.forum.name = "固定样本吧"
        response.data.post.id = 9_002
        response.data.post.floor = 2
        response.data.post.author = user(91)
        response.data.post.content = [content(0, text: "父楼层 #滑稽")]
        let range = page == 1 ? 1...15 : 15...30
        response.data.subpostList = range.map { index in
            var item = Tieba_SubPostList()
            item.id = UInt64(10_000 + index)
            item.author = user(Int64(90 + index))
            item.authorID = item.author.id
            item.time = 1_790_209_800 + UInt32(index) * 60
            item.content = [
                content(0, text: "回复 "), content(4, text: "@固定用户"), content(0, text: "：第\(index)条"),
                content(2, text: "image_emoticon91", alternative: "微微一笑")
            ]
            if index == 30 {
                var image = content(3, text: "")
                image.originSrc = "https://fixture.invalid/subpost-image.png"
                image.src = image.originSrc
                image.width = 800
                image.height = 600
                item.content = [content(0, text: "图片回复"), image]
            }
            return item
        }
        return try response.serializedData()
    }

    private static func user(_ id: Int64) -> Tieba_User {
        var user = Tieba_User()
        user.id = id
        user.nameShow = "固定用户\(id)"
        user.levelID = 14
        user.portrait = "https://fixture.invalid/avatar/\(id)"
        return user
    }

    private static func content(_ type: Int32, text: String, alternative: String = "") -> Tieba_PbContent {
        var content = Tieba_PbContent()
        content.type = type
        content.text = text
        content.c = alternative
        return content
    }
}
