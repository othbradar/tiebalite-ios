import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

struct Stage12SessionCredentialTests {
    @Test
    func keychainEnvelopeSavesLoadsAndDeletesOnlyTheSessionCredential() async throws {
        let dataStore = HarnessMemoryKeychainDataStore()
        let store = KeychainSessionCredentialStore(
            dataStore: dataStore,
            service: "fixture.session",
            account: "primary"
        )
        let credential = try #require(
            SessionCredential(
                bduss: "fx-bduss",
                stoken: "fx-stoken"
            )
        )

        #expect(try await store.load() == nil)
        try await store.save(credential)
        #expect(try await store.load() == credential)
        #expect(await dataStore.itemCount() == 1)

        try await store.delete()
        #expect(try await store.load() == nil)
        #expect(await dataStore.itemCount() == 0)
    }

    @Test
    func credentialAndAuthorizationDescriptionsNeverRevealCookieValues() throws {
        let bduss = ["fixture", "bd", "canary"].joined(separator: "-")
        let stoken = ["fixture", "st", "canary"].joined(separator: "-")
        let credential = try #require(
            SessionCredential(bduss: bduss, stoken: stoken)
        )
        let authorization = SessionAuthorization(credential: credential)

        for description in [
            String(describing: credential),
            String(reflecting: credential),
            String(describing: authorization),
            String(reflecting: authorization)
        ] {
            #expect(!description.contains(bduss))
            #expect(!description.contains(stoken))
        }
    }

}

@MainActor
struct Stage12SessionStoreTests {
    @Test
    func incompleteCookiesDoNotPersistOrEnterSignedIn() async throws {
        let dependencies = makeDependencies()
        dependencies.store.beginSignIn()

        await dependencies.store.completeLogin(
            LoginCookieValues(
                bduss: "fx-bduss",
                stoken: nil
            )
        )

        #expect(dependencies.store.state == .failed(.loginIncomplete))
        #expect(try await dependencies.credentials.load() == nil)
        #expect(await dependencies.auth.snapshot().status == .signedOut)
    }

    @Test
    func cancellingVisibleLoginReturnsToSignedOutWithoutAnError() async {
        let dependencies = makeDependencies()

        dependencies.store.beginSignIn()
        #expect(dependencies.store.state == .signingIn)
        await dependencies.store.cancelSignIn()

        #expect(dependencies.store.state == .signedOut)
    }

