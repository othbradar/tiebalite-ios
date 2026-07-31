import SwiftUI

#Preview("Initial loading") {
    InitialLoadingView()
}

#Preview("Inline loading") {
    InlineLoadingView()
        .padding()
}

#Preview("Empty state") {
    EmptyStateView(
        title: "暂无内容",
        message: "固定 fixture 当前没有可显示的项目。",
        systemImage: "tray"
    )
}

#Preview("Full-page error") {
    FullPageErrorView(
        title: "加载失败",
        message: "请检查后重试。",
        retry: {}
    )
}

#Preview("Inline error") {
    InlineErrorView(message: "加载更多失败", retry: {})
        .padding()
}

#Preview("Pagination footer") {
    PaginationFooter(state: .loading, retry: {})
        .padding()
}
