import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct R01AvatarCellReuseTests {
    @Test
    func actualAvatarViewCancelsItsRequestWhenTheTableCellIsReused() async throws {
        let loader = R01CellAvatarLoader()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 100))
        let rows = (1...40).map { R01AvatarRow(id: "avatar.\($0)") }
        let list = VirtualizedList(
            items: rows,
            backgroundColor: .systemBackground,
            accessibilityIdentifier: "r01.avatar-reuse",
            rowContent: { row in
                TiebaAvatarView(resource: row.resource, imageLoader: loader)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            }
        )
        let coordinator = list.makeCoordinator()
        let table = VirtualizedTableView(frame: window.bounds, style: .plain)
        window.addSubview(table)
        window.makeKeyAndVisible()
        coordinator.install(on: table)
        coordinator.synchronize()
        window.layoutIfNeeded()
        table.layoutIfNeeded()
        defer {
            coordinator.dismantle()
            window.isHidden = true
        }
        let cells = table.visibleCells
        let originalIDs = Dictionary(uniqueKeysWithValues: cells.compactMap { cell in
            table.indexPath(for: cell).map { (ObjectIdentifier(cell), rows[$0.row].id) }
        })
        for id in originalIDs.values { try await loader.waitForStart(id) }
        for row in [20, 30] {
            table.scrollToRow(at: IndexPath(row: row, section: 0), at: .top, animated: false)
            table.layoutIfNeeded()
            await Task.yield()
        }
        let reused = try #require(cells.first { cell in table.visibleCells.contains { $0 === cell } })
        let originalID = try #require(originalIDs[ObjectIdentifier(reused)])
        let currentIndex = try #require(table.indexPath(for: reused))
        let currentID = rows[currentIndex.row].id
        try await loader.waitForStart(currentID)
        try await loader.waitForCancellation(originalID)
        #expect(originalID != currentID)
        #expect(table.virtualListDiagnostics.reuseCount > 0)
    }
}

private struct R01AvatarRow: Identifiable, Equatable, Sendable {
    let id: String
    var resource: ImageResourceDescriptor {
        ImageResourceDescriptor(resourceID: id, candidateURLs: ["https://images.fixture.invalid/\(id)"])
    }
}

private actor R01CellAvatarLoader: ImageLoading {
    private var starts: [String: HarnessContinuationGate<Void>] = [:]
    private var cancellations: [String: HarnessContinuationGate<Void>] = [:]

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        startGate(request.resourceID).succeed(())
        let stream = AsyncStream<Void> { _ in }
        for await _ in stream { try Task.checkCancellation() }
        cancellationGate(request.resourceID).succeed(())
        throw CancellationError()
    }

    func waitForStart(_ id: String) async throws {
        try await startGate(id).wait()
    }

    func waitForCancellation(_ id: String) async throws {
        try await cancellationGate(id).wait()
    }

    private func startGate(_ id: String) -> HarnessContinuationGate<Void> {
        if let gate = starts[id] { return gate }
        let gate = HarnessContinuationGate<Void>()
        starts[id] = gate
        return gate
    }

    private func cancellationGate(_ id: String) -> HarnessContinuationGate<Void> {
        if let gate = cancellations[id] { return gate }
        let gate = HarnessContinuationGate<Void>()
        cancellations[id] = gate
        return gate
    }
}
