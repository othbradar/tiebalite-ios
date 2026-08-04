import Testing
@testable import TiebaLite

@MainActor
struct Stage12SessionCleanupTests {
    @Test
    func logoutStaysBusyUntilCredentialAndWebCleanupFinish() async throws {
        let credentials = DelayedDeleteCredentialStore()
        let auth = SessionAuthContextProvider()
        let websiteData = CleanupWebsiteDataCleaner()
        let store = SessionStore(
            credentialStore: credentials,
            authContextProvider: auth,
            websiteDataCleaner: websiteData
        )
        await signIn(store)

        let logout = Task { @MainActor in
            await store.logout()
        }
        try await credentials.deleteStarted.wait()

        #expect(store.state == .signingOut)
        #expect(store.isBusy)
        #expect(await auth.snapshot().status == .signedOut)
        #expect(credentials.deleteResult.succeed(()))
        await logout.value

        #expect(store.state == .signedOut)
        #expect(!store.isBusy)
        #expect(websiteData.clearCount == 1)
    }

    @Test
    func failedCredentialDeletionStillClearsWebDataAndOffersLogoutRetry() async {
        let credentials = FailingDeleteCredentialStore()
        let auth = SessionAuthContextProvider()
        let websiteData = CleanupWebsiteDataCleaner()
        let store = SessionStore(
            credentialStore: credentials,
            authContextProvider: auth,
            websiteDataCleaner: websiteData
        )
        await signIn(store)

        await store.logout()

        #expect(store.state == .failed(.logout))
        #expect(websiteData.clearCount == 1)
        #expect(await auth.snapshot().status == .signedOut)
    }

    private func signIn(_ store: SessionStore) async {
        store.beginSignIn()
        await store.completeLogin(
            LoginCookieValues(
                bduss: "fx-bduss",
                stoken: "fx-stoken"
            )
        )
        #expect(store.state == .signedIn)
    }
}

@MainActor
private final class CleanupWebsiteDataCleaner: SessionWebsiteDataCleaning {
    private(set) var clearCount = 0

    func clearSessionWebsiteData() async {
        clearCount += 1
    }
}

private actor DelayedDeleteCredentialStore: SessionCredentialStore {
    nonisolated let deleteStarted = HarnessContinuationGate<Void>()
    nonisolated let deleteResult = HarnessContinuationGate<Void>()

    private var credential: SessionCredential?

    func load() throws -> SessionCredential? {
        credential
    }

    func save(_ credential: SessionCredential) throws {
        self.credential = credential
    }

    func delete() async throws {
        deleteStarted.succeed(())
        try await deleteResult.wait()
        credential = nil
    }
}

private actor FailingDeleteCredentialStore: SessionCredentialStore {
    private var credential: SessionCredential?

    func load() throws -> SessionCredential? {
        credential
    }

    func save(_ credential: SessionCredential) throws {
        self.credential = credential
    }

    func delete() throws {
        throw SessionCredentialStoreError.unavailable
    }
}
