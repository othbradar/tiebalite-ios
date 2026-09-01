import SwiftUI

@MainActor
struct SubpostsUnavailableView: View {
    let threadID: ThreadID
    let postID: PostID

    var body: some View {
        EmptyStateView(
            title: "楼中楼",
            message: "当前版本仅在帖子页显示楼中楼预览，完整楼中楼页面尚未提供。",
            systemImage: "text.bubble"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SemanticColor.background)
        .navigationTitle("楼中楼")
        .accessibilityElement(children: .combine)
        .accessibilityValue(
            "帖子 \(threadID.rawValue)，楼层 \(postID.rawValue)"
        )
        .accessibilityIdentifier(AppAccessibilityID.routeSubposts)
    }
}
