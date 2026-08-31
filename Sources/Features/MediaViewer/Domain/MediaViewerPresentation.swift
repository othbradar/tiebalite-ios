import Foundation

struct MediaViewerPresentation: Equatable, Identifiable, Sendable {
    struct PresentationID: Equatable, Hashable, Sendable {
        let orderedMediaIDs: [String]
        let initialMediaID: String
    }

    let id: PresentationID
    let items: [MediaViewerItem]
    let initialMediaID: String

    init?(intent: ThreadMediaIntent) {
        let total = intent.items.count
        let items = intent.items.enumerated().map { index, item in
            MediaViewerItem(
                item,
                accessibilityLabel: MediaAccessibilityCopy.imageLabel(
                    alternativeText: item.alternativeText,
                    position: index + 1,
                    total: total
                )
            )
        }
        let orderedIDs = items.map(\.id)
        let initialID = intent.initialMediaID.stableKey
        guard !items.isEmpty,
              Set(orderedIDs).count == orderedIDs.count,
              orderedIDs.contains(initialID) else {
            return nil
        }
        self.items = items
        initialMediaID = initialID
        id = PresentationID(
            orderedMediaIDs: orderedIDs,
            initialMediaID: initialID
        )
    }
}

struct MediaViewerItem: Equatable, Identifiable, Sendable {
    let id: String
    let mediaID: ThreadMediaID
    let request: ThreadImageRequestDescriptor
    let dimensions: ThreadMediaDimensions
    let alternativeText: String
    let accessibilityLabel: String

    init(_ item: ThreadMediaItem, accessibilityLabel: String) {
        id = item.mediaID.stableKey
        mediaID = item.mediaID
        request = item.request
        dimensions = item.dimensions
        alternativeText = item.alternativeText
        self.accessibilityLabel = accessibilityLabel
    }
}