    @Test
    func matchingSessionExpiryRevokesAuthorizationAndEntersExpired() async throws {
        let dependencies = makeDependencies()
        try await signIn(dependencies.store)
        let context = dependencies.auth.context()

        await dependencies.store.markExpired(context: context)

        #expect(dependencies.store.state == .expired)
        #expect(await dependencies.auth.snapshot().status == .expired)
        #expect(try await dependencies.credentials.load() == nil)
        #expect(throws: RequestAuthorizationError.credentialUnavailable) {
            _ = try dependencies.auth.authorization(for: context)
        }
    }

    @Test
    func logoutRevokesMemoryThenClearsCredentialAndWebData() async throws {
        let dependencies = makeDependencies()
        try await signIn(dependencies.store)
        let signedInContext = dependencies.auth.context()

        await dependencies.store.logout()

        #expect(dependencies.store.state == .signedOut)
        #expect(try await dependencies.credentials.load() == nil)
        #expect(dependencies.websiteData.clearCount == 1)
        #expect(await dependencies.auth.snapshot().status == .signedOut)
        #expect(throws: RequestAuthorizationError.credentialUnavailable) {
            _ = try dependencies.auth.authorization(
                for: signedInContext
            )
        }
    }

    @Test
    func rebuildingSessionStoreRestoresTheFakeCredentialWithoutSystemKeychain() async throws {
        let credential = try #require(
            SessionCredential(
                bduss: "fx-restored-b",
                stoken: "fx-restored-s"
            )
        )
        let fakeCredentials = FakeSessionCredentialStore(
            initialCredential: credential
        )
        let first = SessionStore(
            credentialStore: fakeCredentials,
            authContextProvider: SessionAuthContextProvider(),
            websiteDataCleaner: HarnessSessionWebsiteDataCleaner()
        )
        await first.restore()
        #expect(first.state == .signedIn)

        let rebuiltAuth = SessionAuthContextProvider()
        let rebuilt = SessionStore(
            credentialStore: fakeCredentials,
            authContextProvider: rebuiltAuth,
            websiteDataCleaner: HarnessSessionWebsiteDataCleaner()
        )
        await rebuilt.restore()

        #expect(rebuilt.state == .signedIn)
        #expect(await rebuiltAuth.snapshot().status == .signedIn)
        #expect(await fakeCredentials.loadCount() == 2)
    }

    @Test
    func lateCancelledRestoreCannotOverwriteAReplacementLogin() async throws {
        let oldCredential = try #require(
            SessionCredential(
                bduss: "fx-old-b",
                stoken: "fx-old-s"
            )
        )
        let delayedCredentials = HarnessDelayedSessionCredentialStore(
            delayedCredential: oldCredential
        )
        let auth = SessionAuthContextProvider()
        let store = SessionStore(
            credentialStore: delayedCredentials,
            authContextProvider: auth,
            websiteDataCleaner: HarnessSessionWebsiteDataCleaner()
        )

        let restore = Task { @MainActor in
            await store.restore()
        }
        try await delayedCredentials.loadStarted.wait()
        store.beginSignIn()
        await store.completeLogin(
            LoginCookieValues(
                bduss: "fx-new-b",
                stoken: "fx-new-s"
            )
        )
        #expect(delayedCredentials.loadResult.succeed(oldCredential))
        await restore.value

        #expect(store.state == .signedIn)
        let context = auth.context()
        let authorization = try auth.authorization(for: context)
        #expect(authorization == SessionAuthorization(
            bduss: "fx-new-b",
            stoken: "fx-new-s"
        ))
    }

    @Test
    func loginStartedBeforeLaunchRestoreCannotBeOverwrittenByStoredState() async throws {
        let oldCredential = try #require(
            SessionCredential(
                bduss: "fx-old-b",
                stoken: "fx-old-s"
            )
        )
        let credentials = FakeSessionCredentialStore(
            initialCredential: oldCredential
        )
        let auth = SessionAuthContextProvider()
        let store = SessionStore(
            credentialStore: credentials,
            authContextProvider: auth,
            websiteDataCleaner: HarnessSessionWebsiteDataCleaner()
        )

        store.beginSignIn()
        await store.restoreIfNeeded()

        #expect(store.state == .signingIn)
        #expect(await credentials.loadCount() == 0)
        await store.completeLogin(
            LoginCookieValues(
                bduss: "fx-new-b",
                stoken: "fx-new-s"
            )
        )
        #expect(store.state == .signedIn)
        let authorization = try auth.authorization(for: auth.context())
        #expect(authorization == SessionAuthorization(
            bduss: "fx-new-b",
            stoken: "fx-new-s"
        ))
    }

    @Test
    func oldLeaseNeverAuthorizesAfterLogoutOrAReplacementLogin() async throws {
        let dependencies = makeDependencies()
        try await signIn(dependencies.store)
        let oldContext = dependencies.auth.context()

        await dependencies.store.logout()
        #expect(throws: RequestAuthorizationError.credentialUnavailable) {
            _ = try dependencies.auth.authorization(for: oldContext)
        }

        try await signIn(
            dependencies.store,
            bduss: "fx-replace-b",
            stoken: "fx-replace-s"
        )
        #expect(throws: RequestAuthorizationError.contextMismatch) {
            _ = try dependencies.auth.authorization(for: oldContext)
        }
        let newContext = dependencies.auth.context()
        _ = try dependencies.auth.authorization(for: newContext)
    }

    @Test
    func uiLaunchSessionFixtureUsesFakeSessionStorage() async {
        let descriptor = LaunchScenarioFactory.make(
            scenario: .sessionSignedInFixture
        )

        await descriptor.compositionRoot.sessionStore.restoreIfNeeded()

        #expect(descriptor.compositionRoot.sessionStore.state == .signedIn)
        #expect(
            await descriptor.compositionRoot.environment.session
                .snapshot().status == .signedIn
        )
        #expect(descriptor.compositionRoot.loginWebSession.loginURL == nil)

        await descriptor.compositionRoot.sessionStore.logout()
        #expect(
            await descriptor.compositionRoot.environment.session
                .snapshot().status == .signedOut
        )
    }

    @Test
    func expiredUILaunchFixtureUsesTheSameFakeSessionProviderEverywhere() async {
        let descriptor = LaunchScenarioFactory.make(
            scenario: .sessionExpired
        )

        await descriptor.compositionRoot.sessionStore.restoreIfNeeded()

        #expect(descriptor.compositionRoot.sessionStore.state == .expired)
        #expect(
            await descriptor.compositionRoot.environment.session
                .snapshot().status == .expired
        )
        #expect(descriptor.compositionRoot.loginWebSession.loginURL == nil)
    }

    private func makeDependencies() -> HarnessSessionDependencies {
        let credentials = FakeSessionCredentialStore()
        let auth = SessionAuthContextProvider()
        let websiteData = HarnessSessionWebsiteDataCleaner()
        return HarnessSessionDependencies(
            store: SessionStore(
                credentialStore: credentials,
                authContextProvider: auth,
                websiteDataCleaner: websiteData
            ),
            credentials: credentials,
            auth: auth,
            websiteData: websiteData
        )
    }

    private func signIn(
        _ store: SessionStore,
        bduss: String = "fx-bduss",
        stoken: String = "fx-stoken"
    ) async throws {
        store.beginSignIn()
        await store.completeLogin(
            LoginCookieValues(bduss: bduss, stoken: stoken)
        )
        #expect(store.state == .signedIn)
    }
}

