import Foundation
import Testing
@testable import TiebaLite

struct U08NativeWriteResponseRulesTests {
    @Test
    func errorCategoriesMatchNativePredicatesAndBoundaryCases() throws {
        for sample in try samples().predicateCases {
            let actual = NativeWriteResponseRules.category(errorCode: sample.code)
            #expect((actual.map { [$0.rawValue] } ?? []) == sample.matches, "code \(sample.code)")
        }
    }

    @Test
    func accountActionMatchesNativeBranchIncludingMissingVerificationMaterial() throws {
        let passwordActionSelector = "modifyPWD"
        let selectors: [NativeWriteResponseRules.AccountAction: String] = [
            .reauthenticate: "deleteAccountAndGotoLogin", .bindMobile: "bindMobile:",
            .verifyIdentity: "verifyID:", .changePassword: passwordActionSelector, .verifyFace: "verifyFace"
        ]
        for sample in try samples().accountActionCases {
            let action = NativeWriteResponseRules.accountAction(errorCode: sample.code, passToken: sample.passValue)
            #expect((action != nil) == sample.handled, "code \(sample.code)")
            #expect((action.flatMap { selectors[$0] }.map { [$0] } ?? []) == sample.actions, "code \(sample.code)")
        }
    }

    @Test
    func unknownAndSuccessCodesDoNotCreateVerificationActions() {
        for code in [Int64(0), -1, 999_999] {
            #expect(NativeWriteResponseRules.category(errorCode: code) == nil)
            #expect(NativeWriteResponseRules.accountAction(errorCode: code, passToken: "fixture-pass") == nil)
        }
    }

    private func samples() throws -> Fixtures {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let bytes = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-response-rules.json"))
        return try JSONDecoder().decode(Fixtures.self, from: bytes)
    }

    private struct Fixtures: Decodable {
        let predicateCases: [PredicateCase]
        let accountActionCases: [ActionCase]
    }
    private struct PredicateCase: Decodable { let code: Int64; let matches: [String] }
    private struct ActionCase: Decodable {
        let code: Int64
        let passValue: String?
        let handled: Bool
        let actions: [String]
    }
}
