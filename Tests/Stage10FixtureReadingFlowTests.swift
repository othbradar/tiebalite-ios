import Testing
@testable import TiebaLite

@MainActor
struct Stage10FixtureReadingFlowTests {
    @Test
    func fixtureCatalogProvidesStableRecommendationAndThreadIdentities() async throws {
        let recommendationRepository = FixtureRecommendationRepository()
        let threadRepository = FixtureThreadReaderRepository()

        let recommendations = try await recommendationRepository
            .loadRecommendations()

        #expect(recommendations.count == 12)
        #expect(Set(recommendations.map(\.threadID)).count == 12)
        #expect(recommendations.allSatisfy { $0.threadID > 0 })
        #expect(recommendations.contains { $0.thumbnail != nil })
        #expect(recommendations.contains { $0.thumbnail == nil })
        #expect(recommendations.contains { $0.title.count > 40 })

        for recommendation in recommendations {
            let snapshot = try await threadRepository.loadThread(
                threadID: recommendation.threadID
            )
            #expect(snapshot.threadID == recommendation.threadID)
            #expect(snapshot.title == recommendation.title)
            #expect(!snapshot.posts.isEmpty)
            #expect(
                snapshot.posts.allSatisfy {
                    $0.document.source.threadID == recommendation.threadID
                }
            )
            #expect(
                Set(snapshot.posts.map(\.id)).count == snapshot.posts.count
            )
        }
    }

    @Test
    func recommendationsStoreLoadsOnceAndNormalizesFailure() async {
        let fixtures = [Self.recommendation(threadID: 101)]
        let successRepository = RecordingRecommendationRepository(
            result: .success(fixtures)
        )
        let successStore = RecommendationsStore(
            repository: successRepository
        )

        await successStore.loadIfNeeded()
        await successStore.loadIfNeeded()

        #expect(successStore.state == .loaded(fixtures))
        #expect(await successRepository.callCount() == 1)

        let emptyStore = RecommendationsStore(
            repository: RecordingRecommendationRepository(
                result: .success([])
            )
        )
        await emptyStore.loadIfNeeded()
        #expect(emptyStore.state == .empty)

        let failureRepository = RecordingRecommendationRepository(
            result: .failure(FixtureReadingRepositoryError.unavailable)
        )
        let failureStore = RecommendationsStore(
            repository: failureRepository
        )

        await failureStore.loadIfNeeded()

        #expect(failureStore.state == .initialFailure(.unavailable))
        #expect(await failureRepository.callCount() == 1)
    }

    @Test
    func selectedRecommendationCreatesOneStableThreadRoute() throws {
        let recommendation = Self.recommendation(threadID: 100_003)
        let route = try #require(AppRouter.threadRoute(for: recommendation))
        let expectedID = try #require(ThreadID(recommendation.threadID))
        let navigation = AppNavigationStore()

        #expect(route == .thread(expectedID))
        #expect(navigation.push(route, in: .recommendations))
        #expect(navigation.push(route, in: .recommendations))
        #expect(
            navigation.state.routes(for: .recommendations) == [route]
        )
    }

    @Test
    func threadReaderLoadsRequestedFixtureOnceAndKeepsMediaOrder() async throws {
        let repository = RecordingThreadReaderRepository(
            wrapped: FixtureThreadReaderRepository()
        )
        let store = ThreadReaderStore(
            threadID: 100_003,
            repository: repository
        )

        await store.loadIfNeeded()
        await store.loadIfNeeded()

        let snapshot = try #require(store.state.snapshot)
        #expect(snapshot.threadID == 100_003)
        #expect(await repository.requestedThreadIDs() == [100_003])

        let firstPost = try #require(snapshot.posts.first)
        let imageNodes: [ThreadImageContent] = firstPost.document.nodes
            .compactMap { node -> ThreadImageContent? in
            guard case let .image(content) = node.payload else {
                return nil
            }
            return content
            }
        #expect(imageNodes.count == 3)

        let selected = imageNodes[1].mediaID
        let intent = try #require(
            firstPost.document.mediaIntent(selecting: selected)
        )
        #expect(intent.initialMediaID == selected)
        #expect(intent.items.map(\.mediaID) == imageNodes.map(\.mediaID))

        let failureStore = ThreadReaderStore(
            threadID: 100_003,
            repository: FailingThreadReaderRepository()
        )
        await failureStore.loadIfNeeded()
        #expect(failureStore.state == .initialFailure(.unavailable))
    }

    @Test
    func mismatchedThreadSnapshotFailsAndAllowsRetry() async {
        let repository = MismatchedThreadReaderRepository()
        let store = ThreadReaderStore(
            threadID: 100_003,
            repository: repository
        )

        await store.loadIfNeeded()
        #expect(store.state == .initialFailure(.unavailable))

        store.prepareRetry()
        await store.loadIfNeeded()
        #expect(store.state == .initialFailure(.unavailable))
        #expect(await repository.callCount() == 2)
    }

    @Test
    func cancelledInitialLoadsNeverBecomeLoadedOrFailure() async {
        let recommendationGate = HarnessContinuationGate<
            [RecommendationSummary]
        >()
        let recommendationsStore = RecommendationsStore(
            repository: CancellableRecommendationRepository(
                gate: recommendationGate
            )
        )
        let recommendationTask = Task {
            await recommendationsStore.loadIfNeeded()
        }
        await Task.yield()
        recommendationTask.cancel()
        await recommendationTask.value
        #expect(recommendationsStore.state == .initialLoading)

        let threadGate = HarnessContinuationGate<ThreadReaderSnapshot>()
        let threadStore = ThreadReaderStore(
            threadID: 100_003,
            repository: CancellableThreadReaderRepository(gate: threadGate)
        )
        let threadTask = Task {
            await threadStore.loadIfNeeded()
        }
        await Task.yield()
        threadTask.cancel()
        await threadTask.value
        #expect(threadStore.state == .initialLoading)
    }

    @Test
    func sceneRegistryReusesRouteStoreAndReleasesPoppedRoute() throws {
        let recommendationStore = RecommendationsStore(
            repository: RecordingRecommendationRepository(result: .success([]))
        )
        let repository = FixtureThreadReaderRepository()
        let registry = AppFeatureStoreRegistry(
            followedForumsStore: FollowedForumsStore(
                repository: FixtureFollowedForumsRepository()
            ),
            recommendationsStore: recommendationStore,
            makeThreadReaderStore: { threadID in
                ThreadReaderStore(
                    threadID: threadID,
                    repository: repository
                )
            }
        )
        let threadID = try #require(ThreadID(100_003))

        weak var released: ThreadReaderStore?
        do {
            let first = registry.threadReaderStore(
                for: .recommendations,
                threadID: threadID
            )
            let second = registry.threadReaderStore(
                for: .recommendations,
                threadID: threadID
            )
            released = first

            #expect(first === second)
            registry.retainThreadStores(in: AppNavigationState())
        }

        #expect(released == nil)
    }

    private static func recommendation(
        threadID: Int64
    ) -> RecommendationSummary {
        RecommendationSummary(
            threadID: threadID,
            title: "Fixture thread \(threadID)",
            forumName: "Fixture forum",
            authorName: "Fixture author",
            replyCount: 3,
            thumbnail: nil
        )
    }
}

