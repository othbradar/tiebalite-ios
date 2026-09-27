import Foundation
import Testing
@testable import TiebaLite

struct R12AccountIdentityTests {
    @Test func identityReadsOnlyVerifiedPublicFieldsWithoutRequiringWriteTokens() throws {
        let route = try CurrentAccountIdentity.decode(Data(
            #"{"error_code":0,"user":{"id":"12001","name":"样本用户","portrait":"fixture-portrait"}}"#.utf8))
        #expect(route.userID.rawValue == 12_001)
        #expect(route.fallbackDisplayName == "样本用户")
        #expect(route.portraitResourceID == "fixture-portrait")
    }

    @Test func invalidOrMissingIdentityCannotBecomeAnotherUser() {
        for json in [#"{"error_code":0,"user":{"id":"0"}}"#, #"{"error_code":0}"#,
                     #"{"user":{"id":"12001"}}"#, #"{"error_code":4,"user":{"id":"12001"}}"#,
                     "callback({});"] {
            #expect(throws: (any Error).self) { try CurrentAccountIdentity.decode(Data(json.utf8)) }
        }
    }
}

@MainActor
struct R12CurrentAccountTests {
    private let context = AuthContext.active(.init(sessionID: .init(rawValue: 12), generation: 1))

    @Test func oneLoadServesHomeAndPersonalAndRefreshFailureKeepsProfile() async throws {
        let repository = R12ControlledAccountRepository()
        let store = CurrentAccountStore(repository: repository)
        store.updateContext(context)
        let task = Task { await store.loadIfNeeded() }
        await repository.waitForRequest()
        await store.loadIfNeeded()
        await repository.complete(.success(try R12AccountFixture.profile()))
        await task.value
        #expect(store.profile?.displayName == "固定账户")
        #expect(store.profile?.postCount == nil)
        await store.loadIfNeeded()
        #expect(await repository.calls == 1)
        let refresh = Task { await store.refresh() }
        await repository.waitForRequest()
        #expect(store.profile != nil)
        await repository.complete(.failure(UserProfileRepositoryError.empty))
        await refresh.value
        #expect(store.failed)
        #expect(store.profile?.displayName == "固定账户")
    }

    @Test func logoutOrAccountSwitchRejectsLateProfileAndClearsOldAvatar() async throws {
        let repository = R12ControlledAccountRepository()
        let store = CurrentAccountStore(repository: repository)
        store.updateContext(context)
        let old = Task { await store.loadIfNeeded() }
        await repository.waitForRequest()
        store.updateContext(.anonymous)
        await repository.complete(.success(try R12AccountFixture.profile()))
        await old.value
        #expect(store.profile == nil)
        #expect(!store.isLoading && !store.failed)
        await store.loadIfNeeded()
        #expect(await repository.calls == 1)
        store.updateContext(.active(.init(sessionID: .init(rawValue: 13), generation: 2)))
        let next = Task { await store.loadIfNeeded() }
        await repository.waitForRequest()
        await repository.complete(.success(try R12AccountFixture.profile()))
        await next.value
        #expect(store.profile != nil)
        store.updateContext(context)
        #expect(store.profile == nil)
    }

    @Test func personalProfileSurvivesRootSwitchWithSameStoreAndStableID() async throws {
        let root = LaunchScenarioFactory.make(scenario: .sessionSignedInFixture).compositionRoot
        let account = root.currentAccountStore
        account.updateContext(root.authContextProvider.context())
        await account.loadIfNeeded()
        let profile = try #require(account.profile)
        let route = try #require(UserProfileRoute(userID: profile.userID.rawValue, fallbackDisplayName: profile.displayName))
        let stores = AppFeatureStoreRegistry(compositionRoot: root)
        let original = stores.userProfileStore(for: .settings, route: route)
        var navigation = AppNavigationState(selectedTab: .settings, settingsPath: [.accountProfile])
        stores.retainFeatureStores(in: navigation)
        #expect(stores.userProfileStore(for: .settings, route: route) === original)
        navigation.selectTab(.recommendations)
        stores.retainFeatureStores(in: navigation)
        #expect(stores.userProfileStore(for: .settings, route: route) === original)
    }

    @Test func revokedLeaseCannotPublishIdentityOrStartPublicProfileRequest() async throws {
        let client = HarnessMockHTTPClient()
        let provider = SessionAuthContextProvider()
        provider.install(try #require(SessionCredential(bduss: "fx-r12-b", stoken: "fx-r12-s")))
        let lease = provider.context()
        let repository = LiveCurrentAccountRepository(client: client, authContextProvider: provider)
        let task = Task { try await repository.loadProfile(context: lease) }
        try await client.waitForPendingCallCount(1)
        let call = try #require(await client.pendingCalls().first)
        #expect(call.request.url.absoluteString == "https://c.tieba.baidu.com/c/s/login")
        provider.revoke()
        let response = HTTPResponse(statusCode: 200, headers: ["Content-Type": "application/x-javascript"],
                                    body: Data(#"{"error_code":0,"user":{"id":"12001","name":"样本"}}"#.utf8))
        try await client.succeed(call.id, with: response)
        await #expect(throws: RequestAuthorizationError.self) { try await task.value }
        #expect(await client.pendingCalls().isEmpty)
    }
}

private enum R12AccountFixture {
    static func profile() throws -> UserProfile {
        UserProfile(userID: try #require(UserID(12_001)), displayName: "固定账户", portraitResourceID: nil,
                    introduction: nil, sex: nil, followingCount: 12, followerCount: 34, postCount: nil,
                    threadCount: nil, totalAgreeCount: nil, displayTiebaID: nil)
    }
}

private actor R12ControlledAccountRepository: CurrentAccountRepository {
    private(set) var calls = 0
    private var pending: CheckedContinuation<UserProfile, any Error>?
    private var observer: CheckedContinuation<Void, Never>?

    func loadProfile(context: AuthContext) async throws -> UserProfile {
        calls += 1
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            observer?.resume(); observer = nil
        }
    }

    func waitForRequest() async {
        if pending != nil { return }
        await withCheckedContinuation { observer = $0 }
    }

    func complete(_ result: Result<UserProfile, any Error>) {
        pending?.resume(with: result); pending = nil
    }
}
