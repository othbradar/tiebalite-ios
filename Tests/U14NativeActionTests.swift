import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

struct U14NativeActionTests {
    @Test func likeFormsMatchReplayedIOSCommonAndSignature() throws {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let fixture = try JSONDecoder().decode(Forms.self, from: Data(contentsOf:
            root.appendingPathComponent("API/ContentActions/native-ios-like-common.json")))
        for sample in fixture.cases {
            let kind: ContentActionTarget.Kind = sample.kind == "thread" ? .thread : .post
            let info = ContentActionInspection(target: .init(kind: kind, threadID: 10, postID: kind == .thread ? 0 : 11),
                                               accountID: 42, authorID: 41, forumID: 9, forumName: "Fixture", firstPostID: 1,
                                               likeCount: 2, liked: false, permitsOwnDeletion: false)
            let runtime = NativeWriteRuntimeContext(common: .init(
                staticValues: sample.staticContext, staticMode: sample.staticMode, dynamicValues: sample.input,
                metadata: .init(packageVersion: nil, experimentHits: nil, experimentMisses: nil)),
                http: .init(userAgent: "FixtureIOSAgent", acceptLanguage: "zh-Hans", clientLogID: 42, timeout: 10,
                            responseState: nil, cookies: .init(networkStatus: 1, wifiKeepAlive: false, cellularKeepAlive: false,
                                                               smallFlow: false, smallFlowValue: nil)), multipartBoundary: "unused")
            let request = try NativeContentActionProtocol.request(
                .like(info, sample.business["op_type"] == "0"), runtime: runtime, tbs: "fx")
            var components = URLComponents()
            components.percentEncodedQuery = String(data: try #require(request.body), encoding: .utf8)
            let fields = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
            #expect(fields == sample.expected)
            #expect(request.url.path == sample.path && request.method == .post && request.url.query == nil)
            #expect(request.headers["Content-Type"] == "application/x-www-form-urlencoded")
        }
    }
    private struct Forms: Decodable { let cases: [Form] }
    private struct Form: Decodable {
        let kind: String
        let path: String
        let business: [String: String]
        let staticContext: NativeWriteStaticCommonContext
        let staticMode: NativeWriteStaticCommonParameters.Mode
        let input: NativeWriteDynamicCommonContext
        let expected: [String: String]
    }

    @Test func nativeBusinessTargetsAndReceiptsAreStrict() throws {
        #expect(ContentActionTarget.profile(threadID: 10, postID: 11, section: .replies) ==
                .init(kind: .post, threadID: 10, postID: 11))
        #expect(ContentActionTarget.profile(threadID: 10, postID: 11, section: .threads) ==
                .init(kind: .thread, threadID: 10))
        #expect(!ContentActionTarget.profile(threadID: 10, postID: nil, section: .replies).isValid)
        struct Case: Decodable { let kind: String; let path: String; let fields: [String: String] }
        struct Fixture: Decodable { let cases: [Case] }
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let url = root.appendingPathComponent("API/ContentActions/native-ios-forms.json")
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        for sample in fixture.cases {
            let kind: ContentActionTarget.Kind = sample.kind.contains("Thread") ? .thread
                : sample.kind.contains("Subpost") ? .subpost : .post
            let target = ContentActionTarget(kind: kind, threadID: 10, postID: kind == .subpost ? 12 : kind == .thread ? 0 : 11,
                                             parentPostID: kind == .subpost ? 11 : 0)
            let info = ContentActionInspection(target: target, accountID: 42, authorID: 42, forumID: 9, forumName: "Fixture",
                                               firstPostID: 1, likeCount: 2, liked: false, permitsOwnDeletion: true)
            let operation: NativeContentActionProtocol.Operation = sample.kind.hasPrefix("delete") ? .delete(info)
                : .like(info, sample.kind.hasPrefix("like"))
            #expect(try operation.fields(tbs: "fixture-tbs") == sample.fields)
            #expect(operation.path == sample.path)
        }
        for body in ["{\"error_code\":0}", "{\"error_code\":\"0\"}"] {
            try NativeContentActionProtocol.acknowledge(.init(statusCode: 200, headers: [:], body: Data(body.utf8)))
        }
        for body in ["{}", "{\"error_code\":false}", "{\"error_code\":0.5}", "<html/>"] {
            #expect(throws: ContentActionFailure.outcomeUnknown) {
                try NativeContentActionProtocol.acknowledge(.init(statusCode: 200, headers: [:], body: Data(body.utf8)))
            }
        }
        #expect(throws: ContentActionFailure.rejected) {
            let body = Data("{\"error_code\":3280005,\"error_msg\":\"点赞对象类型错误\"}".utf8)
            try NativeContentActionProtocol.acknowledge(.init(statusCode: 200, headers: [:], body: body))
        }
    }
    @Test func nativeReadUsesExplicitAuthenticatedIdentityAndAgreementPresence() throws {
        let target = ContentActionTarget(kind: .post, threadID: 10, postID: 11)
        let fields = try NativeContentActionProtocol.Operation.inspect(target).fields(tbs: "")
        #expect(fields["back"] == "0" && fields["arround"] == "20")
        #expect(fields["pn"] == nil)
        let request = try NativeContentActionProtocol.encodeRead(fields, common: [:], subpost: false)
        let decoded = try TiebaNativeActions_PageRequest(serializedBytes: request)
        #expect(decoded.data.kz == 10 && decoded.data.pid == 11 && !decoded.data.hasPn)
        #expect(decoded.data.hasBack && decoded.data.back == 0 && decoded.data.arround == 20)
        let sub = ContentActionTarget(kind: .subpost, threadID: 10, postID: 12, parentPostID: 11)
        let subFields = try NativeContentActionProtocol.Operation.inspect(sub).fields(tbs: "")
        let subRequest = try TiebaNativeActions_FloorRequest(serializedBytes:
            NativeContentActionProtocol.encodeRead(subFields, common: [:], subpost: true))
        #expect(subRequest.data.pid == 11 && subRequest.data.spid == 12)
        var response = TiebaNativeActions_PageResponse()
        response.error.errorno = 0; response.data.user.id = 42
        response.data.thread.id = 10; response.data.forum.id = 9
        var post = TiebaNativeActions_Post()
        post.id = 11; post.floor = 2; post.authorID = 42
        post.agree.hasAgree_p = 1; post.agree.agreeType = 2; post.agree.diffAgreeNum = 3
        response.data.postList = [post]
        func inspect(_ value: TiebaNativeActions_PageResponse) throws -> ContentActionInspection {
            let http = HTTPResponse(statusCode: 200, headers: [:], body: try value.serializedData())
            return try NativeContentActionProtocol.inspect(http, target: target, account: 42)
        }
        #expect(try inspect(response).liked == true && inspect(response).likeCount == 3)
        #expect(try inspect(response).canDelete)
        response.data.postList[0].authorID = 41
        #expect(try !inspect(response).canDelete)
        response.data.postList[0].agree.clearHasAgree_p()
        #expect(try inspect(response).liked == false)
        response.data.postList[0].agree.clearDiffAgreeNum()
        #expect(try inspect(response).liked == nil)
        response.data.user.id = 43
        #expect(throws: ContentActionFailure.unavailable) { try inspect(response) }
    }
}
