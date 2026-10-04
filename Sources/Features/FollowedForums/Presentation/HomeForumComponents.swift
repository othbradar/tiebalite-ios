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
    let editing: Bool
    let imageLoader: any ImageLoading
    let toggle: () -> Void
    let toggleEditing: () -> Void
    let openForum: (ForumRoute) -> Void
    let removeForum: (Int64) -> Void
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
                            recentForum(forum)
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

    private func recentForum(_ forum: RecentForum) -> some View {
        Button { if !editing { openForum(forum.route) } } label: {
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
        .accessibilityHint(editing ? "长按结束删除" : "长按管理最近逛吧")
        .accessibilityAction(named: editing ? "结束删除" : "管理最近逛吧", toggleEditing)
        // Keep the capsule and row layout unchanged. Only the edit badge extends
        // slightly into the trailing gap, away from the forum name.
        .overlay(alignment: .topTrailing) {
            if editing {
                Button { removeForum(forum.id) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(.red, in: Circle())
                        .frame(width: 44, height: 44, alignment: .topTrailing)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("删除\(forum.name)吧的最近访问记录")
                .accessibilityIdentifier("home.recent.remove.f\(forum.id)")
                .offset(x: 10)
            }
        }
        .highPriorityGesture(LongPressGesture().onEnded { _ in toggleEditing() })
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
