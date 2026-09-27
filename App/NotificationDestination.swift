import SwiftUI

struct NotificationDestination: View {
    @Bindable var store: NotificationDestinationStore
    let dependencies: AppRouteDependencies
    let openRoute: (RouteIdentity) -> Void
    @State private var retry: UInt64 = 0

    var body: some View {
        Group {
            if let thread = store.thread {
                ThreadReaderView(
                    store: thread, imageLoader: dependencies.imageLoader,
                    accountAvatar: dependencies.currentAccountAvatar,
                    readingTextSize: dependencies.featureStores.settingsStore.readingTextSize,
                    onOpenMedia: dependencies.onOpenMedia, onOpenUser: { openRoute(.userProfile($0)) },
                    onDisplayed: { await dependencies.featureStores.browsingHistoryStore.recordThread($0) },
                    onOpenSubposts: { source in
                        if let thread = ThreadID(source.threadID), let post = PostID(source.postID) {
                            openRoute(.subposts(threadID: thread, postID: post))
                        }
                    })
            } else if store.failed {
                FullPageErrorView(title: "无法打开这条消息", message: "内容可能已删除或暂时不可用，请稍后重试。") { retry &+= 1 }
                    .accessibilityIdentifier("notifications.destination.failure")
            } else { InitialLoadingView(title: "正在定位回复") }
        }
        .background(SemanticColor.background).ignoresSafeArea(.container, edges: .bottom)
        .task(id: retry) { await store.load() }
    }
}
