import SwiftUI

/// Stable callback reference belongs to one bound row. It publishes no layout state.
@MainActor private final class ThreadReaderRowActions {
    var media: (ThreadMediaIntent) -> Void
    var user: (UserProfileRoute) -> Void
    var subposts: (ThreadContentSource) -> Void
    var link: (ExternalLinkIntent) -> Void
    var reply: (ThreadReaderPostRowModel) -> Void
    var next: () -> Void
    init(_ row: ThreadReaderRowView) {
        media = row.onOpenMedia; user = row.onOpenUser; subposts = row.onOpenSubposts
        link = row.onOpenExternalLink; reply = row.onReply; next = row.requestNextPage
    }
    func update(_ other: ThreadReaderRowActions) {
        media = other.media; user = other.user; subposts = other.subposts
        link = other.link; reply = other.reply; next = other.next
    }
}

@MainActor struct ThreadReaderVirtualRow: View {
    private let value: ThreadReaderRowView
    private let contentActions: ContentActionStore?
    private let actions: ThreadReaderRowActions
    init(_ value: ThreadReaderRowView, contentActions: ContentActionStore?) {
        self.contentActions = contentActions
        actions = ThreadReaderRowActions(value)
        // Only the relay retains callbacks; replacing them releases the previous snapshot/context.
        self.value = ThreadReaderRowView(readingControls: value.readingControls, replyPreferences: value.replyPreferences,
                                         row: value.row, imageLoader: value.imageLoader, readingTextSize: value.readingTextSize,
                                         onOpenMedia: { _ in }, onOpenUser: { _ in }, onOpenSubposts: { _ in },
                                         onOpenExternalLink: { _ in }, favoriteStore: value.favoriteStore,
                                         bookmarkStore: value.bookmarkStore, bookmarkTitle: value.bookmarkTitle,
                                         bookmarkForum: value.bookmarkForum, requestNextPage: {})
    }
    func refreshActions(from other: Self) -> Bool {
        let next = other.value
        guard value.row == next.row, value.readingTextSize == next.readingTextSize,
              value.readingControls === next.readingControls, value.replyPreferences === next.replyPreferences,
              value.favoriteStore === next.favoriteStore, value.bookmarkStore === next.bookmarkStore,
              contentActions === other.contentActions,
              value.bookmarkTitle == next.bookmarkTitle, value.bookmarkForum == next.bookmarkForum,
              let identity = value.imageLoader.renderingIdentity, identity == next.imageLoader.renderingIdentity else { return false }
        actions.update(other.actions)
        return true
    }
    var body: some View {
        ThreadReaderRowView(
            readingControls: value.readingControls, replyPreferences: value.replyPreferences,
            row: value.row, imageLoader: value.imageLoader, readingTextSize: value.readingTextSize,
            onOpenMedia: { actions.media($0) }, onOpenUser: { actions.user($0) },
            onOpenSubposts: { actions.subposts($0) }, onOpenExternalLink: { actions.link($0) }, onReply: { actions.reply($0) },
            favoriteStore: value.favoriteStore, bookmarkStore: value.bookmarkStore,
            bookmarkTitle: value.bookmarkTitle, bookmarkForum: value.bookmarkForum, requestNextPage: { actions.next() })
            .environment(\.contentActions, contentActions)
    }
}
