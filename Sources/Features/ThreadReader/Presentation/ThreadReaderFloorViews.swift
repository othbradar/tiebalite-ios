import SwiftUI

@MainActor
struct ThreadReaderRowView: View {
    let row: ThreadReaderRowModel
    let imageLoader: any ImageLoading
    let readingTextSize: ReadingTextSizePreference
    let onOpenMedia: (ThreadMediaIntent) -> Void
    let onOpenUser: (UserProfileRoute) -> Void
    let onOpenSubposts: (ThreadContentSource) -> Void
    let onReadOnlyAction: () -> Void
    let requestNextPage: () -> Void

    @ViewBuilder
    var body: some View {
        switch row.content {
        case let .post(post):
            ThreadReaderPostView(
                post: post, imageLoader: imageLoader, readingTextSize: readingTextSize,
                onOpenMedia: onOpenMedia, onOpenUser: onOpenUser,
                onOpenSubposts: onOpenSubposts, onReadOnlyAction: onReadOnlyAction
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
    let onReadOnlyAction: () -> Void

    private var contentInset: CGFloat { post.floorNumber > 1 ? TiebaParityTokens.userAvatarSize + 8 : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                authorHeader
                if post.floorNumber > 1 {
                    Button(action: onReadOnlyAction) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart")
                            if let count = post.agreeCount, count > 0 { Text("\(count)") }
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain).foregroundStyle(SemanticColor.secondaryText)
                    .accessibilityLabel("点赞")
                    .accessibilityIdentifier("thread-reader.agree.p\(post.source.postID)")
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                if let title = post.title {
                    Text(title).font(Typography.font(.headline)).textSelection(.enabled)
                }
                ThreadContentRenderer(document: post.document, imageLoader: imageLoader,
                                      readingTextSize: readingTextSize, onOpenMedia: onOpenMedia)
                if !post.inlineSubposts.isEmpty || post.remainingSubpostCount > 0 {
                    subposts
                }
                Button("回复", action: onReadOnlyAction)
                    .font(Typography.font(.caption)).foregroundStyle(SemanticColor.secondaryText)
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityIdentifier("thread-reader.reply.p\(post.source.postID)")
            }
            .padding(.leading, contentInset)
            TiebaFlatDivider(inset: 0)
            if let count = post.replyCount {
                Text("回复 \(count)").font(Typography.font(.subheadline)).fontWeight(.semibold)
                    .padding(.vertical, 8)
            }
        }
        .foregroundStyle(SemanticColor.primaryText)
        .padding(.horizontal, TiebaParityTokens.horizontalInset)
        .padding(.top, 8)
        .background(SemanticColor.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ThreadReaderAccessibilityID.post(post.source))
    }

    private var authorHeader: some View {
        Button {
            if let route = UserProfileRoute(userID: post.author.rawUserID, fallbackDisplayName: post.authorName) {
                onOpenUser(route)
            }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                TiebaAvatarView(resource: post.author.avatarResource, imageLoader: imageLoader)
                    .accessibilityIdentifier("thread-reader.avatar.p\(post.source.postID)")
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(post.authorName).font(Typography.font(.subheadline)).fontWeight(.semibold)
                        TiebaUserLevelBadge(level: post.author.levelID)
                        if post.isThreadAuthor { badge("楼主") }
                        if let role = post.author.moderatorLabel { badge(role) }
                    }
                    TiebaMetadataRow(values: [
                        post.metadata,
                        post.floorNumber > 1 ? "第 \(post.floorNumber) 楼" : "",
                        post.author.ipLocation.map { "来自\($0)" } ?? ""
                    ])
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 44, alignment: .top)
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
                ThreadReaderSubpostPreview(subpost: subpost)
            }
            if post.remainingSubpostCount > 0 {
                Button("查看全部 \(post.totalSubpostCount) 条回复") { onOpenSubposts(post.source) }
                    .font(Typography.font(.caption)).foregroundStyle(SemanticColor.accent)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("thread-reader.subposts.all.p\(post.source.postID)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct ThreadReaderSubpostPreview: View {
    let subpost: ThreadReaderSubpostRowModel

    var body: some View {
        TiebaRichTextView(runs: runs, fontSize: 15, lineLimit: 4)
            .accessibilityIdentifier(ThreadReaderAccessibilityID.subpost(subpost.document.source))
    }

    private var runs: [TiebaRichTextRun] {
        let prefix: [TiebaRichTextRun] = [.text(subpost.authorName + ": ", bold: true)]
            + [.text(subpost.replyToDisplayName.map { "回复 \($0)：" } ?? "")]
        let content = TiebaRichText.runs(nodes: subpost.document.nodes)
        return prefix + (content.isEmpty ? [.text("回复内容暂不可用")] : content)
    }

}

struct ThreadReaderReplyBar: View {
    let imageLoader: any ImageLoading
    let onAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TiebaFlatDivider(inset: 0)
            HStack(spacing: 8) {
                TiebaAvatarView(resource: nil, imageLoader: imageLoader, size: 28)
                Button(action: onAction) {
                    Text("评论一番").font(Typography.font(.subheadline))
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                        .padding(.horizontal, 8)
                        .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 6))
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("thread-reader.compose")
                Button("点赞", systemImage: "heart", action: onAction)
                    .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("thread-reader.compose.agree")
                Button("更多", systemImage: "ellipsis", action: onAction)
                    .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("thread-reader.compose.more")
            }
            .buttonStyle(.plain).foregroundStyle(SemanticColor.secondaryText)
            .padding(.horizontal, 16).padding(.vertical, 4)
        }
        .background(SemanticColor.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thread-reader.reply-bar")
    }
}
