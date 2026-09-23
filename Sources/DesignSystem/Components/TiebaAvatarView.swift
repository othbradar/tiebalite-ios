import SwiftUI

struct TiebaAvatarView: View {
    let resource: ImageResourceDescriptor?
    let imageLoader: any ImageLoading
    var size: CGFloat = TiebaParityTokens.userAvatarSize
    var accessibilityLabel = "用户头像"

    var body: some View {
        TiebaRemoteImageView(
            resource: resource,
            imageLoader: imageLoader,
            purpose: .avatar,
            accessibilityLabel: accessibilityLabel
        )
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct TiebaForumAvatarView: View {
    let resource: ImageResourceDescriptor?
    let imageLoader: any ImageLoading
    var size: CGFloat = TiebaParityTokens.forumAvatarSize

    var body: some View {
        TiebaAvatarView(
            resource: resource,
            imageLoader: imageLoader,
            size: size,
            accessibilityLabel: "吧头像"
        )
    }
}
