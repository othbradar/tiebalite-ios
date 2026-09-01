import SwiftUI
import Testing
@testable import TiebaLite
import UIKit

@MainActor
struct Stage19ImageCellReuseTests {
    @Test
    func lateImageFromAReusedTableCellCannotReplaceTheNewMediaID() async throws {
        let loader = Stage19LateImageLoader()
        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 390, height: 60)
        )
        let list = VirtualizedList(
            items: (1...40).map(Stage19ImageRowItem.init),
            backgroundColor: .systemBackground,
            accessibilityIdentifier: "stage19.image-reuse-list",
            rowContent: { item in
                Stage19ImageRow(item: item, loader: loader)
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
        let initialCells = table.visibleCells
        let originalPairs = initialCells.compactMap { cell in
            table.indexPath(for: cell).map {
                (ObjectIdentifier(cell), Stage19ImageRowItem.id(for: $0.row + 1))
            }
        }
        let originalIDs = Dictionary(uniqueKeysWithValues: originalPairs)
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
        let currentID = Stage19ImageRowItem.id(for: reusedIndex.row + 1)
        try await loader.waitUntilStarted(id: currentID)

        #expect(originalID != currentID)
        #expect(table.virtualListDiagnostics.reuseCount > 0)
        #expect(visibleLabels(in: reusedCell).contains("\(currentID)-loading"))

        await loader.finish(id: originalID)
        for _ in 0..<20 {
            await Task.yield()
        }
        table.layoutIfNeeded()

        let labelsAfterLateImage = visibleLabels(in: reusedCell)
        #expect(labelsAfterLateImage.contains("\(currentID)-loading"))
        #expect(!labelsAfterLateImage.contains("\(originalID)-rendered"))

        await loader.finish(id: currentID)
        coordinator.dismantle()
    }

    private func visibleLabels(in view: UIView) -> [String] {
        let ownText = (view as? UILabel)?.text.map { [$0] } ?? []
        return ownText + view.subviews.flatMap(visibleLabels)
    }
}

private struct Stage19ImageRowItem: Identifiable, Equatable, Sendable {
    let id: String
    let resource: ImageResourceDescriptor

    init(_ ordinal: Int) {
        id = Self.id(for: ordinal)
        resource = ImageResourceDescriptor(
            resourceID: id,
            candidateURLs: ["https://images.fixture.invalid/\(ordinal).png"]
        )
    }

    static func id(for ordinal: Int) -> String {
        "stage19.media.\(ordinal)"
    }
}

@MainActor
private struct Stage19ImageRow: View {
    let item: Stage19ImageRowItem
    let loader: Stage19LateImageLoader

    @State private var renderedID: String?

    var body: some View {
        Stage19ImageTestLabel(
            text: renderedID == item.id
                ? "\(item.id)-rendered"
                : "\(item.id)-loading"
        )
        .frame(maxWidth: .infinity, minHeight: 72)
        .task(id: item.resource) {
            do {
                let payload = try await loader.load(ImageRequest(
                    resource: item.resource,
                    targetPixelSize: ImageTargetPixelSize(width: 100, height: 100),
                    purpose: .listThumbnail,
                    resizeMode: .fill
                ))
                try Task.checkCancellation()
                guard payload.displayImage() != nil else {
                    return
                }
                renderedID = item.id
            } catch {
                return
            }
        }
    }
}

private struct Stage19ImageTestLabel: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UILabel {
        UILabel()
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.text = text
    }
}

private actor Stage19LateImageLoader: ImageLoading {
    nonisolated private static let pixelPNG = Data([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x04, 0x00, 0x00, 0x00, 0xB5, 0x1C, 0x0C,
        0x02, 0x00, 0x00, 0x00, 0x0B, 0x49, 0x44, 0x41,
        0x54, 0x78, 0xDA, 0x63, 0x64, 0xF8, 0x0F, 0x00,
        0x01, 0x05, 0x01, 0x01, 0x27, 0x18, 0xE3, 0x66,
        0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
        0xAE, 0x42, 0x60, 0x82
    ])

    private var starts: [String: HarnessContinuationGate<Void>] = [:]
    private var continuations: [
        String: CheckedContinuation<ImagePayload, Never>
    ] = [:]

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        startGate(for: request.resourceID).succeed(())
        return await withCheckedContinuation { continuation in
            continuations[request.resourceID] = continuation
        }
    }

    func waitUntilStarted(id: String) async throws {
        try await startGate(for: id).wait()
    }

    func finish(id: String) {
        continuations.removeValue(forKey: id)?.resume(
            returning: ImagePayload(
                data: Self.pixelPNG,
                mediaType: "image/png"
            )
        )
    }

    private func startGate(for id: String) -> HarnessContinuationGate<Void> {
        if let gate = starts[id] {
            return gate
        }
        let gate = HarnessContinuationGate<Void>()
        starts[id] = gate
        return gate
    }
}
