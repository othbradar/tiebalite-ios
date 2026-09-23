import Testing
@testable import TiebaLite

struct R01VisualPrimitivesTests {
    @Test
    func avatarOnlyConsumesAnEvidenceBackedHTTPSValue() {
        #expect(TiebaAvatarResource.user(userID: 1, portrait: "portrait-token") == nil)
        #expect(TiebaAvatarResource.user(userID: 1, portrait: "http://tb.himg.baidu.com/a") == nil)
        #expect(TiebaAvatarResource.user(userID: 1, portrait: "https://user:pass@fixture.invalid/a") == nil)
        let first = TiebaAvatarResource.user(userID: 1, portrait: "https://images.fixture.invalid/a")
        let second = TiebaAvatarResource.user(userID: 1, portrait: "https://images.fixture.invalid/b")
        #expect(first?.resourceID == second?.resourceID)
        #expect(first != second)
        #expect(first?.candidateURLs == ["https://images.fixture.invalid/a"])
    }

    @Test
    func absentLevelsAndUnknownAuthorIdentityStayAbsent() {
        let user = TiebaUserVisuals(rawUserID: 0, displayName: "未知", levelID: 0)
        #expect(user.levelID == nil)
        #expect(user.moderatorLabel == nil)
        #expect(!user.isThreadAuthor(0))
    }

    @Test(arguments: [
        (1, [1]), (2, [2]), (3, [3]), (4, [2, 2]),
        (5, [3, 2]), (6, [3, 3]), (7, [3, 3, 1]), (8, [3, 3, 2])
    ])
    func mediaFormsCompactRows(count: Int, expected: [Int]) {
        let layout = TiebaMediaGridGeometry(count: count, width: 360)
        #expect(layout.rowCounts == expected)
        #expect(layout.frames.count == count)
        #expect(layout.frames.allSatisfy { $0.maxX <= 360 && $0.maxY <= layout.height })
        if count > 1 {
            #expect(layout.frames[0].minY == layout.frames[1].minY)
        }
        if count == 3 { #expect(layout.rowCounts == [3]) }
        if count == 2 || count == 3 { #expect(layout.height == 120) }
    }

    @Test
    func gridRejectsInvalidGeometryWithoutChangingItemOrder() {
        #expect(TiebaMediaGridGeometry.proposedWidth(.infinity).isFinite)
        #expect(TiebaMediaGridGeometry.proposedWidth(-10) == 0)
        #expect(TiebaMediaGridGeometry(count: 0, width: 320).frames.isEmpty)
        #expect(TiebaMediaGridGeometry(count: 8, width: .infinity).frames.isEmpty)
        #expect(TiebaMediaGridGeometry(count: 8, width: 0).frames.isEmpty)
        let layout = TiebaMediaGridGeometry(count: 8, width: 390)
        #expect(layout.frames[3].minX == 0)
        #expect(layout.frames[6].minX == 0)
        #expect(layout.frames[7].minX > layout.frames[6].minX)
    }
}
