import SwiftUI

struct HomeSearchBox: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass").font(.title3)
                Text("发现更多").font(.subheadline)
                Spacer()
            }
            .foregroundStyle(SemanticColor.secondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityIdentifier("home.search")
    }
}

struct HomeSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.bold())
            .foregroundStyle(SemanticColor.secondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(TiebaParityTokens.neutralFill, in: Capsule())
    }
}

struct HomeRecentForumsRow: View {
    let forums: [RecentForum]
    let expanded: Bool
    let imageLoader: any ImageLoading
    let toggle: () -> Void
    let openForum: (ForumRoute) -> Void
    @ScaledMetric(relativeTo: .caption) private var nameSize: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                HStack {
                    HomeSectionLabel(title: "经过贴吧")
                    Spacer()
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.subheadline.bold())
                        .foregroundStyle(SemanticColor.primaryText)
                }
                .frame(minHeight: 44)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(expanded ? "已展开" : "已收起")
            .accessibilityIdentifier("home.recent.toggle")
            if expanded {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 8) {
                        ForEach(forums) { forum in
                            Button { openForum(forum.route) } label: {
                                HStack(spacing: 4) {
                                    TiebaForumAvatarView(resource: forum.avatarResource, imageLoader: imageLoader, size: 24)
                                    Text("\(forum.name)吧").font(.system(size: nameSize, weight: .bold))
                                        .lineLimit(1).padding(.trailing, 4)
                                }
                                .padding(4)
                                .background(TiebaParityTokens.neutralFill, in: Capsule())
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("home.recent.f\(forum.id)")
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("home.recent.list")
            }
        }
        .padding(.vertical, 8)
    }
}

struct HomeFollowedForumRow: View {
    let forum: FollowedForum
    let avatarResource: ImageResourceDescriptor?
    let imageLoader: any ImageLoading
    @ScaledMetric(relativeTo: .subheadline) private var titleSize: CGFloat = 15
    @ScaledMetric(relativeTo: .caption2) private var metadataSize: CGFloat = 10

    var body: some View {
        HStack(spacing: 14) {
            TiebaForumAvatarView(resource: avatarResource, imageLoader: imageLoader)
            VStack(alignment: .leading, spacing: 2) {
                Text(forum.name)
                    .font(.system(size: titleSize, weight: .bold))
                    .foregroundStyle(SemanticColor.primaryText)
                    .multilineTextAlignment(.leading)
                Text("热度 \(HomeForumNumber.text(forum.hotCount))")
                    .font(.system(size: metadataSize))
                    .foregroundStyle(SemanticColor.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TiebaForumLevelBadge(level: forum.levelID)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct HomeForumSkeleton: View {
    var body: some View {
        HStack(spacing: 14) {
            Circle().fill(TiebaParityTokens.neutralFill).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 6) {
                Rectangle().fill(TiebaParityTokens.neutralFill).frame(width: 96, height: 12)
                Rectangle().fill(TiebaParityTokens.neutralFill).frame(width: 56, height: 8)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 3).fill(TiebaParityTokens.neutralFill).frame(width: 40, height: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
