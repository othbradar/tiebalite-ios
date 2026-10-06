import SwiftUI

@MainActor
struct RecommendationFeedRow: View {
    let item: RecommendationSummary
    let imageLoader: any ImageLoading
    let openURL: OpenURLAction
    let onOpenUser: (UserProfileRoute) -> Void
    let openThread: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var nameSize: CGFloat = 13
    @ScaledMetric(relativeTo: .caption) private var metadataSize: CGFloat = 12
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                primaryContent
                if let url = PublicContentURL.forum(item.forumName) {
                    Button { openURL(url) } label: { forumChip }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("recommendations.forum.t\(item.threadID)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            actions
        }
        .padding(.horizontal, TiebaParityTokens.horizontalInset)
        .padding(.top, 16)
        .background(SemanticColor.background)
        TiebaFlatDivider()
    }

    private var authorHeader: some View {
        HStack(spacing: 8) {
            TiebaAvatarView(resource: item.author?.avatarResource, imageLoader: imageLoader)
                .accessibilityIdentifier("recommendations.avatar.t\(item.threadID)")
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(item.authorName)
                        .font(.system(size: nameSize, weight: .bold))
                        .lineLimit(1)
                    TiebaUserLevelBadge(level: item.author?.levelID)
                    if let role = item.author?.moderatorLabel {
                        TiebaMetadataRow(values: [role])
                    }
                }
                if let time = RecommendationFeedText.relativeTime(item.feed.timeUnixSeconds, now: .now) {
                    Text(time)
                        .font(.system(size: metadataSize))
                        .foregroundStyle(SemanticColor.secondaryText)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(SemanticColor.primaryText)
    }

    private var contentRuns: [TiebaRichTextRun] {
        let abstract = item.feed.abstractText
        let showTitle = item.feed.showsTitle || abstract.isEmpty
        let title = showTitle ? TiebaRichText.parse(item.title, bold: true) : []
        let separator = showTitle && !abstract.isEmpty ? "\n" : ""
        let abstractRuns = item.feed.abstractNodes.isEmpty
            ? TiebaRichText.parse(abstract) : TiebaRichText.runs(nodes: item.feed.abstractNodes)
        return title + TiebaRichText.parse(separator) + abstractRuns
    }

    private var hasInlineActions: Bool {
        contentRuns.contains { $0.linkIntent != nil || $0.profileIntent != nil }
    }

    @ViewBuilder
    private var primaryContent: some View {
        if hasInlineActions {
            VStack(alignment: .leading, spacing: 8) {
                Button(action: openThread) { authorHeader }.buttonStyle(.plain)
                    .accessibilityIdentifier(RecommendationsAccessibilityID.row(item.threadID))
            .contextMenu { moreActions }
                contentText
                if !item.previewMediaResources.isEmpty {
                    Button(action: openThread) { mediaPreview }.buttonStyle(.plain)
                        .accessibilityIdentifier("recommendations.media.t\(item.threadID)")
                }
            }
        } else {
            Button(action: openThread) {
                VStack(alignment: .leading, spacing: 8) {
                    authorHeader
                    contentText
                    if !item.previewMediaResources.isEmpty { mediaPreview }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开帖子")
            .accessibilityIdentifier(RecommendationsAccessibilityID.row(item.threadID))
            .contextMenu { moreActions }
        }
    }

    @ViewBuilder
    private var moreActions: some View {
        if let url = PublicContentURL.thread(item.threadID) {
            LinkActionsContent(url: url, identifier: "recommendations.more.t\(item.threadID)", open: openThread)
        }
    }

    private var contentText: some View {
        TiebaRichTextView(runs: contentRuns, fontSize: 15, lineLimit: 5, interactive: hasInlineActions,
                          onOpenExternalLink: { intent in
                              if let url = URL(string: intent.destination.absoluteString) { openURL(url) }
                          }, onOpenUser: onOpenUser)
            .accessibilityIdentifier("recommendations.content.t\(item.threadID)")
    }

    private var mediaPreview: some View {
        // Only the preview is capped. The domain retains every candidate and ordinal.
        // The badge stays inside this row, never captures touches, and has no independent lifetime.
        TiebaMediaGrid(resources: item.previewMediaResources, imageLoader: imageLoader)
            .frame(maxWidth: item.previewMediaResources.count == 1 && horizontalSizeClass == .regular ? 360 : .infinity)
            .overlay(alignment: .bottomTrailing) {
                if item.mediaCount > 3 {
                    Label("\(item.mediaCount)", systemImage: "photo")
                        .font(.system(size: metadataSize))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(8)
                        .allowsHitTesting(false)
                        .accessibilityLabel("共 \(item.mediaCount) 张图片")
                }
            }
            .accessibilityElement(children: .contain)
    }

    private var forumChip: some View {
        HStack(spacing: 8) {
            TiebaRemoteImageView(
                resource: item.forumAvatarResource, imageLoader: imageLoader,
                purpose: .avatar, accessibilityLabel: "吧头像"
            )
            .frame(width: 20, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(item.forumName.hasSuffix("吧") ? item.forumName : item.forumName + "吧")
                .font(.system(size: metadataSize))
                .lineLimit(1)
                .foregroundStyle(SemanticColor.secondaryText)
        }
        .padding(4)
        .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 4))
        .fixedSize(horizontal: false, vertical: true)
    }

    private var actions: some View {
        HStack(spacing: 0) {
            if let url = PublicContentURL.thread(item.threadID) {
                ShareLink(item: url) {
                    actionLabel(TiebaShareIcon(), count: item.feed.shareCount, fallback: "分享")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("分享帖子")
                .accessibilityIdentifier("recommendations.share.t\(item.threadID)")
            }
            Button(action: openThread) {
                actionLabel(TiebaReplyIcon(), count: Int64(item.replyCount), fallback: "回复")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.replyCount) 条回复，打开帖子")
            .accessibilityIdentifier("recommendations.reply.t\(item.threadID)")
            actionLabel(TiebaLikeIcon(), count: item.feed.agreeCount, fallback: "0")
                .accessibilityLabel("点赞：\(RecommendationFeedText.count(item.feed.agreeCount, fallback: "暂无计数"))")
        }
        .foregroundStyle(SemanticColor.secondaryText)
    }

    private func actionLabel<Icon: View>(_ icon: Icon, count: Int64?, fallback: String) -> some View {
        HStack(spacing: 8) {
            icon.font(TiebaParityTokens.contentActionIconFont)
            Text(RecommendationFeedText.count(count, fallback: fallback)).font(.system(size: metadataSize))
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
    }
}
