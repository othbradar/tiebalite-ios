import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct U08NativeResponsePersistenceTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let account = TextWriteAccount(userID: "42", tbs: "fixture-tbs", nameShow: "Fixture")

    @Test func nativeDefaultCacheReadsDiskAfterMemoryIsGone() throws {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let samples = try JSONDecoder().decode(Samples.self, from: Data(contentsOf:
            root.appendingPathComponent("API/Write/native-ios-state-cache.json")))
        let sample = try #require(samples.cases.first { $0.storagePolicy == samples.sharedCachePolicy })
        #expect(samples.sharedCachePolicy == 2)
        #expect(sample.beforeRestart == sample.afterRestart && sample.afterRestart != nil)
        #expect(sample.events == ["write-memory", "write-disk", "read-memory", "read-memory", "read-disk", "write-memory"])
    }

    @Test func expiryMatchesNativeModificationDateBoundary() async throws {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let samples = try JSONDecoder().decode(Samples.self, from: Data(contentsOf:
            root.appendingPathComponent("API/Write/native-ios-state-cache.json")))
        let state = try #require(NativeWriteResponseState(headerValue: "__ymg_scsc=fixture-state"))
        for sample in samples.expiry {
            let vault = NativeWriteAccountVault(dataStore: NativeAccountTestKeychain())
            try await vault.save(account, namespace: "owner")
            try await vault.saveResponseState(state, namespace: "owner", userID: "42", at: start)
            try await vault.enteredBackground(at: start.addingTimeInterval(sample.ageSeconds))
            let value = try await vault.responseState(namespace: "owner", userID: "42")
            #expect((value == nil) == sample.removed)
        }
    }

    @Test func legacyRecordRemainsReadableAndMetadataSavesRetainOnlyTheSingleResponseValue() async throws {
        let keys = NativeAccountTestKeychain()
        let key = KeychainItemKey(service: "dev.local.tiebaliteios.native-write", account: "prepared-account-v1")
        try await keys.write(Data(#"{"version":1,"namespace":"owner","userID":"42","tbs":"fixture-tbs","name":"Fixture"}"#.utf8),
                             key: key)
        let vault = NativeWriteAccountVault(dataStore: keys)
        let loaded = try #require(await vault.load(namespace: "owner"))
        #expect(loaded.userID == account.userID && loaded.tbs == account.tbs && loaded.nameShow == account.nameShow)
        #expect(try await vault.responseState(namespace: "owner", userID: "42") == nil)
        let state = try #require(NativeWriteResponseState(headerValue: "other=fixture; __ymg_scsc=fixture-state; Path=/"))
        try await vault.saveResponseState(state, namespace: "owner", userID: "42", at: start)
        try await vault.save(.init(userID: "42", tbs: "fixture-new-tbs", nameShow: "Updated"), namespace: "owner")
        let restarted = NativeWriteAccountVault(dataStore: keys)
        #expect(try await restarted.responseState(namespace: "owner", userID: "42") == state)
        #expect(try await restarted.load(namespace: "owner")?.tbs == "fixture-new-tbs")
        let stored = try #require(await keys.read(key))
        let encoded = try #require(String(data: stored, encoding: .utf8))
        #expect(!encoded.contains("other=") && !encoded.contains("Path=/"))
    }

    @Test func otherAccountsAndLateResultsCannotRecoverOrOverwriteStoredState() async throws {
        let vault = NativeWriteAccountVault(dataStore: NativeAccountTestKeychain())
        try await vault.save(account, namespace: "owner")
        let state = try #require(NativeWriteResponseState(headerValue: "__ymg_scsc=fixture-state"))
        try await vault.saveResponseState(state, namespace: "owner", userID: "42", at: start)
        #expect(try await vault.responseState(namespace: "other", userID: "42") == nil)
        #expect(try await vault.responseState(namespace: "owner", userID: "43") == nil)
        try await vault.save(.init(userID: "43", tbs: "fixture-other"), namespace: "other")
        await #expect(throws: RequestAuthorizationError.contextMismatch) {
            try await vault.saveResponseState(state, namespace: "owner", userID: "42", at: start)
        }
        #expect(try await vault.responseState(namespace: "other", userID: "43") == nil)
        try await vault.delete(namespace: "owner")
        #expect(try await vault.load(namespace: "other")?.userID == "43")
    }

    @Test func backgroundExpiryDoesNotExpireAtLookupOrEraseAccountMetadata() async throws {
        let vault = NativeWriteAccountVault(dataStore: NativeAccountTestKeychain())
        try await vault.save(account, namespace: "owner")
        let state = try #require(NativeWriteResponseState(headerValue: "__ymg_scsc=fixture-state"))
        try await vault.saveResponseState(state, namespace: "owner", userID: "42", at: start)
        try await vault.enteredBackground(at: start.addingTimeInterval(3_600))
        #expect(try await vault.responseState(namespace: "owner", userID: "42") == state)
        try await vault.enteredBackground(at: start.addingTimeInterval(3_601)) // Within native cleanup throttle.
        #expect(try await vault.responseState(namespace: "owner", userID: "42") == state)
        try await vault.enteredBackground(at: start.addingTimeInterval(4_201))
        #expect(try await vault.responseState(namespace: "owner", userID: "42") == nil)
        let loaded = try #require(await vault.load(namespace: "owner"))
        #expect(loaded.userID == account.userID && loaded.tbs == account.tbs && loaded.nameShow == account.nameShow)
    }

    @Test func failedDiskSaveKeepsMemoryAndBackgroundCleanupDoesNotReviveOldDiskState() async throws {
        let keys = NativeAccountTestKeychain()
        let vault = NativeWriteAccountVault(dataStore: keys)
        try await vault.save(account, namespace: "owner")
        let old = try #require(NativeWriteResponseState(headerValue: "__ymg_scsc=fixture-old"))
        let new = try #require(NativeWriteResponseState(headerValue: "__ymg_scsc=fixture-new"))
        try await vault.saveResponseState(old, namespace: "owner", userID: "42", at: start)
        await keys.setWriteFailure(true)
        await #expect(throws: HTTPClientError.unavailable) {
            try await vault.saveResponseState(new, namespace: "owner", userID: "42", at: start.addingTimeInterval(10))
        }
        #expect(try await vault.responseState(namespace: "owner", userID: "42") == new)
        await #expect(throws: HTTPClientError.unavailable) { try await vault.enteredBackground(at: start.addingTimeInterval(4_000)) }
        #expect(try await vault.responseState(namespace: "owner", userID: "42") == nil)
        await keys.setWriteFailure(false)
        try await vault.save(account, namespace: "owner")
        #expect(try await NativeWriteAccountVault(dataStore: keys).responseState(namespace: "owner", userID: "42") == nil)
    }

    @Test func logoutRemovesResponseStateTogetherWithOnlyTheCompanionAccountRecord() async throws {
        let keys = NativeAccountTestKeychain()
        let vault = NativeWriteAccountVault(dataStore: keys)
        let credentials = KeychainSessionCredentialStore(dataStore: keys)
        let protected = NativeWriteCredentialStore(base: credentials, accounts: vault)
        let credential = try #require(SessionCredential(bduss: "fx", stoken: "fy"))
        try await protected.save(credential)
        try await vault.save(account, namespace: "owner")
        let state = try #require(NativeWriteResponseState(headerValue: "__ymg_scsc=fixture-state"))
        try await vault.saveResponseState(state, namespace: "owner", userID: "42", at: start)
        try await protected.delete()
        #expect(try await vault.responseState(namespace: "owner", userID: "42") == nil)
        #expect(try await credentials.load() == nil)
    }

    private struct Samples: Decodable {
        let sharedCachePolicy: Int
        let cases: [Sample]
        let expiry: [Expiry]
    }
    private struct Expiry: Decodable { let ageSeconds: Double; let removed: Bool }
    private struct Sample: Decodable {
        let storagePolicy: Int
        let beforeRestart: String?
        let afterRestart: String?
        let events: [String]
    }
}
