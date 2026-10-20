import SwiftUI

@MainActor
struct ForumSearchResultRow: View {
    let row: ThreadSearchRowModel
    let keyword: String
    let imageLoader: any ImageLoading
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TiebaForumAvatarView(resource: row.result.forumAvatarResource, imageLoader: imageLoader, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.forumName.hasSuffix("吧") ? row.forumName : row.forumName + "吧")
                                .font(.subheadline)
                            Text(authorLine).font(.caption).foregroundStyle(SemanticColor.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    Text(highlight(row.title))
                        .font(.body.weight(row.result.postID == nil ? .semibold : .regular))
                        .lineLimit(row.result.postID == nil ? 2 : 4)
                    if let summary = row.summary { Text(highlight(summary)).font(.body).lineLimit(2) }
                    if !row.result.quotedPosts.isEmpty { quotes }
                    if row.result.postID == nil, !row.result.thumbnailResources.isEmpty {
                        TiebaMediaGrid(resources: row.result.thumbnailResources, imageLoader: imageLoader)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .accessibilityIdentifier(row.result.searchAccessibilityID)
            .accessibilityHint(row.result.postID == nil ? "打开帖子" : "打开匹配的回复")
            HStack {
                if let url = PublicContentURL.thread(row.result.threadID) {
                    ShareLink(item: url) {
                        Label("分享", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .accessibilityIdentifier("\(row.result.searchAccessibilityID).share")
                }
                Button(action: open) {
                    Label(row.result.postID == nil ? row.replyText : "回复", systemImage: "text.bubble")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("\(row.result.searchAccessibilityID).replies")
                Label(row.result.likeCount.map { $0 > 0 ? String($0) : "赞" } ?? "赞", systemImage: "hand.thumbsup")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .font(.caption).foregroundStyle(SemanticColor.secondaryText)
        }
        .buttonStyle(.plain).foregroundStyle(SemanticColor.primaryText).multilineTextAlignment(.leading)
        .padding(12).background(SemanticColor.background, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 8).padding(.bottom, 8)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private var quotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(row.result.quotedPosts.enumerated()), id: \.offset) { index, quote in
                HStack(alignment: .top, spacing: 8) {
                    if index == row.result.quotedPosts.count - 1, let image = row.result.thumbnailResources.first {
                        TiebaRemoteImageView(resource: image, imageLoader: imageLoader, purpose: .listThumbnail,
                                             accessibilityLabel: "原帖图片")
                            .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    Text(highlight((quote.authorName.isEmpty ? "" : quote.authorName + "：") + quote.text))
                        .font(.subheadline).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(index > 0 ? 8 : 0)
                .background(index > 0 ? SemanticColor.background : .clear, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .foregroundStyle(SemanticColor.secondaryText).padding(10)
        .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 8))
    }

    private var authorLine: String {
        let verb = row.result.postID == nil ? "发布于" : "回复于"
        return row.authorName + (row.timeText.map { " \(verb) \($0)" } ?? "")
    }

    private func highlight(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        var searchStart = result.startIndex
        while searchStart < result.endIndex,
              let range = result[searchStart...].range(of: keyword, options: .caseInsensitive) {
            result[range].foregroundColor = .red
            searchStart = range.upperBound
        }
        return result
    }
}
