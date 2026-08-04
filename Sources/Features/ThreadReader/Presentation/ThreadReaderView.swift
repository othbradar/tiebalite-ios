import SwiftUI

@MainActor
struct ThreadReaderView: View {
    @Bindable var store: ThreadReaderStore
    let imageLoader: any ImageLoading
    let onOpenMedia: (ThreadMediaIntent) -> Void

    @State private var retryGeneration: UInt64 = 0

    var body: some View {
        ZStack {
            SemanticColor.background
            content
        }
        .background(SemanticColor.background)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            ThreadReaderAccessibilityID.screen(store.threadID)
        )
        .task(id: loadTaskID) {
            await store.loadIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .initialLoading:
            InitialLoadingView(title: "正在加载帖子")
        case .initialFailure:
            FullPageErrorView(
                title: "帖子加载失败",
                message: "这篇帖子暂时不可用。",
                retry: requestRetry
            )
            .accessibilityIdentifier(
                ThreadReaderAccessibilityID.failure(store.threadID)
            )
        case let .loaded(snapshot):
            reader(snapshot)
        }
    }

    private func reader(_ snapshot: ThreadReaderSnapshot) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.medium) {
                header(snapshot)

                ForEach(snapshot.posts) { post in
                    ThreadReaderPostView(
                        post: post,
                        imageLoader: imageLoader,
                        onOpenMedia: onOpenMedia
                    )
                    .id(post.id)
                }
            }
            .scrollTargetLayout()
            .padding(Spacing.medium)
        }
        .scrollPosition(id: readAnchorBinding, anchor: .top)
        .background(SemanticColor.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            ThreadReaderAccessibilityID.scroll(snapshot.threadID)
        )
    }

    private func header(_ snapshot: ThreadReaderSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(snapshot.title)
                .font(Typography.font(.title))
                .foregroundStyle(SemanticColor.primaryText)
                .textSelection(.enabled)
            Label(snapshot.forumName, systemImage: "rectangle.stack")
            Label(snapshot.author.displayName, systemImage: "person")
            Label("\(snapshot.replyCount) 条回复", systemImage: "bubble.left")
        }
        .font(Typography.font(.subheadline))
        .foregroundStyle(SemanticColor.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.medium)
        .background(SemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(
            ThreadReaderAccessibilityID.header(snapshot.threadID)
        )
    }

    private var readAnchorBinding: Binding<ThreadContentSource?> {
        Binding(
            get: { store.readAnchor },
            set: { store.setReadAnchor($0) }
        )
    }

    private var navigationTitle: String {
        store.state.snapshot?.forumName ?? "帖子"
    }

    private var loadTaskID: ThreadReaderLoadTaskID {
        ThreadReaderLoadTaskID(
            threadID: store.threadID,
            retryGeneration: retryGeneration
        )
    }

    private func requestRetry() {
        store.prepareRetry()
        retryGeneration &+= 1
    }
}

private struct ThreadReaderLoadTaskID: Hashable {
    let threadID: Int64
    let retryGeneration: UInt64
}

@MainActor
private struct ThreadReaderPostView: View {
    let post: ThreadReaderPost
    let imageLoader: any ImageLoading
    let onOpenMedia: (ThreadMediaIntent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Text(post.floorNumber == 1 ? "楼主" : "\(post.floorNumber) 楼")
                    .font(Typography.font(.headline))
                    .foregroundStyle(SemanticColor.primaryText)
                Spacer(minLength: Spacing.small)
                Text(post.author.displayName)
                    .font(Typography.font(.subheadline))
                    .foregroundStyle(SemanticColor.secondaryText)
            }

            Text(post.metadata)
                .font(Typography.font(.caption))
                .foregroundStyle(SemanticColor.secondaryText)

            ThreadContentRenderer(
                document: post.document,
                imageLoader: imageLoader,
                onOpenMedia: onOpenMedia
            )
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            ThreadReaderAccessibilityID.post(post.document.source)
        )
    }
}

enum ThreadReaderAccessibilityID {
    static func failure(_ threadID: Int64) -> String {
        "thread-reader.state.failure.t\(threadID)"
    }

    static func header(_ threadID: Int64) -> String {
        "thread-reader.header.t\(threadID)"
    }

    static func post(_ source: ThreadContentSource) -> String {
        "thread-reader.post.t\(source.threadID).p\(source.postID)"
            + ".s\(source.scope.rawValue)"
    }

    static func screen(_ threadID: Int64) -> String {
        "thread-reader.screen.t\(threadID)"
    }

    static func scroll(_ threadID: Int64) -> String {
        "thread-reader.scroll.t\(threadID)"
    }
}
