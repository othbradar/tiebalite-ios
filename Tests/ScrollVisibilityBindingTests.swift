import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

extension SFScrollTests {
    @MainActor @Suite(.serialized)
    struct VisibilityBinding {
        @Test func visibilityOnlyChangeReplacesActualDisplayedPreviewAndFloor() async throws {
            let visibility = LocalUserVisibility.shared
            let saved = visibility.ids
            let store = ThreadReaderStore(threadID: 990_015, repository: Stage15LongThreadFixtureRepository(
                threadID: 990_015, totalPostCount: 20, pageSize: 20))
            await store.loadIfNeeded()
            let rows = store.configuredRows(textSize: .standard)
            let index = try #require(rows.firstIndex { $0.row.post?.floorNumber == 17 })
            let revision = store.listRevision
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene); window.frame = scene.coordinateSpace.bounds
            let controller = UIHostingController(rootView: NavigationStack {
                ThreadReaderView(store: store, imageLoader: DisabledImageLoader(),
                                 followsGlobalReplyPreferences: false, onOpenMedia: { _ in })
            })
            window.rootViewController = controller; window.makeKeyAndVisible()
            defer { window.isHidden = true; store.cancel(); visibility.update(saved) }
            try #require(await VirtualListNativeCondition.wait { findTable(controller.view)?.numberOfRows(inSection: 0) == rows.count })
            let table = try #require(findTable(controller.view))
            table.scrollToRow(at: .init(row: index, section: 0), at: .top, animated: false)
            try #require(await VirtualListNativeCondition.wait { visibleText(table).contains("稳定楼中楼预览 1") })
            visibility.update(saved.union([1_000_016]))
            try #require(await VirtualListNativeCondition.wait {
                !visibleText(table).contains("稳定楼中楼预览 1") && visibleText(table).contains("稳定楼中楼预览 2")
            })
            #expect(store.listRevision == revision)
            visibility.update(saved.union([990_032]))
            try #require(await VirtualListNativeCondition.wait {
                table.numberOfRows(inSection: 0) == rows.count - 1 && !visibleText(table).contains("稳定楼中楼预览")
            })
            #expect(store.listRevision == revision)
            visibility.update(saved)
            try #require(await VirtualListNativeCondition.wait { table.numberOfRows(inSection: 0) == rows.count })
            table.scrollToRow(at: .init(row: index, section: 0), at: .top, animated: false)
            try #require(await VirtualListNativeCondition.wait { visibleText(table).contains("稳定楼中楼预览 1") })
        }
        private func findTable(_ view: UIView) -> UITableView? {
            if let table = view as? VirtualizedTableView { return table }
            return view.subviews.lazy.compactMap { findTable($0) }.first
        }
        private func visibleText(_ table: UITableView) -> String {
            func text(_ view: UIView) -> String {
                if let text = view as? UITextView, text.window != nil { return text.text ?? "" }
                return view.subviews.map { text($0) }.joined(separator: " ")
            }
            return table.visibleCells.map { text($0) }.joined(separator: " ")
        }
    }
}
