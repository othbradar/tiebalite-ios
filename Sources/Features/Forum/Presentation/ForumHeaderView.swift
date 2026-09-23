import SwiftUI

struct ForumHeaderView: View {
    let forum: ForumSummary
    let imageLoader: any ImageLoading

    var body: some View {
        HStack(spacing: 16) {
            TiebaForumAvatarView(resource: forum.avatarResource, imageLoader: imageLoader, size: 56)
                .accessibilityIdentifier("forum-home.avatar")
            VStack(alignment: .leading, spacing: 4) {
                Text(forum.name.hasSuffix("吧") ? forum.name : forum.name + "吧")
                    .font(.title3.bold())
                    .lineLimit(1)
                if let progress = forum.membership?.progress {
                    ProgressView(value: progress)
                        .tint(SemanticColor.primaryText)
                        .accessibilityLabel("升级经验进度")
                }
                HStack(spacing: 4) {
                    TiebaForumLevelBadge(level: forum.levelID)
                    if let name = forum.levelName {
                        Text(name).font(.caption).foregroundStyle(SemanticColor.secondaryText)
                    }
                }
                TiebaMetadataRow(values: [
                    "关注 " + ForumFeedText.count(Int64(forum.memberCount), fallback: "0"),
                    "主题 " + ForumFeedText.count(Int64(forum.threadCount), fallback: "0")
                ])
            }
            Spacer(minLength: 0)
            if let days = forum.membership?.signedDays {
                Text("已签\(days)天")
                    .font(.caption)
                    .foregroundStyle(SemanticColor.secondaryText)
                    .padding(8)
                    .background(TiebaParityTokens.neutralFill, in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ForumHomeAccessibilityID.header)
    }
}
