import SwiftUI

@MainActor
struct ThreadReaderRowView: View {
    var readingControls: ThreadReaderStore?
    var replyPreferences: (any ThreadReplyPreferences)?
    let row: ThreadReaderRowModel
    let imageLoader: any ImageLoading
    let readingTextSize: ReadingTextSizePreference
    let onOpenMedia: (ThreadMediaIntent) -> Void
    let onOpenUser: (UserProfileRoute) -> Void
    let onOpenSubposts: (ThreadContentSource) -> Void
    let onOpenExternalLink: (ExternalLinkIntent) -> Void
    var onReply: (ThreadReaderPostRowModel) -> Void = { _ in }
    var favoriteStore: FavoriteStore?
    var bookmarkStore: BookmarkStore?
    var bookmarkTitle: String?
    var bookmarkForum: String?
    let requestNextPage: () -> Void

    @ViewBuilder
    var body: some View {
        switch row.content {
        case .replyFilters:
            if let readingControls {
                ThreadReplyFilterBar(store: readingControls, preferences: replyPreferences)
                    .padding(.horizontal, 16)
            }
        case let .post(post):
            ThreadReaderPostView(
                post: post, imageLoader: imageLoader, readingTextSize: readingTextSize,
                onOpenMedia: onOpenMedia, onOpenUser: onOpenUser,
                onOpenSubposts: onOpenSubposts, onOpenExternalLink: onOpenExternalLink, onReply: onReply,
                favoriteStore: favoriteStore, bookmarkStore: bookmarkStore, bookmarkTitle: bookmarkTitle, bookmarkForum: bookmarkForum
            )
        case let .pagination(pagination):
            ThreadReaderPaginationView(pagination: pagination, requestNextPage: requestNextPage)
                .padding(.vertical, Spacing.medium)
        }
    }
}

struct ThreadReaderForumChip: View {
    let snapshot: ThreadReaderSnapshot
    let imageLoader: any ImageLoading

    var body: some View {
        HStack(spacing: 8) {
            TiebaForumAvatarView(resource: snapshot.forumAvatarResource, imageLoader: imageLoader, size: 28)
                .accessibilityIdentifier("thread-reader.forum-avatar")
            Text(snapshot.forumName + (snapshot.forumName.hasSuffix("吧") ? "" : "吧"))
                .font(Typography.font(.subheadline)).fontWeight(.semibold)
                .lineLimit(1)
                .frame(maxWidth: 180)
                .padding(.trailing, 10)
        }
        .padding(4)
        .background(TiebaParityTokens.neutralFill, in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ThreadReaderAccessibilityID.header(snapshot.threadID))
    }
}

@MainActor
private struct ThreadReaderPostView: View {
    let post: ThreadReaderPostRowModel
    let imageLoader: any ImageLoading
    let readingTextSize: ReadingTextSizePreference
    let onOpenMedia: (ThreadMediaIntent) -> Void
    let onOpenUser: (UserProfileRoute) -> Void
    let onOpenSubposts: (ThreadContentSource) -> Void
    let onOpenExternalLink: (ExternalLinkIntent) -> Void
    var onReply: (ThreadReaderPostRowModel) -> Void = { _ in }
    var favoriteStore: FavoriteStore?
    var bookmarkStore: BookmarkStore?
    var bookmarkTitle: String?
    var bookmarkForum: String?

