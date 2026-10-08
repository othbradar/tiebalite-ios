import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U08NativeAccountPersistenceTests {
    @Test func replyResponseStateSurvivesRepositoryAndVaultRecreation() async throws {
        let keys = NativeAccountTestKeychain()
        let vault = NativeWriteAccountVault(dataStore: keys)
        try await vault.save(.init(userID: "42", tbs: "fixture-tbs"), namespace: "account-a")
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let fixture = try NativeClientFixture.load()
        let http = HarnessMockHTTPClient()
        for attempt in 0..<2 {
            let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: try #require(fixture.cases.first))
            let repository = NativeLiveTextWriteRepository(
                auth: auth, loader: NativeClientHarnessBridge(client: http), runtime: runtime,
                firstLogin: { false }, didPrepareAccount: {}, accountVault: NativeWriteAccountVault(dataStore: keys),
                accountNamespace: { "account-a" })
            let operation = Task { try await repository.send(request, context: auth.context()) }
            let call = try await next(http)
            #expect(call.request.url.path == "/c/c/post/add")
            let state = call.request.headers.first { $0.key.lowercased() == "svcp_stk" }?.value
            #expect(state == (attempt == 0 ? nil : "fixture-continuation"))
            try await http.succeed(call.id, with: .init(
                statusCode: 200, headers: ["Set-Cookie": "__ymg_scsc=fixture-continuation; Path=/"], body: NativeClientFixture.response()))
            #expect(try await operation.value.postID == 401)
        }
        #expect(await http.events().filter { if case .started = $0 { true } else { false } }.count == 2)
    }

    @Test func persistenceFailureDoesNotUndoSuccessfulReplyOrRepeatIt() async throws {
        let keys = NativeAccountTestKeychain()
        let vault = NativeWriteAccountVault(dataStore: keys)
        try await vault.save(.init(userID: "42", tbs: "fixture-tbs"), namespace: "account-a")
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let fixture = try NativeClientFixture.load()
        let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: try #require(fixture.cases.first))
        let http = HarnessMockHTTPClient()
        let repository = NativeLiveTextWriteRepository(
            auth: auth, loader: NativeClientHarnessBridge(client: http), runtime: runtime,
            firstLogin: { false }, didPrepareAccount: {}, accountVault: vault, accountNamespace: { "account-a" })
        let operation = Task { try await repository.send(request, context: auth.context()) }
        let call = try await next(http)
        await keys.setWriteFailure(true)
        try await http.succeed(call.id, with: .init(
            statusCode: 200, headers: ["Set-Cookie": "__ymg_scsc=fixture-memory; Path=/"], body: NativeClientFixture.response()))
        #expect(try await operation.value.postID == 401)
        #expect(repository.responseStatePersistenceFailed)
        #expect(try await vault.responseState(namespace: "account-a", userID: "42")?.requestHeaders
                == ["svcp_stk": "fixture-memory"])
        #expect(await http.pendingCalls().isEmpty)
        #expect(await http.events().filter { if case .started = $0 { true } else { false } }.count == 1)
        await keys.setWriteFailure(false)
        let nextOperation = Task { try await repository.send(request, context: auth.context()) }
        let nextCall = try await next(http)
        #expect(nextCall.request.headers.first { $0.key.lowercased() == "svcp_stk" }?.value == "fixture-memory")
        try await http.succeed(nextCall.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        #expect(try await nextOperation.value.postID == 401)
    }

    @Test(arguments: [true, false])
    func currentProfileUsesRawNameAndNeverTheUIFallback(hasRawName: Bool) async throws {
        let profile = UserProfile(userID: try #require(UserID(42)), displayName: "Updated fixture", portraitResourceID: nil,
                                  introduction: nil, sex: nil, followingCount: nil, followerCount: nil,
                                  postCount: nil, threadCount: nil, totalAgreeCount: nil, displayTiebaID: nil,
                                  accountDisplayName: hasRawName ? " Updated fixture " : nil)
        let setup = try await makeSetup(tbs: "fixture-tbs", profile: profile)
        let operation = Task { try await setup.repository.send(request, context: setup.auth.context()) }
        let write = try await next(setup.http)
        #expect(write.request.url.path == "/c/c/post/add")
        #expect(try await setup.vault.load(namespace: "account-a")?.nameShow == (hasRawName ? " Updated fixture " : "Fixture"))
        try await setup.http.succeed(write.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        #expect(try await operation.value.postID == 401)
        #expect(await setup.http.events().filter { if case .started = $0 { true } else { false } }.count == 1)
    }

    @Test func storedAccountOnlyFetchesMissingTBSAndPersistsItBeforeWriting() async throws {
        let setup = try await makeSetup(tbs: "")
        let operation = Task { try await setup.repository.send(request, context: setup.auth.context()) }
        let tbs = try await next(setup.http)
        #expect(tbs.request.url.path == "/c/s/tbs")
        try await setup.http.succeed(tbs.id, with: .init(statusCode: 200, body: Data(#"{"error_code":0,"tbs":"fixture-ready"}"#.utf8)))
        let write = try await next(setup.http)
        #expect(write.request.url.path == "/c/c/post/add")
        #expect(try await setup.vault.load(namespace: "account-a")?.tbs == "fixture-ready")
        try await setup.http.succeed(write.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        #expect(try await operation.value.postID == 401)
        #expect(await setup.http.events().filter { if case .started = $0 { true } else { false } }.count == 2)
    }

    @Test func accountReplacementRejectsLateTBSWithoutWritingOrOverwritingStoredAccount() async throws {
        let setup = try await makeSetup(tbs: "")
        let context = setup.auth.context()
        let operation = Task { try await setup.repository.send(request, context: context) }
        let tbs = try await next(setup.http)
        setup.auth.install(try #require(SessionCredential(bduss: "other", stoken: "other")))
        try await setup.vault.save(.init(userID: "43", tbs: "fixture-new"), namespace: "account-b")
        try await setup.http.succeed(tbs.id, with: .init(statusCode: 200, body: Data(#"{"error_code":0,"tbs":"fixture-late"}"#.utf8)))
        await #expect(throws: TextWriteFailure.authentication) { try await operation.value }
        #expect(try await setup.vault.load(namespace: "account-b")?.tbs == "fixture-new")
        #expect(await setup.http.pendingCalls().isEmpty)
    }

    @Test func restartedRepositoryUsesStoredAccountWithoutAnotherLogin() async throws {
        let keys = NativeAccountTestKeychain()
        let vault = NativeWriteAccountVault(dataStore: keys)
        try await vault.save(.init(userID: "42", tbs: "fixture-tbs", nameShow: "Fixture"), namespace: "account-a")
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let fixture = try NativeClientFixture.load()
        let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: try #require(fixture.cases.first))
        let http = HarnessMockHTTPClient()
        let repository = NativeLiveTextWriteRepository(
            auth: auth, loader: NativeClientHarnessBridge(client: http), runtime: runtime,
            firstLogin: { false }, didPrepareAccount: {}, accountVault: NativeWriteAccountVault(dataStore: keys),
            accountNamespace: { "account-a" })
        let operation = Task {
            try await repository.send(.init(target: R09WriteFixture.target(.threadReply),
                                            draft: .init(content: "Fixture")), context: auth.context())
        }
        try await http.waitForPendingCallCount(1)
        let call = try #require(await http.pendingCalls().first)
        #expect(call.request.url.path == "/c/c/post/add")
        try await http.succeed(call.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        #expect(try await operation.value.postID == 401)
        #expect(await http.events().filter { if case .started = $0 { true } else { false } }.count == 1)
    }

    @Test func storedMetadataIsIsolatedAndLogoutOnlyDeletesItsOwnKey() async throws {
        let keys = NativeAccountTestKeychain()
        let vault = NativeWriteAccountVault(dataStore: keys)
        let credentials = KeychainSessionCredentialStore(dataStore: keys)
        let credential = try #require(SessionCredential(bduss: "fx", stoken: "fy"))
        try await credentials.save(credential)
        try await vault.save(.init(userID: "42", tbs: "fixture-tbs"), namespace: "account-a")
        #expect(try await vault.load(namespace: "account-b") == nil)
        #expect(try await vault.load(namespace: "account-a")?.userID == "42")
        try await vault.delete(namespace: "account-b")
        #expect(try await vault.load(namespace: "account-a") != nil)
        let protected = NativeWriteCredentialStore(base: credentials, accounts: vault)
        try await protected.delete()
        #expect(try await credentials.load() == nil)
        #expect(try await vault.load(namespace: "account-a") == nil)
    }

    private var request: TextWriteRequest {
        .init(target: R09WriteFixture.target(.threadReply), draft: .init(content: "Fixture"))
    }

    private struct Setup {
        let auth: SessionAuthContextProvider
        let vault: NativeWriteAccountVault
        let http: HarnessMockHTTPClient
        let repository: NativeLiveTextWriteRepository
    }

    private func makeSetup(tbs: String, profile: UserProfile? = nil) async throws -> Setup {
        let vault = NativeWriteAccountVault(dataStore: NativeAccountTestKeychain())
        try await vault.save(.init(userID: "42", tbs: tbs, nameShow: "Fixture"), namespace: "account-a")
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let fixture = try NativeClientFixture.load()
        let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: try #require(fixture.cases.first))
        let http = HarnessMockHTTPClient()
        return Setup(auth: auth, vault: vault, http: http, repository: NativeLiveTextWriteRepository(
            auth: auth, loader: NativeClientHarnessBridge(client: http), runtime: runtime,
            firstLogin: { false }, didPrepareAccount: {}, accountVault: vault, accountNamespace: { "account-a" },
            currentProfile: { profile }))
    }

    private func next(_ http: HarnessMockHTTPClient) async throws -> HarnessPendingHTTPCall {
        try await http.waitForPendingCallCount(1)
        return try #require(await http.pendingCalls().first)
    }
}

actor NativeAccountTestKeychain: KeychainDataStoring {
    private var records: [KeychainItemKey: Data] = [:]
    private var failWrites = false
    func setWriteFailure(_ value: Bool) { failWrites = value }
    func read(_ key: KeychainItemKey) -> Data? { records[key] }
    func write(_ data: Data, key: KeychainItemKey) throws {
        guard !failWrites else { throw HTTPClientError.unavailable }
        records[key] = data
    }
    func delete(_ key: KeychainItemKey) { records[key] = nil }
}
