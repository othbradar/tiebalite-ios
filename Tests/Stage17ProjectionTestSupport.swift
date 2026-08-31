import Observation
import SwiftUI
@testable import TiebaLite
import UIKit

@MainActor
enum Stage17ProjectionSupport {
    static func makeWindow<Content: View>(
        host: UIHostingController<Content>
    ) -> UIWindow {
        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 1_024, height: 768)
        )
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }

    static func settleChanges() async {
        for _ in 0..<100 {
            await Task.yield()
        }
    }

    static func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
    }
}

@MainActor
@Observable
final class Stage17Visibility {
    var isPresented = true
}

@MainActor
struct Stage17ForumProjectionHarness: View {
    @Bindable var visibility: Stage17Visibility
    let store: ForumHomeStore
    let route: ForumRoute
    var onDisplayed: (ForumSummary) async -> Void = { _ in }

    var body: some View {
        if visibility.isPresented {
            ForumHomeView(
                store: store,
                route: route,
                onOpenThread: { _ in },
                onDisplayed: onDisplayed
            )
        } else {
            Color.clear
        }
    }
}

actor Stage17AsyncCounter {
    private(set) var count = 0
    private var observers: [(Int, HarnessContinuationGate<Void>)] = []

    func increment() {
        count += 1
        var retained: [(Int, HarnessContinuationGate<Void>)] = []
        for observer in observers {
            if count >= observer.0 {
                observer.1.succeed(())
            } else {
                retained.append(observer)
            }
        }
        observers = retained
    }

    func waitForCount(_ expected: Int) async throws {
        guard count < expected else {
            return
        }
        let gate = HarnessContinuationGate<Void>()
        observers.append((expected, gate))
        try await gate.wait()
    }
}

@MainActor
struct Stage17ThreadProjectionHarness: View {
    @Bindable var visibility: Stage17Visibility
    let store: ThreadReaderStore

    var body: some View {
        if visibility.isPresented {
            ThreadReaderView(
                store: store,
                imageLoader: DisabledImageLoader(),
                onOpenMedia: { _ in }
            )
        } else {
            Color.clear
        }
    }
}

@MainActor
struct Stage17RecommendationProjectionHarness: View {
    @Bindable var visibility: Stage17Visibility
    let store: RecommendationsStore

    var body: some View {
        if visibility.isPresented {
            RecommendationsView(
                store: store,
                imageLoader: DisabledImageLoader(),
                onOpenThread: { _ in }
            )
        } else {
            Color.clear
        }
    }
}

@MainActor
struct Stage17FollowedProjectionHarness: View {
    @Bindable var visibility: Stage17Visibility
    let store: FollowedForumsStore
    let access: FollowedForumsSessionAccess

    var body: some View {
        if visibility.isPresented {
            FollowedForumsView(
                store: store,
                sessionAccess: access,
                openLogin: {},
                openForum: { _ in }
            )
        } else {
            Color.clear
        }
    }
}

enum Stage17ControlledRepositoryError: Error {
    case missingCall
}

actor Stage17ControlledForumRepository: ForumHomeRepository {
    private struct PendingCall {
        let request: ForumHomePageRequest
        let gate: HarnessContinuationGate<ForumHomeSnapshot>
    }

    private var calls = 0
    private var pending: [Int: PendingCall] = [:]
    private var countObservers: [(Int, HarnessContinuationGate<Void>)] = []

    func loadForumHomePage(
        _ request: ForumHomePageRequest
    ) async throws -> ForumHomeSnapshot {
        calls += 1
        let call = calls
        let gate = HarnessContinuationGate<ForumHomeSnapshot>()
        pending[call] = PendingCall(request: request, gate: gate)
        resumeCountObservers()
        do {
            return try await withTaskCancellationHandler {
                try await gate.wait()
            } onCancel: {
                gate.cancel()
            }
        } catch {
            pending.removeValue(forKey: call)
            throw error
        }
    }

    func waitForCallCount(_ expected: Int) async throws {
        guard calls < expected else {
            return
        }
        let gate = HarnessContinuationGate<Void>()
        countObservers.append((expected, gate))
        try await gate.wait()
    }

    func callCount() -> Int {
        calls
    }

    func succeedLatest() async throws {
        guard let call = pending.keys.max(),
              let pendingCall = pending.removeValue(forKey: call) else {
            throw Stage17ControlledRepositoryError.missingCall
        }
        let snapshot = try await FixtureForumHomeRepository()
            .loadForumHomePage(pendingCall.request)
        guard pendingCall.gate.succeed(snapshot) else {
            throw Stage17ControlledRepositoryError.missingCall
        }
    }

    private func resumeCountObservers() {
        var retained: [(Int, HarnessContinuationGate<Void>)] = []
        for observer in countObservers {
            if calls >= observer.0 {
                observer.1.succeed(())
            } else {
                retained.append(observer)
            }
        }
        countObservers = retained
    }
}