    private var actionTarget: ContentActionTarget {
        .init(kind: post.source.scope == .firstPost ? .thread : .post,
              threadID: post.source.threadID, postID: post.source.scope == .firstPost ? 0 : post.source.postID)
    }
    private var contentInset: CGFloat { post.source.scope == .post ? TiebaParityTokens.userAvatarSize + 8 : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                authorHeader.contextMenu { floorActions }
                if post.source.scope == .post {
                    ContentLikeButton(target: actionTarget, count: post.agreeCount) { count in
                        HStack(spacing: 4) {
                            TiebaLikeIcon()
                            Text("\(count ?? 0)").font(.caption)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                if let title = post.title {
                    Text(title).font(Typography.font(.headline)).textSelection(.enabled)
                }
                ThreadContentRenderer(document: post.document, imageLoader: imageLoader, preparedBlocks: post.preparedBlocks,
                                      readingTextSize: readingTextSize, onOpenMedia: onOpenMedia,
                                      onOpenExternalLink: onOpenExternalLink, onOpenUser: onOpenUser,
                                      onBodyTap: { onReply(post) })
                if !post.inlineSubposts.isEmpty {
                    subposts
                }
            }
            .padding(.leading, contentInset)
            TiebaMetadataRow(values: [[
                post.floorNumber > 1 ? "第\(post.floorNumber)楼" : "",
                post.metadata,
                post.author.ipLocation ?? ""
            ].filter { !$0.isEmpty }.joined(separator: " ")])
                .accessibilityIdentifier("thread-reader.metadata.p\(post.source.postID)")
                .padding(.leading, contentInset)
                .padding(.top, 8).padding(.bottom, 12)
            TiebaFlatDivider(inset: 0)

        }
        .foregroundStyle(SemanticColor.primaryText)
        .padding(.horizontal, TiebaParityTokens.horizontalInset)
        .padding(.top, 8)
        .background(SemanticColor.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ThreadReaderAccessibilityID.post(post.source))
        .modifier(ContentDeletionPreparation(target: actionTarget, authorID: post.author.rawUserID))
    }

    @ViewBuilder
    private var floorActions: some View {
        ContentDeleteAction(target: actionTarget)
        if let bookmarkTitle, let bookmarkForum {
            FavoriteAction(entry: .init(target: .init(threadID: post.source.threadID, postID: post.source.postID),
                                        title: bookmarkTitle, forumName: bookmarkForum, status: 1, isDeleted: false),
                           store: favoriteStore, isFloor: true)
            BookmarkAction(entry: .init(target: .init(threadID: post.source.threadID, postID: post.source.postID),
                                        title: bookmarkTitle, forumName: bookmarkForum,
                                        floor: post.floorNumber > 0 ? post.floorNumber : nil),
                           store: bookmarkStore, isFloor: true)
        }
    }

    private var authorHeader: some View {
        Button {
            if let route = UserProfileRoute(userID: post.author.rawUserID, fallbackDisplayName: post.authorName) {
                onOpenUser(route)
            }
        } label: {
            HStack(spacing: 8) {
                TiebaAvatarView(resource: post.author.avatarResource, imageLoader: imageLoader)
                    .accessibilityIdentifier("thread-reader.avatar.p\(post.source.postID)")
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(post.authorName).font(Typography.font(.subheadline)).fontWeight(.semibold)
                        TiebaUserLevelBadge(level: post.author.levelID)
                        if post.isThreadAuthor { badge("楼主") }
                        if let role = post.author.moderatorLabel { badge(role) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("thread-reader.author.\(post.author.rawUserID)")
    }

    private func badge(_ text: String) -> some View {
        Text(text).font(Typography.font(.caption)).foregroundStyle(SemanticColor.secondaryText)
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 3))
            .fixedSize()
    }

    private var subposts: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(post.inlineSubposts) { subpost in
                ThreadReaderSubpostPreview(subpost: subpost, onOpenExternalLink: onOpenExternalLink,
                                           onOpenUser: onOpenUser, onOpenSubposts: { onOpenSubposts(post.source) })
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 6).fill(TiebaParityTokens.neutralFill)
                .contentShape(Rectangle())
                .onTapGesture { onOpenSubposts(post.source) }
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thread-reader.subposts.preview.p\(post.source.postID)")
    }
}

private struct ThreadReaderSubpostPreview: View {
    let subpost: ThreadReaderSubpostRowModel
    let onOpenExternalLink: (ExternalLinkIntent) -> Void
    let onOpenUser: (UserProfileRoute) -> Void
    let onOpenSubposts: () -> Void

    var body: some View {
        TiebaRichTextView(runs: subpost.previewRuns, fontSize: 15, lineLimit: 4,
                          onOpenExternalLink: onOpenExternalLink, onOpenUser: onOpenUser, onBodyTap: onOpenSubposts)
            .accessibilityIdentifier(ThreadReaderAccessibilityID.subpost(subpost.document.source))
    }

}

struct ThreadReaderReplyBar: View {
    let imageLoader: any ImageLoading
    var accountAvatar: ImageResourceDescriptor?
    let threadID: Int64
    var readingControls: ThreadReaderStore?
    let reload: () -> Void
    var onCompose: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            TiebaFlatDivider(inset: 0)
            HStack(spacing: 8) {
                TiebaAvatarView(resource: accountAvatar, imageLoader: imageLoader, size: 28)
                Button(action: onCompose) {
                    Text("评论一番").font(Typography.font(.subheadline))
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                        .padding(.horizontal, 8)
                        .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 6))
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("thread-reader.compose")
                if let url = PublicContentURL.thread(threadID) {
                    if let readingControls {
                        ThreadReadingMenu(store: readingControls, url: url, reload: reload)
                    } else {
                        LinkActionsMenu(url: url, identifier: "thread-reader.compose.more", reload: reload)
                    }
                }
            }
            .buttonStyle(.plain).foregroundStyle(SemanticColor.secondaryText)
            .padding(.horizontal, 16).padding(.vertical, 4)
        }
        .background(SemanticColor.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thread-reader.reply-bar")
    }
}
