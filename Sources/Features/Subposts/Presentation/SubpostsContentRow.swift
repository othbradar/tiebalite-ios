import SwiftUI

struct SubpostsContentRow: View {
    let author: TiebaUserVisuals
    let metadata: String
    let document: ThreadContentDocument
    let isThreadAuthor: Bool
    let imageLoader: any ImageLoading
    let readingTextSize: ReadingTextSizePreference
    let onOpenMedia: (ThreadMediaIntent) -> Void
    let onOpenUser: (UserProfileRoute) -> Void
    let onOpenExternalLink: (ExternalLinkIntent) -> Void
    let identifier: String
    let reply: (() -> Void)?
    var parentPostID: Int64 = 0
    var createdAt: UInt32?
    var floorNumber: Int?
    private var actionTarget: ContentActionTarget {
        .init(kind: .subpost, threadID: document.source.threadID, postID: document.source.postID, parentPostID: parentPostID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if let route = UserProfileRoute(userID: author.rawUserID, fallbackDisplayName: author.displayName) { onOpenUser(route) }
            } label: {
                HStack(spacing: 8) {
                    TiebaAvatarView(resource: author.avatarResource, imageLoader: imageLoader)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(author.displayName).font(Typography.font(.subheadline)).fontWeight(.semibold)
                            TiebaUserLevelBadge(level: author.levelID)
                            if isThreadAuthor {
                                Text("楼主").font(Typography.font(.caption)).foregroundStyle(SemanticColor.secondaryText)
                                    .padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(TiebaParityTokens.neutralFill, in: RoundedRectangle(cornerRadius: 3))
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier(identifier + ".author")
            .contextMenu {
                if reply != nil { ContentDeleteAction(target: actionTarget) }
            }
            ThreadContentRenderer(
                document: document, imageLoader: imageLoader, readingTextSize: readingTextSize,
                onOpenMedia: onOpenMedia, onOpenExternalLink: onOpenExternalLink, onOpenUser: onOpenUser,
                onBodyTap: reply)
                .padding(.leading, TiebaParityTokens.userAvatarSize + 8)
            TiebaMetadataRow(values: [[
                floorNumber.flatMap { $0 > 1 ? "第\($0)楼" : nil } ?? "",
                TiebaDateText.monthDay(seconds: createdAt, fallback: metadata),
                author.ipLocation ?? ""
            ].filter { !$0.isEmpty }.joined(separator: " ")])
                .accessibilityIdentifier(identifier + ".metadata")
                .padding(.leading, TiebaParityTokens.userAvatarSize + 8)
                .padding(.top, 8).padding(.bottom, 12)
            TiebaFlatDivider(inset: 0)
        }
        .padding(.horizontal, 16).padding(.top, 8)
        .foregroundStyle(SemanticColor.primaryText)
        .background {
            SemanticColor.background
                .contentShape(Rectangle())
                .onTapGesture {
                    guard case .available = document.availability else { return }
                    reply?()
                }
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier(identifier)
        .modifier(ContentDeletionPreparation(target: actionTarget, authorID: author.rawUserID))
    }
}
