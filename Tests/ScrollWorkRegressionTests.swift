import Observation
import Synchronization
import Testing
@testable import TiebaLite
import UIKit

extension SFScrollTests {
    @MainActor @Suite(.serialized)
    struct ScrollWorkRegressionTests {
        @Test func repeatedTextSizingReusesActualMeasurement() {
            let text = TiebaSelectableTextView()
            text.apply(runs: [.text(String(repeating: "测试正文与表情 ", count: 60))], pointSize: 17, lineLimit: 0, interactive: true)
            let proposal = CGSize(width: 280, height: CGFloat.greatestFiniteMagnitude)
            ScrollWorkMetrics.start()
            let first = text.sizeThatFits(proposal)
            for _ in 0..<30 { #expect(text.sizeThatFits(proposal) == first) }
            let counts = ScrollWorkMetrics.stop()
            // The actual UIKit measurement count is added in SF-01, not calls to this test helper.
            #expect(counts["text.cacheHit", default: 0] == 30)
            text.apply(runs: [.text("短")], pointSize: 17, lineLimit: 0, interactive: true)
            #expect(text.sizeThatFits(proposal).height < first.height)
        }

        @Test func measuredTextInvalidatesForActualStorageAndLayoutChanges() {
            let text = TiebaSelectableTextView()
            let long = String(repeating: "正文选择与换行。", count: 80)
            text.apply(runs: [.text("短文")], pointSize: 17, lineLimit: 0, interactive: true)
            let proposal = CGSize(width: 280, height: CGFloat.greatestFiniteMagnitude)
            let short = text.sizeThatFits(proposal)
            text.attributedText = NSAttributedString(string: long, attributes: [.font: UIFont.systemFont(ofSize: 17)])
            let tall = text.sizeThatFits(proposal)
            #expect(tall.height > short.height)
            text.textStorage.addAttribute(.font, value: UIFont.systemFont(ofSize: 26),
                                          range: NSRange(location: 0, length: text.textStorage.length))
            #expect(text.sizeThatFits(proposal).height > tall.height)
            for width in [200.0, 340.0] {
                for limit in [0, 3] {
                    text.apply(runs: [.text(long)], pointSize: 22, lineLimit: limit, interactive: true)
                    text.textContainerInset = .init(top: 3, left: 4, bottom: 7, right: 5)
                    text.textContainer.lineFragmentPadding = 2
                    let fresh = TiebaSelectableTextView()
                    fresh.apply(runs: [.text(long)], pointSize: 22, lineLimit: limit, interactive: true)
                    fresh.textContainerInset = text.textContainerInset; fresh.textContainer.lineFragmentPadding = 2
                    let proposed = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
                    #expect(text.sizeThatFits(proposed) == fresh.sizeThatFits(proposed))
                }
            }
        }

        @Test func readonlyPreparationNeverPublishesWriteBusy() async {
            let repository = U14ActionMock()
            let store = ContentActionStore(repository: repository, ledger: .init(file: nil),
                                           visibility: ContentRemovalVisibility(),
                                           context: { .init(namespace: "sf-test", revision: 1) }, account: { 42 })
            store.sessionChanged()
            let notifications = Mutex(0)
            withObservationTracking { _ = store.busy } onChange: { notifications.withLock { $0 += 1 } }
            for id in 1...100 {
                await store.prepareDeletion(.init(kind: .post, threadID: 10, postID: Int64(id)), authorID: 41)
            }
            #expect(notifications.withLock { $0 } == 0)
            #expect(repository.inspections == 0 && repository.writes == 0)
        }

        @Test(arguments: [200, 1_000])
        func cachedRowsAndFooterDoNotScanOrProjectOldPosts(pageSize: Int) async throws {
            let store = ThreadReaderStore(threadID: 990_015, repository: Stage15LongThreadFixtureRepository(
                threadID: 990_015, totalPostCount: pageSize * 2, pageSize: pageSize))
            await store.loadIfNeeded()
            let first = store.configuredRows(textSize: .standard)
            ScrollWorkMetrics.start()
            for row in first.prefix(30) { store.setReadAnchor(row.id); _ = store.configuredRows(textSize: .standard) }
            let hits = ScrollWorkMetrics.stop()
            #expect(hits["row.removalScan", default: 0] == 0)
            ScrollWorkMetrics.start()
            store.listPresentation?.setPagination(.loading(nextPage: 2))
            _ = store.configuredRows(textSize: .standard)
            store.listPresentation?.setPagination(.failure(nextPage: 2))
            _ = store.configuredRows(textSize: .standard)
            #expect(ScrollWorkMetrics.stop()["row.projection", default: 0] == 0)
            ScrollWorkMetrics.start()
            await store.loadNextPage()
            let next = store.configuredRows(textSize: .standard)
            #expect(next.filter { $0.row.post != nil }.count == pageSize * 2)
            #expect(ScrollWorkMetrics.stop()["row.projection", default: 0] == pageSize)
            store.cancel()
        }
    }
}