actor Stage17ControlledThreadRepository: ThreadReaderRepository {
    private struct PendingCall {
        let request: ThreadReaderPageRequest
        let gate: HarnessContinuationGate<ThreadReaderSnapshot>
    }

    private var calls = 0
    private var pending: [Int: PendingCall] = [:]
    private var countObservers: [(Int, HarnessContinuationGate<Void>)] = []

    func loadPage(
        _ request: ThreadReaderPageRequest
    ) async throws -> ThreadReaderSnapshot {
        calls += 1
        let call = calls
        let gate = HarnessContinuationGate<ThreadReaderSnapshot>()
        pending[call] = PendingCall(request: request, gate: gate)
        resumeCountObservers()
        do {
            return try await withTaskCancellationHandler {
                try await gate.wait()
            } onCancel: {
                gate.cancel()
            }
        } catch {
            pending.removeValue(forKey: call)
            throw error
        }
    }

    func waitForCallCount(_ expected: Int) async throws {
        guard calls < expected else {
            return
        }
        let gate = HarnessContinuationGate<Void>()
        countObservers.append((expected, gate))
        try await gate.wait()
    }

    func callCount() -> Int {
        calls
    }

    func succeedLatest() async throws {
        guard let call = pending.keys.max(),
              let pendingCall = pending.removeValue(forKey: call) else {
            throw Stage17ControlledRepositoryError.missingCall
        }
        let snapshot = try await FixtureThreadReaderRepository()
            .loadPage(pendingCall.request)
        guard pendingCall.gate.succeed(snapshot) else {
            throw Stage17ControlledRepositoryError.missingCall
        }
    }

    private func resumeCountObservers() {
        var retained: [(Int, HarnessContinuationGate<Void>)] = []
        for observer in countObservers {
            if calls >= observer.0 {
                observer.1.succeed(())
            } else {
                retained.append(observer)
            }
        }
        countObservers = retained
    }
}

actor Stage17ControlledRecRepository: RecommendationRepository {
    private struct PendingCall {
        let request: RecommendationPageRequest
        let gate: HarnessContinuationGate<RecommendationRepositoryPage>
    }

    private var calls = 0
    private var pending: [Int: PendingCall] = [:]
    private var countObservers: [(Int, HarnessContinuationGate<Void>)] = []

    func loadRecommendations() async throws -> [RecommendationSummary] {
        try await loadPage(.initial).items
    }

    func loadPage(
        _ request: RecommendationPageRequest
    ) async throws -> RecommendationRepositoryPage {
        calls += 1
        let call = calls
        let gate = HarnessContinuationGate<RecommendationRepositoryPage>()
        pending[call] = PendingCall(request: request, gate: gate)
        resumeCountObservers()
        do {
            return try await withTaskCancellationHandler {
                try await gate.wait()
            } onCancel: {
                gate.cancel()
            }
        } catch {
            pending.removeValue(forKey: call)
            throw error
        }
    }

    func waitForCallCount(_ expected: Int) async throws {
        guard calls < expected else {
            return
        }
        let gate = HarnessContinuationGate<Void>()
        countObservers.append((expected, gate))
        try await gate.wait()
    }

    func callCount() -> Int {
        calls
    }

    func succeedLatest() async throws {
        guard let call = pending.keys.max(),
              let pendingCall = pending.removeValue(forKey: call) else {
            throw Stage17ControlledRepositoryError.missingCall
        }
        let page = try await FixtureRecommendationRepository()
            .loadPage(pendingCall.request)
        guard pendingCall.gate.succeed(page) else {
            throw Stage17ControlledRepositoryError.missingCall
        }
    }

    private func resumeCountObservers() {
        var retained: [(Int, HarnessContinuationGate<Void>)] = []
        for observer in countObservers {
            if calls >= observer.0 {
                observer.1.succeed(())
            } else {
                retained.append(observer)
            }
        }
        countObservers = retained
    }
}

actor Stage17ControlledFollowedRepository: FollowedForumsRepository {
    private var calls = 0
    private var pending: [Int: HarnessContinuationGate<[FollowedForum]>] = [:]
    private var countObservers: [(Int, HarnessContinuationGate<Void>)] = []

    func loadFollowedForums(
        authentication: AuthContext
    ) async throws -> [FollowedForum] {
        _ = authentication
        calls += 1
        let call = calls
        let gate = HarnessContinuationGate<[FollowedForum]>()
        pending[call] = gate
        resumeCountObservers()
        do {
            return try await withTaskCancellationHandler {
                try await gate.wait()
            } onCancel: {
                gate.cancel()
            }
        } catch {
            pending.removeValue(forKey: call)
            throw error
        }
    }

    func waitForCallCount(_ expected: Int) async throws {
        guard calls < expected else {
            return
        }
        let gate = HarnessContinuationGate<Void>()
        countObservers.append((expected, gate))
        try await gate.wait()
    }

    func callCount() -> Int {
        calls
    }

    func succeedLatest(
        authentication access: FollowedForumsSessionAccess
    ) async throws {
        guard case .active = access,
              let call = pending.keys.max(),
              let gate = pending.removeValue(forKey: call) else {
            throw Stage17ControlledRepositoryError.missingCall
        }
        let forums = [
            FollowedForum(
                forumID: 13_001,
                name: "Swift开发",
                avatarResourceID: nil,
                hotCount: 17,
                memberCount: 1_700,
                threadCount: 170,
                levelID: 7,
                levelName: "七级",
                isSignedToday: false
            )
        ]
        guard gate.succeed(forums) else {
            throw Stage17ControlledRepositoryError.missingCall
        }
    }

    private func resumeCountObservers() {
        var retained: [(Int, HarnessContinuationGate<Void>)] = []
        for observer in countObservers {
            if calls >= observer.0 {
                observer.1.succeed(())
            } else {
                retained.append(observer)
            }
        }
        countObservers = retained
    }
}