private actor RecordingRecommendationRepository: RecommendationRepository {
    private let result: Result<
        [RecommendationSummary],
        FixtureReadingRepositoryError
    >
    private var calls = 0

    init(
        result: Result<
            [RecommendationSummary],
            FixtureReadingRepositoryError
        >
    ) {
        self.result = result
    }

    func loadRecommendations() async throws -> [RecommendationSummary] {
        calls += 1
        return try result.get()
    }

    func callCount() -> Int {
        calls
    }
}

private actor RecordingThreadReaderRepository: ThreadReaderRepository {
    private let wrapped: any ThreadReaderRepository
    private var threadIDs: [Int64] = []

    init(wrapped: any ThreadReaderRepository) {
        self.wrapped = wrapped
    }

    func loadThread(threadID: Int64) async throws -> ThreadReaderSnapshot {
        threadIDs.append(threadID)
        return try await wrapped.loadThread(threadID: threadID)
    }

    func requestedThreadIDs() -> [Int64] {
        threadIDs
    }
}

private actor MismatchedThreadReaderRepository: ThreadReaderRepository {
    private var calls = 0

    func loadThread(threadID: Int64) async throws -> ThreadReaderSnapshot {
        _ = threadID
        calls += 1
        return try await FixtureThreadReaderRepository().loadThread(
            threadID: 100_004
        )
    }

    func callCount() -> Int {
        calls
    }
}

private struct CancellableRecommendationRepository: RecommendationRepository {
    let gate: HarnessContinuationGate<[RecommendationSummary]>

    func loadRecommendations() async throws -> [RecommendationSummary] {
        try await withTaskCancellationHandler {
            try await gate.wait()
        } onCancel: {
            gate.cancel()
        }
    }
}

private struct CancellableThreadReaderRepository: ThreadReaderRepository {
    let gate: HarnessContinuationGate<ThreadReaderSnapshot>

    func loadThread(threadID: Int64) async throws -> ThreadReaderSnapshot {
        _ = threadID
        return try await withTaskCancellationHandler {
            try await gate.wait()
        } onCancel: {
            gate.cancel()
        }
    }
}

private struct FailingThreadReaderRepository: ThreadReaderRepository {
    func loadThread(threadID: Int64) async throws -> ThreadReaderSnapshot {
        _ = threadID
        throw FixtureReadingRepositoryError.unavailable
    }
}
