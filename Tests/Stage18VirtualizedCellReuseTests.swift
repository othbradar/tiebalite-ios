import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
@Suite(.serialized)
struct Stage18VirtualizedCellReuseTests {
    @Test
    func reusedRowUsesNewHeightOnItsFirstMeasurement() async throws {
        let fixture = try mountedList()
        defer { fixture.close() }
        try #require(await fixture.waitForText("row-1-pending"))
        let cell = try #require(fixture.table.cellForRow(at: IndexPath(row: 0, section: 0)) as? VirtualListHostingCell)
        let container = cell.contentView
        for (index, height) in [480.0, 72.0, 360.0, 64.0].enumerated() {
            let title = "resized-\(index)"
            cell.unbindHostedContent?()
            fixture.coordinator.configure(cell, with: .init(id: index + 2, title: title, height: height))
            let first = cell.systemLayoutSizeFitting(
                CGSize(width: 390, height: 0), withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel).height
            #expect(abs(first - height) < 2, "First sizing must use the new binding, before a display turn")
            #expect(cell.contentView === container)
            #expect(await fixture.waitForText("\(title)-pending", in: cell))
        }
    }

    @Test
    func lateResultFromAReusedCellCannotReplaceTheNewRow() async throws {
        let fixture = try mountedList()
        defer { fixture.close() }
        let table = fixture.table
        try #require(await fixture.waitForText("row-1-pending"))
        let initialCells = table.visibleCells
        let originalIDs = Dictionary(uniqueKeysWithValues: initialCells.compactMap { cell in
            table.indexPath(for: cell).map { (ObjectIdentifier(cell), $0.row + 1) }
        })
        let containers = Dictionary(uniqueKeysWithValues: initialCells.map { (ObjectIdentifier($0), $0.contentView) })
        for targetRow in [20, 30] {
            table.scrollToRow(at: IndexPath(row: targetRow, section: 0), at: .top, animated: false)
            table.layoutIfNeeded()
            try #require(await fixture.waitForText("row-\(targetRow + 1)-pending"))
        }
        let cell = try #require(initialCells.first { initial in
            table.visibleCells.contains { $0 === initial } && table.bounds.contains(initial.frame)
        })
        let originalID = try #require(originalIDs[ObjectIdentifier(cell)])
        let currentID = try #require(table.indexPath(for: cell)).row + 1
        #expect(originalID != currentID && table.virtualListDiagnostics.reuseCount > 0)
        #expect(cell.contentView === containers[ObjectIdentifier(cell)])
        try #require(await fixture.waitForText("row-\(currentID)-pending", in: cell))
        let completed = fixture.loader.finish(id: originalID, text: "row-\(originalID)-late")
        #expect(!completed.isEmpty)
        #expect(await VirtualListNativeCondition.wait { completed.isSubset(of: fixture.loader.applied) })
        #expect(fixture.texts(in: cell).contains("row-\(currentID)-pending"))
        #expect(!fixture.texts(in: cell).contains("row-\(originalID)-late"))
        fixture.loader.finish(id: currentID, text: "row-\(currentID)-ready")
        #expect(await fixture.waitForText("row-\(currentID)-ready", in: cell))
        let button = try #require(fixture.button(in: cell))
        button.sendActions(for: .touchUpInside)
        #expect(fixture.loader.actions == [currentID])
    }

    @Test
    func returningToSameIDRejectsItsFirstBindingAndKeepsSameBindingUpdates() async throws {
        let fixture = try mountedList()
        defer { fixture.close() }
        try #require(await fixture.waitForText("row-1-pending"))
        let cell = try #require(fixture.table.cellForRow(at: IndexPath(row: 0, section: 0)) as? VirtualListHostingCell)
        let container = cell.contentView
        let oldLabel = try #require(virtualListVisibleLabels(in: cell).first { $0.text == "row-1-pending" })
        let oldStarts = Set(fixture.loader.starts[1] ?? [])
        // Exercise the business unbind here; UIKit's prepareForReuse also marks
        // a cell hidden until dequeue/display, covered by the real-table test.
        cell.unbindHostedContent?()
        fixture.coordinator.configure(cell, with: .init(id: 2, title: "row-2"))
        try #require(await fixture.waitForText("row-2-pending", in: cell))
        #expect(oldLabel.window == nil)
        cell.unbindHostedContent?()
        fixture.coordinator.configure(cell, with: .init(id: 1, title: "row-1"))
        try #require(await fixture.waitForText("row-1-pending", in: cell))
        let newSerial = try #require(fixture.loader.starts[1]?.last)
        #expect(!oldStarts.contains(newSerial))
        for serial in oldStarts { fixture.loader.finish(serial: serial, text: "obsolete-A") }
        #expect(await VirtualListNativeCondition.wait { oldStarts.isSubset(of: fixture.loader.applied) })
        #expect(fixture.texts(in: cell).contains("row-1-pending"))
        #expect(!fixture.texts(in: cell).contains("obsolete-A"))
        fixture.loader.finish(serial: newSerial, text: "current-A-ready")
        try #require(await fixture.waitForText("current-A-ready", in: cell))
        let starts = fixture.loader.starts[1]
        fixture.coordinator.configure(cell, with: .init(id: 1, title: "updated-A", height: 140, fontSize: 26))
        #expect(await VirtualListNativeCondition.wait {
            fixture.button(in: cell)?.title(for: .normal) == "updated-A" &&
                virtualListVisibleLabels(in: cell).contains { $0.text == "current-A-ready" && $0.font.pointSize == 26 }
        })
        #expect(fixture.loader.starts[1] == starts)
        #expect(cell.contentView === container)
        #expect(await VirtualListNativeCondition.wait {
            abs(cell.systemLayoutSizeFitting(
                CGSize(width: 390, height: 0), withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel).height - 140) < 2
        })
        fixture.coordinator.tableView(fixture.table, didEndDisplaying: cell, forRowAt: IndexPath(row: 0, section: 0))
        #expect(fixture.texts(in: cell).contains("current-A-ready"))
        #expect(cell.contentConfiguration != nil)
        fixture.button(in: cell)?.sendActions(for: .touchUpInside)
        #expect(fixture.loader.actions == [1])
    }

    private func mountedList() throws -> VirtualListBindingFixture {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        return VirtualListBindingFixture(scene: scene)
    }
}
