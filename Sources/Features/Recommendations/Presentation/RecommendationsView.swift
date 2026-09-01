import SwiftUI
import UIKit

@MainActor
struct RecommendationsView: View {
    @Bindable var store: RecommendationsStore
    let imageLoader: any ImageLoading
    let onOpenThread: (RecommendationSummary) -> Void

    @State private var retryGeneration: UInt64 = 0

    var body: some View {
        VStack(spacing: 0) {
            Text("TiebaLite")
                .font(Typography.font(.largeTitle))
                .foregroundStyle(SemanticColor.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.large)
                .padding(.top, Spacing.small)
                .accessibilityIdentifier(
                    RecommendationsAccessibilityID.shellTitle
                )

            content
        }
        .background(SemanticColor.background)
        .navigationTitle("推荐")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(RecommendationsAccessibilityID.root)
        .task(id: retryGeneration) {
            await loadStoreAcrossProjection()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .initialLoading:
            InitialLoadingView(title: "正在加载推荐")
                .accessibilityIdentifier(
                    RecommendationsAccessibilityID.initialLoading
                )
        case let .loaded(items),
             let .loadingNextPage(items),
             let .nextPageFailure(items),
             let .refreshing(items),
             let .refreshFailure(items):
            recommendationList(items)
        case .empty:
            EmptyStateView(
                title: "暂无推荐",
                message: "当前没有可显示的帖子。",
                systemImage: "rectangle.stack"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SemanticColor.background)
            .accessibilityIdentifier(RecommendationsAccessibilityID.empty)
        case .initialFailure:
            FullPageErrorView(
                title: "推荐加载失败",
                message: "推荐服务暂时不可用。",
                retry: requestRetry
            )
            .accessibilityIdentifier(RecommendationsAccessibilityID.failure)
        }
    }

    private func recommendationList(
        _ items: [RecommendationSummary]
    ) -> some View {
        ScrollView {
            LazyVStack(spacing: Spacing.medium) {
                ForEach(items) { item in
                    Button {
                        onOpenThread(item)
                    } label: {
                        RecommendationRow(
                            item: item,
                            imageLoader: imageLoader
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("打开只读帖子")
                    .accessibilityIdentifier(
                        RecommendationsAccessibilityID.row(item.threadID)
                    )
                    .id(item.threadID)
                    .task(id: RecommendationPrefetchTaskID(
                        threadID: item.threadID,
                        nextPage: store.nextPage
                    )) {
                        store.requestNextPage(after: item.threadID)
                    }
                }

                PaginationFooter(
                    state: paginationFooterState,
                    retry: requestNextPage
                )
            }
            .scrollTargetLayout()
            .padding(Spacing.medium)
        }
        .scrollPosition(id: scrollAnchorBinding, anchor: .center)
        .background(SemanticColor.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(RecommendationsAccessibilityID.list)
    }

    private var scrollAnchorBinding: Binding<Int64?> {
        Binding(
            get: { store.scrollAnchor },
            set: { store.setScrollAnchor($0) }
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

    private func loadStoreAcrossProjection() async {
        let operation = Task { @MainActor in
            await store.loadIfNeeded()
        }
        await operation.value
    }

    private var paginationFooterState: PaginationFooterState {
        switch store.state {
        case .loadingNextPage:
            .loading
        case .nextPageFailure:
            .failure
        case .loaded, .refreshing, .refreshFailure:
            store.nextPage == nil ? .end : .idle
        case .empty, .initialFailure, .initialLoading:
            .idle
        }
    }
}

private struct RecommendationPrefetchTaskID: Hashable {
    let threadID: Int64
    let nextPage: UInt32?
}

@MainActor
private struct RecommendationRow: View {
    let item: RecommendationSummary
    let imageLoader: any ImageLoading

    var body: some View {
        ContentSummaryCard(
            title: item.title,
            primaryMetadata: item.forumName,
            primarySystemImage: "rectangle.stack",
            secondaryMetadata: item.authorName,
            secondarySystemImage: "person",
            trailingMetadata: "\(item.replyCount)",
            trailingAccessibilityLabel: "\(item.replyCount) 条回复"
        ) {
            if let thumbnail = item.thumbnail {
                RecommendationThumbnailView(
                    threadID: item.threadID,
                    thumbnail: thumbnail,
                    imageLoader: imageLoader
                )
            }
        }
    }
}

@MainActor
private struct RecommendationThumbnailView: View {
    enum Phase {
        case failed
        case loading
        case rendered
    }

    let threadID: Int64
    let thumbnail: RecommendationThumbnail
    let imageLoader: any ImageLoading

    @Environment(\.displayScale) private var displayScale
    @State private var phase = Phase.loading
    @State private var image: UIImage?
    @State private var targetPixelSize: ImageTargetPixelSize?

    var body: some View {
        ZStack {
            SemanticColor.background

            switch phase {
            case .loading:
                ProgressView()
            case .rendered:
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .accessibilityHidden(true)
                }
            case .failed:
                Image(systemName: "photo.badge.exclamationmark")
                    .foregroundStyle(SemanticColor.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
        .accessibilityLabel(thumbnail.alternativeText)
        .accessibilityValue(phase.accessibilityValue)
        .accessibilityIdentifier(
            RecommendationsAccessibilityID.thumbnail(threadID)
        )
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            targetPixelSize = ImageTargetPixelSize.normalized(
                pointWidth: size.width,
                pointHeight: size.height,
                displayScale: displayScale,
                purpose: .listThumbnail
            )
        }
        .task(id: RecommendationThumbnailTaskID(
            resource: thumbnail.resource,
            targetPixelSize: targetPixelSize
        )) {
            await load()
        }
        .onDisappear {
            image = nil
        }
    }

    private func load() async {
        phase = .loading
        image = nil
        guard let targetPixelSize else {
            return
        }
        do {
            let payload = try await imageLoader.load(
                ImageRequest(
                    resource: thumbnail.resource,
                    targetPixelSize: targetPixelSize,
                    purpose: .listThumbnail,
                    resizeMode: .fill
                )
            )
            try Task.checkCancellation()
            guard let decoded = payload.displayImage() else {
                phase = .failed
                return
            }
            image = decoded
            phase = .rendered
        } catch is CancellationError {
            return
        } catch {
            phase = .failed
        }
    }
}

private struct RecommendationThumbnailTaskID: Hashable {
    let resource: ImageResourceDescriptor
    let targetPixelSize: ImageTargetPixelSize?
}

private extension RecommendationThumbnailView.Phase {
    var accessibilityValue: String {
        switch self {
        case .loading:
            "正在加载"
        case .rendered:
            "已加载"
        case .failed:
            "加载失败"
        }
    }
}

enum RecommendationsAccessibilityID {
    static let empty = "recommendations.state.empty"
    static let failure = "recommendations.state.failure"
    static let initialLoading = "recommendations.state.initial-loading"
    static let list = "recommendations.list"
    static let root = "app.root.recommendations"
    static let shellTitle = "app.shell.title"

    static func row(_ threadID: Int64) -> String {
        "recommendations.row.t\(threadID)"
    }

    static func thumbnail(_ threadID: Int64) -> String {
        "recommendations.thumbnail.t\(threadID)"
    }
}
