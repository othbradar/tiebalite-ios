import SwiftUI

struct ForumThreadFeedRow: View {
    let row: ForumThreadRowModel
    let imageLoader: any ImageLoading
    let openThread: () -> Void
    @ScaledMetric(relativeTo: .body) private var textSize: CGFloat = 15
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var thread: ForumThreadSummary { row.sourceSummary }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: openThread) {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    text
                    if !row.thumbnailDescriptions.isEmpty {
                        TiebaMediaGrid(resources: row.thumbnailDescriptions.map(\.resource), imageLoader: imageLoader)
                            .frame(maxWidth: row.rowKind == .singleMedia && sizeClass == .regular ? 360 : .infinity)
                            .overlay(alignment: .bottomTrailing) {
                                if thread.mediaCount > 3 {
                                    Text("\(thread.mediaCount)")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .padding(6)
                                        .background(.black.opacity(0.5), in: Capsule())
                                        .padding(6)
                                        .allowsHitTesting(false)
                                        .accessibilityLabel("共 \(thread.mediaCount) 张图片")
                                }
                            }
                            .accessibilityElement(children: .contain)
                    } else if thread.hasVideo {
                        Text("视频内容").font(.caption).foregroundStyle(SemanticColor.secondaryText)
                    }
                    Text(thread.forumName.hasSuffix("吧") ? thread.forumName : thread.forumName + "吧")
                        .font(.caption)
                        .foregroundStyle(SemanticColor.secondaryText)
                        .padding(4)
                        .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开只读帖子")
            .accessibilityIdentifier(ForumHomeAccessibilityID.row(row.threadID))
            HStack(spacing: 0) {
                action("arrow.up.arrow.down", count: thread.metadata.shareCount, fallback: "分享")
                Button(action: openThread) {
                    action("text.bubble", count: Int64(row.replyCount), fallback: "回复")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("forum-home.reply.t\(row.threadID)")
                action("heart", count: thread.metadata.agreeCount, fallback: "点赞")
            }
            .foregroundStyle(SemanticColor.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        TiebaFlatDivider()
    }

    private var header: some View {
        HStack(spacing: 8) {
            TiebaAvatarView(resource: thread.author?.avatarResource, imageLoader: imageLoader)
                .accessibilityIdentifier("forum-home.author.t\(row.threadID)")
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(row.authorName).font(.subheadline.bold()).lineLimit(1)
                    TiebaUserLevelBadge(level: thread.author?.levelID)
                    if let role = thread.author?.moderatorLabel { TiebaMetadataRow(values: [role]) }
                }
                if let time = ForumFeedText.time(thread.metadata.timeUnixSeconds) {
                    Text(time).font(.caption).foregroundStyle(SemanticColor.secondaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(SemanticColor.primaryText)
    }

    private var text: some View {
        let showTitle = thread.metadata.showsTitle || row.summary == nil
        let title = showTitle ? Text(row.title).bold() : Text("")
        let summary = row.summary ?? ""
        return (title + Text((showTitle && !summary.isEmpty ? "\n" : "") + summary))
            .font(.system(size: textSize))
            .foregroundStyle(SemanticColor.primaryText)
            .lineLimit(5)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func action(_ symbol: String, count: Int64?, fallback: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 18))
            Text(ForumFeedText.count(count, fallback: fallback)).font(.caption)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
    }
}

struct ForumHomeRowView: View {
    let row: ForumHomeRowModel
    var imageLoader: any ImageLoading = DisabledImageLoader()
    let onOpenThread: (ForumThreadSummary) -> Void
    let requestReload: () -> Void
    let requestNextPage: () -> Void

    @ViewBuilder
    var body: some View {
        switch row.content {
        case let .thread(thread):
            if thread.isPinned {
                Button { onOpenThread(thread.sourceSummary) } label: {
                    compactTitle("置顶", title: thread.title)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(ForumHomeAccessibilityID.row(thread.threadID))
            } else {
                ForumThreadFeedRow(row: thread, imageLoader: imageLoader) { onOpenThread(thread.sourceSummary) }
            }
        case let .rule(title):
            compactTitle("吧规", title: title)
                .accessibilityIdentifier("forum-home.rule")
        case let .header(forum):
            ForumHeaderView(forum: forum, imageLoader: imageLoader)
        case .section:
            EmptyView()
        case .empty:
            EmptyStateView(title: "暂无帖子", message: "这个分类当前没有可显示的帖子。", systemImage: "rectangle.stack")
                .frame(maxWidth: .infinity, minHeight: 200)
                .accessibilityIdentifier(ForumHomeAccessibilityID.empty)
        case let .retainedStatus(status):
            if status == .refreshFailure {
                InlineErrorView(message: "重新加载失败，已保留原列表。", retry: requestReload)
            }
        case let .pagination(state):
            PaginationFooter(state: state.footerState, retry: requestNextPage)
        }
    }

    private func compactTitle(_ tag: String, title: String) -> some View {
        HStack(spacing: 16) {
            Text(tag).font(.caption.bold())
                .foregroundStyle(SemanticColor.secondaryText)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 3))
            Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                .foregroundStyle(SemanticColor.primaryText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private extension ForumHomePaginationPresentation {
    var footerState: PaginationFooterState {
        switch self {
        case .idle: .idle
        case .loading: .loading
        case .failure: .failure
        case .end: .end
        }
    }
}
