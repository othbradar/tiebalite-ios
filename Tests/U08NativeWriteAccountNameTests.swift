import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U08NativeWriteAccountNameTests {
    @Test
    func profileNameSelectionMatchesNativeUIDGuardAndFallback() throws {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let bytes = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-account-name.json"))
        for sample in try JSONDecoder().decode(Fixtures.self, from: bytes).cases {
            let input = sample.input
            let result = NativeWriteAccountName.updatedName(
                accountID: input.accountID, currentName: input.cachedName, profileID: input.profileID,
                displayName: input.displayName, loginName: input.loginName
            )
            #expect(result.map { Array($0.utf16) } == sample.expected.updated.first.map { Array($0.utf16) }, "\(sample.name)")
            #expect(sample.expected.updated.count <= 1)
            #expect(sample.expected.saved.count == sample.expected.updated.count)
            #expect(sample.expected.notifications == sample.expected.updated.count)
        }
    }

    @Test
    func profileUpdatePreservesTBSAndOnlyChangesItsOwnAccount() throws {
        let auth = try provider()
        let session = try makeSession(auth, tbs: "fx")
        #expect(try !session.acceptProfileName(profileUserID: "43", displayName: "Other", loginName: nil,
                                               for: auth.context()))
        #expect(try session.cachedAccount()?.nameShow == "Old")
        #expect(try session.acceptProfileName(profileUserID: "42", displayName: "", loginName: "Native fallback",
                                              for: auth.context()))
        #expect(try session.cachedAccount()?.nameShow == "Native fallback")
        #expect(try session.cachedAccount()?.tbs == "fx")
        #expect(try !session.acceptProfileName(profileUserID: "42", displayName: nil, loginName: nil,
                                               for: auth.context()))
        #expect(try session.cachedAccount()?.nameShow == "Native fallback")
        #expect(try session.beginTBSRequest() == nil)
    }

    @Test
    func pendingTBSCompletionDoesNotOverwriteNewerProfileName() throws {
        let auth = try provider()
        let session = try makeSession(auth, tbs: "")
        let pending = try #require(try session.beginTBSRequest())
        #expect(try session.acceptProfileName(profileUserID: "42", displayName: "Updated", loginName: "Login",
                                              for: auth.context()))
        #expect(try session.beginTBSRequest() == nil)
        #expect(try session.finishTBSRequest(pending, value: "fx"))
        #expect(try session.cachedAccount()?.nameShow == "Updated")
    }

    @Test
    func replacedLeaseRejectsOldProfileEvenForSameUserID() throws {
        let auth = try provider()
        let oldContext = auth.context()
        let old = try makeSession(auth, tbs: "fx")
        auth.install(try #require(SessionCredential(bduss: "fixture-other", stoken: "fixture-other-token")))
        let replacement = try makeSession(auth, tbs: "fx")
        #expect(throws: RequestAuthorizationError.contextMismatch) {
            try old.acceptProfileName(profileUserID: "42", displayName: "Stale", loginName: nil, for: oldContext)
        }
        #expect(throws: RequestAuthorizationError.contextMismatch) {
            try replacement.acceptProfileName(profileUserID: "42", displayName: "Stale", loginName: nil, for: oldContext)
        }
        #expect(try replacement.cachedAccount()?.nameShow == "Old")
    }

    private func provider() throws -> SessionAuthContextProvider {
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fixture-session", stoken: "fixture-token")))
        return auth
    }

    private func makeSession(_ auth: SessionAuthContextProvider, tbs: String) throws -> NativeWriteSession {
        try NativeWriteSession(auth: auth, context: auth.context(), account: .init(userID: "42", tbs: tbs, nameShow: "Old"))
    }

    private struct Fixtures: Decodable { let cases: [Sample] }
    private struct Sample: Decodable { let name: String; let input: Input; let expected: Expected }
    private struct Input: Decodable {
        let accountID: String?
        let profileID: String?
        let cachedName: String?
        let displayName: String?
        let loginName: String?
    }
    private struct Expected: Decodable {
        let updated: [String]
        let saved: [[String: String]]
        let notifications: Int
    }
}