@MainActor
private struct HarnessSessionDependencies {
    let store: SessionStore
    let credentials: FakeSessionCredentialStore
    let auth: SessionAuthContextProvider
    let websiteData: HarnessSessionWebsiteDataCleaner
}

struct Stage12LoginNavigationTests {
    @Test
    func loginNavigationAllowsOnlyVisibleHTTPSBaiduPagesAndExactCompletion() throws {
        let configuredLogin = try #require(
            LoginWebNavigationPolicy.loginURL
        )
        let login = try #require(
            URL(string: "https://wappass.baidu.com/passport?login")
        )
        let completion = try #require(
            URL(string: "https://tieba.baidu.com/index/tbwise/mine")
        )
        let alternateCompletion = try #require(
            URL(string: "https://tiebac.baidu.com/index/tbwise/home")
        )
        let wrongPath = try #require(
            URL(string: "https://tieba.baidu.com/f/index/forumpark")
        )
        let wrongHost = try #require(
            URL(string: "https://tieba.baidu.com.evil.invalid/index/tbwise/mine")
        )
        let insecure = try #require(
            URL(string: "http://tieba.baidu.com/index/tbwise/mine")
        )
        let explicitDefaultPort = try #require(
            URL(string: "https://tieba.baidu.com:443/index/tbwise/mine")
        )
        let alternatePort = try #require(
            URL(string: "https://tieba.baidu.com:444/index/tbwise/mine")
        )

        #expect(configuredLogin.scheme == "https")
        #expect(configuredLogin.host == "wappass.baidu.com")
        let loginComponents = try #require(
            URLComponents(url: configuredLogin, resolvingAgainstBaseURL: false)
        )
        let loginQuery = loginComponents.queryItems ?? []
        #expect(loginQuery.map(\.name) == ["login", "u"])
        #expect(
            loginQuery.last?.value ==
                "https://tieba.baidu.com/index/tbwise/mine"
        )
        #expect(
            loginComponents.percentEncodedQuery ==
                "login&u=https%3A%2F%2Ftieba.baidu.com%2Findex%2Ftbwise%2Fmine"
        )
        #expect(LoginWebNavigationPolicy.allows(login))
        #expect(LoginWebNavigationPolicy.allows(completion))
        #expect(LoginWebNavigationPolicy.isCompletion(completion))
        #expect(LoginWebNavigationPolicy.isCompletion(alternateCompletion))
        #expect(!LoginWebNavigationPolicy.isCompletion(wrongPath))
        #expect(!LoginWebNavigationPolicy.allows(wrongHost))
        #expect(!LoginWebNavigationPolicy.allows(insecure))
        #expect(!LoginWebNavigationPolicy.allows(explicitDefaultPort))
        #expect(!LoginWebNavigationPolicy.allows(alternatePort))
    }

    @Test
    func cookieSelectionUsesCompletionDomainPathAndCaseInsensitiveNames() throws {
        let completion = try #require(
            URL(string: "https://tieba.baidu.com/index/tbwise/mine")
        )
        let values = LoginCookieValues.select(
            from: [
                LoginCookieRecord(
                    name: "BDUSS",
                    value: "wrong-host",
                    domain: "wappass.baidu.com",
                    path: "/",
                    isSecure: true
                ),
                LoginCookieRecord(
                    name: "bduss",
                    value: "b-road",
                    domain: ".baidu.com",
                    path: "/",
                    isSecure: true
                ),
                LoginCookieRecord(
                    name: "BdUsS",
                    value: "b-specific",
                    domain: ".baidu.com",
                    path: "/index/tbwise",
                    isSecure: true
                ),
                LoginCookieRecord(
                    name: "stoken",
                    value: "s-correct",
                    domain: ".baidu.com",
                    path: "/",
                    isSecure: true
                ),
                LoginCookieRecord(
                    name: "STOKEN",
                    value: "wrong-path",
                    domain: ".baidu.com",
                    path: "/passport",
                    isSecure: true
                )
            ],
            completionURL: completion
        )

        #expect(values.bduss == "b-specific")
        #expect(values.stoken == "s-correct")
        #expect(values.credential != nil)
    }

    @Test
    func ambiguousSameScopeCookiesFailClosed() throws {
        let completion = try #require(
            URL(string: "https://tieba.baidu.com/index/tbwise/mine")
        )
        let records = ["one", "two"].map { value in
            LoginCookieRecord(
                name: "BDUSS",
                value: value,
                domain: ".baidu.com",
                path: "/",
                isSecure: true
            )
        } + [
            LoginCookieRecord(
                name: "STOKEN",
                value: "s-value",
                domain: ".baidu.com",
                path: "/",
                isSecure: true
            )
        ]

        let values = LoginCookieValues.select(
            from: records,
            completionURL: completion
        )

        #expect(values.bduss == nil)
        #expect(values.credential == nil)
    }
}

