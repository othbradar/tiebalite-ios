import SwiftUI

/// Native menu and ShareLink keep system presentation anchored to the invoking control on iPad.
struct LinkActionsMenu: View {
    let url: URL
    let identifier: String
    var reload: (() -> Void)?
    var open: (() -> Void)?

    var body: some View {
        Menu {
            LinkActionsContent(url: url, identifier: identifier, reload: reload, open: open)
        } label: {
            Label("更多", systemImage: "ellipsis")
                .font(TiebaParityTokens.contentActionIconFont)
                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityIdentifier(identifier)
    }
}

struct LinkActionsContent: View {
    let url: URL
    let identifier: String
    var reload: (() -> Void)?
    var open: (() -> Void)?

    var body: some View {
        Button("复制链接", systemImage: "link") { UIPasteboard.general.url = url }
            .accessibilityIdentifier(identifier + ".copy")
        ShareLink(item: url) { Label("分享", systemImage: "square.and.arrow.up") }
            .accessibilityIdentifier(identifier + ".share")
        if let open {
            Button("打开", systemImage: "doc.text", action: open)
                .accessibilityIdentifier(identifier + ".open")
        }
        if let reload {
            Button("重新加载", systemImage: "arrow.clockwise", action: reload)
                .accessibilityIdentifier(identifier + ".reload")
        }
    }
}
