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
        let items = intent.items.map(MediaViewerItem.init)
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

    init(_ item: ThreadMediaItem) {
        id = item.mediaID.stableKey
        mediaID = item.mediaID
        request = item.request
        dimensions = item.dimensions
        alternativeText = item.alternativeText
    }
}
