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
    let identifier: String
    let reply: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if let route = UserProfileRoute(userID: author.rawUserID, fallbackDisplayName: author.displayName) { onOpenUser(route) }
            } label: {
                HStack(alignment: .top, spacing: 8) {
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
                        TiebaMetadataRow(values: [metadata, author.ipLocation.map { "来自\($0)" } ?? ""])
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(minHeight: 44, alignment: .top)
            }
            .buttonStyle(.plain).accessibilityIdentifier(identifier + ".author")
            VStack(alignment: .leading, spacing: 4) {
                ThreadContentRenderer(
                    document: document, imageLoader: imageLoader, readingTextSize: readingTextSize,
                    onOpenMedia: onOpenMedia)
                if let reply {
                    Button("回复", action: reply).font(Typography.font(.caption)).foregroundStyle(SemanticColor.secondaryText)
                        .frame(minHeight: 44).accessibilityIdentifier(identifier + ".action")
                }
            }.padding(.leading, TiebaParityTokens.userAvatarSize + 8)
            TiebaFlatDivider(inset: 0)
        }
        .padding(.horizontal, 16).padding(.top, 8)
        .foregroundStyle(SemanticColor.primaryText).background(SemanticColor.background)
        .accessibilityElement(children: .contain).accessibilityIdentifier(identifier)
    }
}
