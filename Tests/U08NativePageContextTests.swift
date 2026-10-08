import Testing
@testable import TiebaLite

@MainActor
struct U08NativePageContextTests {
    @Test func threadContextKeepsServerReplyCountWithoutChangingFloorOrDraftIdentity() async throws {
        let store = ThreadReaderStore(threadID: 140_006, repository: FixtureThreadReaderRepository())
        await store.loadIfNeeded()
        let snapshot = try #require(store.state.snapshot)
        var target = TextComposeTarget.reply(snapshot: snapshot, readingEntry: .forum)
        #expect(target.replyCount == Int(snapshot.replyCount))
        #expect(target.readingEntry == .forum)
        let identity = target.id
        target.replyCount = 81
        target.readingEntry = .history
        #expect(target.id == identity)
        let fields = try NativeTextWriteParameters.reply(
            .init(target: target, draft: .init(content: "Fixture")), preparedContent: "Fixture",
            account: .init(userID: "42", tbs: "fixture-tbs"),
            context: .init(container: .threadPage, pageEntryType: 0, floorNumber: "0", replyCount: target.replyCount.map(String.init)))
        #expect(fields["floor"] == "81" && fields["floor_num"] == "0")
    }

    @Test func subpostContextUsesParentReplyTotalAndFreezesAtEditorOpening() async throws {
        let store = SubpostsStore(route: .init(threadID: 8_001, postID: 9_002), repository: FixtureSubpostsRepository())
        await store.loadIfNeeded()
        let item = try #require(store.snapshot?.items.first)
        let intent = try #require(store.replyIntent(for: item))
        let target = TextComposeTarget.reply(intent, document: item.document, readingEntry: .recommendations)
        #expect(target.readingEntry == .recommendations)
        #expect(target.id == TextComposeTarget.reply(intent, document: item.document).id)
        #expect(target.replyCount == store.snapshot?.totalCount)
        #expect(target.replyCount != store.snapshot?.items.count)
        await store.loadNextPage()
        #expect(target.replyCount == intent.replyCount)
        #expect(target.postID == store.route.postID && target.subpostID == item.id)
    }
}
