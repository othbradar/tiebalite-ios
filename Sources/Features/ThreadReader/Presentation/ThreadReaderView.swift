import SwiftUI
import UIKit

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
        .onDisappear {
            store.cancel()
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
        case let .loaded(snapshot),
             let .loadingNextPage(snapshot),
             let .nextPageFailure(snapshot):
            reader(snapshot)
        }
    }

    @ViewBuilder
    private func reader(_ snapshot: ThreadReaderSnapshot) -> some View {
        if let presentation = store.listPresentation {
            VirtualizedList(
                items: presentation.rows,
                backgroundColor: .systemBackground,
                accessibilityIdentifier:
                    ThreadReaderAccessibilityID.scroll(snapshot.threadID),
                restoredAnchor: store.readAnchor,
                onPrefetch: { rowIDs in
                    guard rowIDs.contains(where: {
                        presentation.prefetchRowIDs.contains($0)
                    }) else {
                        return
                    }
                    requestNextPage()
                },
                onScrollSettled: store.setReadAnchor,
                rowContent: { row in
                    ThreadReaderRowView(
                        row: row,
                        imageLoader: imageLoader,
                        onOpenMedia: onOpenMedia,
                        requestNextPage: requestNextPage
                    )
                }
            )
            .background(SemanticColor.background)
            .accessibilityElement(children: .contain)
        } else {
            InitialLoadingView(title: "正在加载帖子")
        }
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

    private func requestNextPage() {
        Task { @MainActor in
            await store.loadNextPage()
        }
    }
}

private struct ThreadReaderLoadTaskID: Hashable {
    let threadID: Int64
    let retryGeneration: UInt64
}

@MainActor
private struct ThreadReaderRowView: View {
    let row: ThreadReaderRowModel
    let imageLoader: any ImageLoading
    let onOpenMedia: (ThreadMediaIntent) -> Void
    let requestNextPage: () -> Void

    @ViewBuilder
    var body: some View {
        switch row.content {
        case let .header(header):
            ThreadReaderHeaderView(header: header)
                .padding(.top, Spacing.medium)
                .padding(.bottom, Spacing.small)
        case let .post(post):
            ThreadReaderPostView(
                post: post,
                imageLoader: imageLoader,
                onOpenMedia: onOpenMedia
            )
            .padding(.vertical, Spacing.small)
        case let .pagination(pagination):
            ThreadReaderPaginationView(
                pagination: pagination,
                requestNextPage: requestNextPage
            )
            .padding(.vertical, Spacing.medium)
        }
    }
}

@MainActor
private struct ThreadReaderHeaderView: View {
    let header: ThreadReaderHeaderRowModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(header.title)
                .font(Typography.font(.title))
                .foregroundStyle(SemanticColor.primaryText)
                .textSelection(.enabled)
            Label(header.forumName, systemImage: "rectangle.stack")
            Label(header.authorName, systemImage: "person")
            Label("\(header.replyCount) 条回复", systemImage: "bubble.left")
        }
        .font(Typography.font(.subheadline))
        .foregroundStyle(SemanticColor.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.medium)
        .background(SemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.horizontal, Spacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(
            ThreadReaderAccessibilityID.header(header.threadID)
        )
    }
}

@MainActor
private struct ThreadReaderPostView: View {
    let post: ThreadReaderPostRowModel
    let imageLoader: any ImageLoading
    let onOpenMedia: (ThreadMediaIntent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Text(post.floorNumber == 1 ? "楼主" : "\(post.floorNumber) 楼")
                    .font(Typography.font(.headline))
                    .foregroundStyle(SemanticColor.primaryText)
                Spacer(minLength: Spacing.small)
                Text(post.authorName)
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

            if !post.inlineSubposts.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    ForEach(post.inlineSubposts) { subpost in
                        ThreadReaderSubpostView(
                            subpost: subpost,
                            imageLoader: imageLoader,
                            onOpenMedia: onOpenMedia
                        )
                    }

                    if post.remainingSubpostCount > 0 {
                        Text("查看全部 \(post.totalSubpostCount) 条回复")
                            .font(Typography.font(.caption))
                            .foregroundStyle(SemanticColor.secondaryText)
                    }
                }
                .padding(Spacing.small)
                .background(SemanticColor.background)
                .clipShape(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                )
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.horizontal, Spacing.medium)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            ThreadReaderAccessibilityID.post(post.source)
        )
    }
}

@MainActor
private struct ThreadReaderSubpostView: View {
    let subpost: ThreadReaderSubpostRowModel
    let imageLoader: any ImageLoading
    let onOpenMedia: (ThreadMediaIntent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                Text(subpost.authorName)
                    .font(Typography.font(.subheadline))
                    .foregroundStyle(SemanticColor.primaryText)
                if let replyTo = subpost.replyToDisplayName {
                    Text("回复 \(replyTo)")
                        .font(Typography.font(.caption))
                        .foregroundStyle(SemanticColor.secondaryText)
                }
                Spacer(minLength: Spacing.xSmall)
                Text(subpost.metadata)
                    .font(Typography.font(.caption))
                    .foregroundStyle(SemanticColor.secondaryText)
            }

            if subpost.document.isVisiblyEmpty {
                Text("回复内容暂不可用")
                    .font(Typography.font(.body))
                    .foregroundStyle(SemanticColor.secondaryText)
            } else {
                ThreadContentRenderer(
                    document: subpost.document,
                    imageLoader: imageLoader,
                    onOpenMedia: onOpenMedia
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            ThreadReaderAccessibilityID.subpost(subpost.document.source)
        )
    }
}

@MainActor
private struct ThreadReaderPaginationView: View {
    let pagination: ThreadReaderPaginationRowModel
    let requestNextPage: () -> Void

    @ViewBuilder
    var body: some View {
        switch pagination.state {
        case .end:
            PaginationFooter(state: .end, retry: {})
        case .failure:
            PaginationFooter(
                state: .failure,
                retry: requestNextPage
            )
        case .loading:
            PaginationFooter(state: .loading, retry: {})
        case .loadMore:
            Button("加载更多", action: requestNextPage)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier(
                    ThreadReaderAccessibilityID.loadMore(
                        pagination.threadID
                    )
                )
        }
    }
}

enum ThreadReaderAccessibilityID {
    static func failure(_ threadID: Int64) -> String {
        "thread-reader.state.failure.t\(threadID)"
    }

    static func header(_ threadID: Int64) -> String {
        "thread-reader.header.t\(threadID)"
    }

    static func loadMore(_ threadID: Int64) -> String {
        "thread-reader.pagination.load-more.t\(threadID)"
    }

    static func post(_ source: ThreadContentSource) -> String {
        "thread-reader.post.t\(source.threadID).p\(source.postID)"
            + ".s\(source.scope.rawValue)"
    }

    static func screen(_ threadID: Int64) -> String {
        "thread-reader.screen.t\(threadID)"
    }

    static func subpost(_ source: ThreadContentSource) -> String {
        "thread-reader.subpost.t\(source.threadID).p\(source.postID)"
            + ".s\(source.scope.rawValue)"
    }

    static func scroll(_ threadID: Int64) -> String {
        "thread-reader.scroll.t\(threadID)"
    }
}
