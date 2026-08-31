import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct Stage18VirtualizedCellReuseTests {
    @Test
    func lateResultFromAReusedCellCannotReplaceTheNewRow() async throws {
        let loader = Stage18LateRowLoader()
        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 390, height: 60)
        )
        let list = makeList(loader: loader)
        let coordinator = list.makeCoordinator()
        let table = VirtualizedTableView(
            frame: window.bounds,
            style: .plain
        )
        window.addSubview(table)
        window.makeKeyAndVisible()
        coordinator.install(on: table)
        coordinator.synchronize()
        window.layoutIfNeeded()
        table.layoutIfNeeded()
        let initialCells = table.visibleCells
        let originalIDs = Dictionary(uniqueKeysWithValues: initialCells.compactMap { cell in
            table.indexPath(for: cell).map {
                (ObjectIdentifier(cell), $0.row + 1)
            }
        })
        for originalID in originalIDs.values {
            try await loader.waitUntilStarted(id: originalID)
        }

        for targetRow in [20, 30] {
            table.scrollToRow(
                at: IndexPath(row: targetRow, section: 0),
                at: .top,
                animated: false
            )
            table.layoutIfNeeded()
            await Task.yield()
        }
        let reusedCell = try #require(initialCells.first { initialCell in
            table.visibleCells.contains { $0 === initialCell }
        })
        let originalID = try #require(
            originalIDs[ObjectIdentifier(reusedCell)]
        )
        let reusedIndex = try #require(table.indexPath(for: reusedCell))
        let currentID = reusedIndex.row + 1
        try await loader.waitUntilStarted(id: currentID)
        #expect(originalID != currentID)
        #expect(table.virtualListDiagnostics.reuseCount > 0)
        #expect(
            visibleLabels(in: reusedCell).contains("row-\(currentID)-pending")
        )

        await loader.finish(
            id: originalID,
            value: "row-\(originalID)-late"
        )
        for _ in 0..<20 {
            await Task.yield()
        }
        table.layoutIfNeeded()

        let labelsAfterLateResult = visibleLabels(in: reusedCell)
        #expect(labelsAfterLateResult.contains("row-\(currentID)-pending"))
        #expect(!labelsAfterLateResult.contains("row-\(originalID)-late"))

        await loader.finish(id: currentID, value: "row-\(currentID)-ready")
        coordinator.dismantle()
    }

    private func makeList(
        loader: Stage18LateRowLoader
    ) -> VirtualizedList<Stage18LateRowItem, Stage18LateRow> {
        VirtualizedList(
            items: (1...40).map {
                Stage18LateRowItem(id: $0, title: "row-\($0)")
            },
            backgroundColor: .systemBackground,
            accessibilityIdentifier: "stage18.late-row-list",
            rowContent: { item in
                Stage18LateRow(item: item, loader: loader)
            }
        )
    }

    private func visibleLabels(in view: UIView) -> [String] {
        let ownText = (view as? UILabel)?.text.map { [$0] } ?? []
        return ownText + view.subviews.flatMap(visibleLabels)
    }
}

private struct Stage18LateRowItem: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
}

private struct Stage18LateRow: View {
    let item: Stage18LateRowItem
    let loader: Stage18LateRowLoader

    @State private var text: String

    init(item: Stage18LateRowItem, loader: Stage18LateRowLoader) {
        self.item = item
        self.loader = loader
        _text = State(initialValue: "\(item.title)-pending")
    }

    var body: some View {
        Stage18TestLabel(text: text)
            .frame(maxWidth: .infinity, minHeight: 72)
            .task(id: item.id) {
                text = await loader.value(for: item.id)
            }
    }
}

private struct Stage18TestLabel: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.text = text
    }
}

private actor Stage18LateRowLoader {
    private var starts: [Int: HarnessContinuationGate<Void>] = [:]
    private var continuations: [Int: CheckedContinuation<String, Never>] = [:]

    func value(for id: Int) async -> String {
        startGate(for: id).succeed(())
        return await withCheckedContinuation { continuation in
            continuations[id] = continuation
        }
    }

    func waitUntilStarted(id: Int) async throws {
        try await startGate(for: id).wait()
    }

    func finish(id: Int, value: String) {
        continuations.removeValue(forKey: id)?.resume(returning: value)
    }

    private func startGate(for id: Int) -> HarnessContinuationGate<Void> {
        if let gate = starts[id] {
            return gate
        }
        let gate = HarnessContinuationGate<Void>()
        starts[id] = gate
        return gate
    }
}
