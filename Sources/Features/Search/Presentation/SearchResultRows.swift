import SwiftUI

/// Layout reference: Android UI c5f1125 SearchForumPage / Search.kt, and the user's P02 screenshots.
@MainActor
struct SearchRowView: View {
    let row: SearchRowModel
    let imageLoader: any ImageLoading
    let onOpenForum: (ForumSearchResult) -> Void
    let onOpenThread: (ThreadSearchResult) -> Void
    let onOpenUser: (UserProfileRoute) -> Void
    let retryNextPage: () -> Void

    @ViewBuilder
    var body: some View {
        switch row.content {
        case let .section(section):
            HStack {
                Text(section.title)
                    .font(.caption.bold())
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .foregroundStyle(section == .recommended ? SemanticColor.background : SemanticColor.secondaryText)
                    .background(section == .recommended ? SemanticColor.primaryText : TiebaParityTokens.neutralFill, in: Capsule())
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .accessibilityAddTraits(.isHeader)
        case let .forum(row):
            Button { onOpenForum(row.result) } label: {
                forumRow(row)
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开吧首页")
            .accessibilityIdentifier(SearchAccessibilityID.forum(row.result.forumID))
        case let .thread(row):
            threadRow(row)
        case let .user(result):
            Button { onOpenUser(result.route) } label: {
                HStack(spacing: 16) {
                    TiebaAvatarView(resource: result.avatarResource, imageLoader: imageLoader, size: 48)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.route.fallbackDisplayName).font(.body.bold()).lineLimit(1)
                        if let introduction = result.introduction {
                            Text(introduction).font(.subheadline).lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(SemanticColor.primaryText)
                .padding(16).contentShape(Rectangle())
                .multilineTextAlignment(.leading)
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开个人主页")
            .accessibilityIdentifier("search.user.\(result.id)")
        case let .pagination(state):
            PaginationFooter(state: state, retry: retryNextPage)
                .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }

    private func forumRow(_ row: ForumSearchRowModel) -> some View {
        HStack(spacing: 16) {
            TiebaForumAvatarView(resource: row.result.avatarResource, imageLoader: imageLoader, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title.hasSuffix("吧") ? row.title : row.title + "吧")
                    .font(.body.bold()).foregroundStyle(SemanticColor.primaryText).lineLimit(2)
                HStack(spacing: 8) {
                    if let count = row.result.memberCountText {
                        statistic(count, image: "person", label: "关注人数")
                    }
                    if let count = row.result.postCountText {
                        statistic(count, image: "text.bubble", label: "帖子数")
                    }
                }
                if let summary = row.summary {
                    Text(summary).font(.subheadline).foregroundStyle(SemanticColor.primaryText).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .combine)
    }

    private func statistic(_ count: String, image: String, label: String) -> some View {
        Label(count, systemImage: image).font(.caption)
            .foregroundStyle(SemanticColor.secondaryText)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 4))
            .accessibilityLabel("\(label) \(count)")
    }

    private func threadRow(_ row: ThreadSearchRowModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { onOpenThread(row.result) } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TiebaAvatarView(resource: row.result.author?.avatarResource, imageLoader: imageLoader)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.authorName).font(.subheadline.bold()).lineLimit(1)
                            if let time = row.timeText {
                                Text(time).font(.caption).foregroundStyle(SemanticColor.secondaryText)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    Text(row.title).font(.body.bold()).lineLimit(2)
                    if let summary = row.summary { Text(summary).font(.body).lineLimit(2) }
                }
                .foregroundStyle(SemanticColor.primaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开帖子")
            .accessibilityIdentifier(row.result.searchAccessibilityID)

            if let forum = row.forumResult {
                Button { onOpenForum(forum) } label: {
                    HStack(spacing: 6) {
                        TiebaForumAvatarView(resource: forum.avatarResource, imageLoader: imageLoader, size: 20)
                        Text(row.forumName.hasSuffix("吧") ? row.forumName : row.forumName + "吧")
                            .font(.caption).lineLimit(1)
                    }
                    .padding(4)
                    .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 4))
                    .frame(minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(SemanticColor.secondaryText)
                .accessibilityIdentifier("search.thread-forum.\(row.result.threadID)")
            } else {
                Text(row.forumName).font(.caption).foregroundStyle(SemanticColor.secondaryText)
            }
            HStack {
                Button { onOpenThread(row.result) } label: {
                    Label(row.replyText, systemImage: "text.bubble").frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityLabel("\(row.replyText) 条回复")
                .accessibilityIdentifier("search.replies.\(row.result.threadID)")
                if let count = row.result.likeCount {
                    Label(String(max(0, count)), systemImage: "heart")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityLabel("\(max(0, count)) 个赞")
                }
                if let url = PublicContentURL.thread(row.result.threadID) {
                    ShareLink(item: url) {
                        Label(row.shareText, systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .accessibilityLabel("分享帖子")
                    .accessibilityIdentifier("search.share.\(row.result.threadID)")
                }
            }
            .font(.caption).foregroundStyle(SemanticColor.secondaryText).buttonStyle(.plain)
            TiebaFlatDivider()
        }
        .padding(.horizontal, 16).padding(.top, 16)
        .background(SemanticColor.background)
    }
}

private extension SearchResultSection {
    var title: String {
        switch self {
        case .recommended: "推荐"
        case .related: "相关吧"
        case .relatedUsers: "相关用户"
        }
    }
}

private extension ThreadSearchRowModel {
    var forumResult: ForumSearchResult? {
        guard let forumID = result.forumID, forumID > 0 else { return nil }
        return ForumSearchResult(forumID: forumID, name: result.forumName, displayName: forumName,
                                 summary: nil, memberCountText: nil, postCountText: nil,
                                 avatarResource: result.forumAvatarResource)
    }
}
