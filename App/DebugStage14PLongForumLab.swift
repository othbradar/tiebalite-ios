#if DEBUG && !UITESTING
import SwiftUI

enum DebugStage14PLongForumLabLaunch {
    static let flag = "--stage14p-long-forum-lab"

    static func isRequested(arguments: [String]) -> Bool {
        arguments.filter { $0 == flag }.count == 1
    }
}

@MainActor
struct DebugStage14PLongForumLabView: View {
    private let route: ForumRoute?
    @State private var store: ForumHomeStore?
    @State private var selectedThreadID: Int64?

    init() {
        let route = ForumRoute("Stage14P性能")
        self.route = route
        _store = State(
            initialValue: route.map {
                ForumHomeStore(
                    route: $0,
                    repository: DebugStage14PLongForumFixtureRepository()
                )
            }
        )
    }

    var body: some View {
        NavigationStack {
            if let route, let store {
                VStack(spacing: 0) {
                    Text(summary(store: store))
                        .font(Typography.font(.caption))
                        .foregroundStyle(SemanticColor.secondaryText)
                        .padding(Spacing.small)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SemanticColor.surface)
                        .accessibilityIdentifier("forum-home.debug.long-summary")

                    ForumHomeView(
                        store: store,
                        route: route,
                        onOpenThread: { thread in
                            selectedThreadID = thread.threadID
                        }
                    )
                }
                .navigationDestination(item: $selectedThreadID) { threadID in
                    VStack(spacing: Spacing.medium) {
                        Image(systemName: "doc.text")
                            .font(.system(size: IconSize.large))
                        Text("Debug Fixture 帖子")
                            .font(Typography.font(.title))
                        Text("ThreadID \(threadID)")
                            .font(Typography.font(.body))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SemanticColor.background)
                    .accessibilityIdentifier("forum-home.debug.fixture-thread")
                }
            } else {
                Text("invalid-static-route")
            }
        }
        .accessibilityIdentifier("forum-home.debug.long-lab")
    }

    private func summary(store: ForumHomeStore) -> String {
        let snapshot = store.state.snapshot
        return "items=\(snapshot?.threads.count ?? 0) "
            + "page=\(snapshot?.currentPage ?? 0) "
            + "has-more=\(snapshot?.hasMore == true)"
    }
}
#endif