struct Stage12AuthenticatedProbeContractTests {
    @Test
    func authenticatedPersonalizedBodyUsesTheActiveLeaseFieldsWithoutChangingAnonymousGolden() throws {
        let input = try PersonalizedRequestInput(loadKind: .refresh, page: 1)
        let anonymous = try PersonalizedProtocol.encodeRequest(input)
        let authorization = SessionAuthorization(
            bduss: "fx-auth-b",
            stoken: "fx-auth-s"
        )
        let body = try PersonalizedProtocol.makeAuthenticatedRequestBody(
            input,
            authorization: authorization
        )

        guard case let .multipartBinary(_, fields, part) = body else {
            Issue.record("Authenticated probe changed multipart body family")
            return
        }
        let request = try Tieba_PersonalizedRequest(
            serializedBytes: part.data
        )
        #expect(request.data.common.bduss == "fx-auth-b")
        #expect(request.data.common.stoken == "fx-auth-s")
        #expect(fields == [
            EndpointField(name: "stoken", value: "fx-auth-s")
        ])
        #expect(try PersonalizedProtocol.encodeRequest(input) == anonymous)
        #expect(
            try PersonalizedProtocol.makeActiveDescriptor(
                host: "fixture.invalid"
            ).authentication == .active
        )
    }

#if DEBUG
    @Test
    func decodedServerFailureIsReportedAsTypedServerOutcome() throws {
        var error = Tieba_Error()
        error.errorCode = 17
        var response = Tieba_PersonalizedResponse()
        response.error = error
        let endpoint = try PersonalizedProtocol.makeActiveDescriptor(
            host: "fixture.invalid"
        )

        let result = DebugAuthenticatedSessionProbe.map(
            response: HTTPResponse(
                statusCode: 200,
                headers: [
                    "content-type": PersonalizedProtocol.liveResponseMIMEType
                ],
                body: try response.serializedData()
            ),
            endpoint: endpoint
        )

        #expect(result.decoded)
        #expect(result.itemCount == nil)
        #expect(result.outcome == .server)
    }
#endif
}

private actor HarnessMemoryKeychainDataStore: KeychainDataStoring {
    private var items: [KeychainItemKey: Data] = [:]

    func read(_ key: KeychainItemKey) throws -> Data? {
        items[key]
    }

    func write(_ data: Data, key: KeychainItemKey) throws {
        items[key] = data
    }

    func delete(_ key: KeychainItemKey) throws {
        items[key] = nil
    }

    func itemCount() -> Int {
        items.count
    }
}

@MainActor
private final class HarnessSessionWebsiteDataCleaner: SessionWebsiteDataCleaning {
    private(set) var clearCount = 0

    func clearSessionWebsiteData() async {
        clearCount += 1
    }
}

private final class HarnessDelayedSessionCredentialStore:
    SessionCredentialStore,
    Sendable {
    let loadStarted = HarnessContinuationGate<Void>()
    let loadResult = HarnessContinuationGate<SessionCredential?>()

    private let storage: HarnessMutableSessionCredentialStorage

    init(delayedCredential: SessionCredential) {
        storage = HarnessMutableSessionCredentialStorage(
            credential: delayedCredential
        )
    }

    func load() async throws -> SessionCredential? {
        loadStarted.succeed(())
        return try await loadResult.wait()
    }

    func save(_ credential: SessionCredential) async throws {
        await storage.set(credential)
    }

    func delete() async throws {
        await storage.set(nil)
    }
}

private actor HarnessMutableSessionCredentialStorage {
    private var credential: SessionCredential?

    init(credential: SessionCredential?) {
        self.credential = credential
    }

    func set(_ credential: SessionCredential?) {
        self.credential = credential
    }
}
