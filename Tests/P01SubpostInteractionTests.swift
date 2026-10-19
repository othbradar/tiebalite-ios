import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct P01SubpostInteractionTests {
    @Test func footerDateUsesTimestampAndLocalDayWithoutInventingMissingDates() throws {
        let utc = try #require(TimeZone(secondsFromGMT: 0))
        let west = try #require(TimeZone(secondsFromGMT: -3_600))
        #expect(TiebaDateText.monthDay(seconds: 1_790_209_800, fallback: "old", timeZone: utc) == "09-24")
        #expect(TiebaDateText.monthDay(seconds: 1_790_209_800, fallback: "old", timeZone: west) == "09-23")
        #expect(TiebaDateText.monthDay(seconds: nil, fallback: "cached", timeZone: utc) == "cached")
        #expect(TiebaDateText.monthDay(seconds: 0, fallback: "", timeZone: utc).isEmpty)
    }

    @Test(arguments: [0, 1, 2, 3, 23])
    func previewLimitDoesNotDependOnReportedTotal(total: Int) {
        let template = R06ThreadFixtureRepository.post(threadID: 42, floor: 1, imageCount: 0)
        let count = total == 0 ? 2 : min(total, 5)
        let row = ThreadReaderPostRowModel(.init(
            floorNumber: 2, author: template.author, metadata: template.metadata, document: template.document,
            subposts: Array(template.subposts.prefix(count)), subpostTotal: total))
        #expect(row.inlineSubposts.count == min(count, 3))
        #expect(row.inlineSubposts.map(\.id) == Array(template.subposts.prefix(min(count, 3))).map(\.id))
        #expect(row.source.postID != row.inlineSubposts[0].id.postID)
    }

    @Test func quotedRecipientDoesNotReplaceClickedAuthorOrParentAndDraftIdentitiesStayDistinct() async throws {
        let route = SubpostsRoute(threadID: 8_001, postID: 9_002)
        let store = SubpostsStore(route: route, repository: FixtureSubpostsRepository())
        await store.loadIfNeeded()
        let item = try #require(store.snapshot?.items[1])
        let intent = try #require(store.replyIntent(for: item))
        let target = TextComposeTarget.reply(intent, document: item.document)
        #expect(target.threadID == 8_001 && target.postID == 9_002 && target.subpostID == 10_002)
        #expect(target.recipient?.rawUserID == 92 && target.recipient?.displayName == "样本回复者2")
        #expect(target.quote.hasPrefix("回复 固定样本用户："))
        #expect(target.isValid)
        let other = try #require(store.snapshot?.items[0])
        let otherTarget = TextComposeTarget.reply(try #require(store.replyIntent(for: other)), document: other.document)
        #expect(target.id != otherTarget.id)
        store.setReadAnchor(.reply(item.id))
        await store.loadNextPage()
        #expect(store.readAnchor == .reply(item.id))
        #expect(store.replyIntent(for: item) == intent)
    }

    @Test func optInBodyTapExcludesLinksAndSelectionAndUsesUpdatedCallback() throws {
        let source = ThreadContentSource(threadID: 42, postID: 901, scope: .subPost)
        let nodes = FixtureThreadReaderPages.actionLinks(source: source, ordinal: 0)
        let view = TiebaSelectableTextView()
        view.frame = CGRect(x: 0, y: 0, width: 380, height: 200)
        view.apply(runs: [.text("普通正文\n")] + TiebaRichText.runs(nodes: nodes), pointSize: 17, lineLimit: 0, interactive: true)
        let handler = TiebaTextBodyTap()
        var first = 0
        var second = 0
        view.onBodyTap = { first += 1 }
        handler.update(in: view, enabled: true)
        view.layoutIfNeeded()
        #expect(handler.acceptsBodyTap(at: CGPoint(x: 5, y: 8)))
        var linkIndex: Int?
        view.attributedText.enumerateAttribute(.link, in: NSRange(location: 0, length: view.attributedText.length)) { value, range, _ in
            if value != nil, linkIndex == nil { linkIndex = range.location }
        }
        let index = try #require(linkIndex)
        let start = try #require(view.position(from: view.beginningOfDocument, offset: index))
        let end = try #require(view.position(from: start, offset: 1))
        let range = try #require(view.textRange(from: start, to: end))
        let rect = view.firstRect(for: range)
        #expect(!handler.acceptsBodyTap(at: CGPoint(x: rect.midX, y: rect.midY)))
        view.selectedRange = NSRange(location: 0, length: 2)
        #expect(!handler.acceptsBodyTap(at: CGPoint(x: 5, y: 8)))
        view.onBodyTap = { second += 1 }
        #expect(view.selectedRange == NSRange(location: 0, length: 2))
        view.selectedRange = NSRange(location: 0, length: 0)
        #expect(view.accessibilityActivate())
        #expect(first == 0 && second == 1)
        view.onBodyTap = nil
        #expect(!handler.acceptsBodyTap(at: CGPoint(x: 5, y: 8)))
    }
}
