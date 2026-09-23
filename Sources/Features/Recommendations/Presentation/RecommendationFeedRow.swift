import SwiftUI

@MainActor
struct RecommendationFeedRow: View {
    let item: RecommendationSummary
    let imageLoader: any ImageLoading
    let openThread: () -> Void

    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 15
    @ScaledMetric(relativeTo: .subheadline) private var nameSize: CGFloat = 13
    @ScaledMetric(relativeTo: .caption) private var metadataSize: CGFloat = 12
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: openThread) {
                VStack(alignment: .leading, spacing: 8) {
                    authorHeader
                    contentText
                    if !item.previewMediaResources.isEmpty {
                        mediaPreview
                    }
                    forumChip
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开只读帖子")
            .accessibilityIdentifier(RecommendationsAccessibilityID.row(item.threadID))
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

    private var contentText: some View {
        let abstract = item.feed.abstractText
        let showTitle = item.feed.showsTitle || abstract.isEmpty
        let title = showTitle ? Text(item.title).bold() : Text("")
        let separator = showTitle && !abstract.isEmpty ? "\n" : ""
        return (title + Text(separator + abstract))
            .font(.system(size: bodySize))
            .foregroundStyle(SemanticColor.primaryText)
            .lineSpacing(0.8)
            .lineLimit(5)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
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
            actionLabel("arrow.up.arrow.down", count: item.feed.shareCount, fallback: "分享")
                .accessibilityLabel("分享：\(RecommendationFeedText.count(item.feed.shareCount, fallback: "暂无计数"))")
            Button(action: openThread) {
                actionLabel("text.bubble", count: Int64(item.replyCount), fallback: "回复")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.replyCount) 条回复，打开只读帖子")
            .accessibilityIdentifier("recommendations.reply.t\(item.threadID)")
            actionLabel("heart", count: item.feed.agreeCount, fallback: "点赞")
                .accessibilityLabel("点赞：\(RecommendationFeedText.count(item.feed.agreeCount, fallback: "暂无计数"))")
        }
        .foregroundStyle(SemanticColor.secondaryText)
    }

    private func actionLabel(_ symbol: String, count: Int64?, fallback: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 18))
            Text(RecommendationFeedText.count(count, fallback: fallback)).font(.system(size: metadataSize))
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .contentShape(Rectangle())
    }
}
