import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct U08NativeHTTPMetricsTests {
    @Test func completedHTTPMatchesNativeDefaultPathWithoutChangingBusinessResults() async throws {
        for sample in try samples().cases {
            let input = sample.input
            let setup = try setup(protobuf: input.protobuf)
            let body: Data
            switch input.bodyKind {
            case "empty": body = Data()
            case "rejected":
                body = input.protobuf ? try NativeClientFixture.response("post-error-with-ids")
                    : Data(#"{"error_code":5,"logid":123}"#.utf8)
            default:
                body = input.protobuf ? try NativeClientFixture.response()
                    : Data(#"{"error_code":0,"logid":123}"#.utf8)
            }
            let response = HTTPResponse(statusCode: input.statusCode, body: body)
            let request = try HTTPRequest(method: .post, url: #require(URL(string: "https://tiebac.baidu.com/c/s/tbs")))
            let task = Task {
                if input.protobuf {
                    let decoded = try await setup.send()
                    #expect(decoded.errorCode == input.errorCode)
                    #expect(decoded.serverRejected == (input.errorCode > 0))
                } else {
                    let decoded = try await setup.preparation.execute(request)
                    #expect(decoded == response)
                }
            }
            let call = try await next(setup.http)
            try await setup.http.succeed(call.id, with: response)
            if input.protobuf && !(200..<300).contains(input.statusCode) {
                await #expect(throws: HTTPClientError.server(statusCode: input.statusCode)) { try await task.value }
                #expect(setup.client.receivedResponseState == nil)
            } else if input.protobuf && body.isEmpty {
                await #expect(throws: HTTPClientError.malformedResponse) { try await task.value }
            } else {
                try await task.value
            }
            #expect(setup.runtime.requestMetrics == sample.expected.metrics, Comment(rawValue: sample.name))
            #expect(await setup.http.pendingCalls().isEmpty)
            #expect(await setup.http.events().count == 2)
        }
    }

    @Test func rejectedHTTPStatisticsCannotCrossAnAccountChangeOrCancellation() async throws {
        for changeAccount in [false, true] {
            for protobuf in [false, true] {
                let setup = try setup(protobuf: protobuf)
                let task = Task {
                    if protobuf { _ = try await setup.send() } else {
                        let request = try HTTPRequest(method: .post,
                                                      url: #require(URL(string: "https://tiebac.baidu.com/c/s/tbs")))
                        _ = try await setup.preparation.execute(request)
                    }
                }
                let call = try await next(setup.http)
                if changeAccount {
                    setup.auth.install(try #require(SessionCredential(bduss: "other", stoken: "other")))
                    try await setup.http.succeed(call.id, with: .init(statusCode: 503, body: Data()))
                } else { task.cancel() }
                await #expect(throws: (any Error).self) { try await task.value }
                #expect(setup.runtime.requestMetrics.api == nil)
                #expect(setup.client.receivedResponseState == nil)
                #expect(await setup.http.events().count == 2)
            }
        }
    }

    @Test func noMeasurementDoesNotInventHTTPFailureStatistics() async throws {
        let setup = try setup(protobuf: true, measured: false)
        let task = Task { try await setup.send() }
        let call = try await next(setup.http)
        try await setup.http.succeed(call.id, with: .init(statusCode: 503, body: NativeClientFixture.response()))
        await #expect(throws: HTTPClientError.server(statusCode: 503)) { try await task.value }
        #expect(setup.runtime.requestMetrics.api == nil)
        #expect(await setup.http.events().count == 2)
    }

    @Test func rejectedHTTPStatisticsAreConsumedOnceByTheNextExplicitReply() async throws {
        let setup = try setup(protobuf: true)
        let first = Task { try await setup.send() }
        let call = try await next(setup.http)
        try await setup.http.succeed(call.id, with: .init(statusCode: 429, body: NativeClientFixture.response()))
        await #expect(throws: HTTPClientError.server(statusCode: 429)) { try await first.value }
        #expect(await setup.http.pendingCalls().isEmpty)
        let second = Task { try await setup.send() }
        let outgoing = try await next(setup.http)
        let body = try #require(outgoing.request.body)
        let start = try #require(body.range(of: Data("\r\n\r\n".utf8))).upperBound
        let end = try #require(body[start...].range(of: Data("\r\n--Boundary+".utf8))).lowerBound
        let common = try TiebaNativeWrite_PostRequest(serializedBytes: body[start..<end]).data.common
        #expect(common.mApi == "c/c/post/add" && common.mResult == "-1" && common.mCost == "250.000000")
        #expect(!common.hasMLogid && !common.hasMSizeU && !common.hasMSizeD)
        #expect(setup.runtime.requestMetrics.api == nil)
        try await setup.http.succeed(outgoing.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        #expect(try await second.value.postID == "401")
        #expect(await setup.http.events().count == 4)
    }

    private func setup(protobuf: Bool, measured: Bool = true) throws -> Setup {
        let fixture = try NativeClientFixture.load()
        let sample = try #require(fixture.cases.first { $0.kind == "threadReply" })
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let context = auth.context()
        let session = try NativeWriteSession(auth: auth, context: context, account: .init(
            userID: "42", tbs: "fixture-tbs", nameShow: "FixtureName"))
        let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: sample)
        if !protobuf { runtime.requestMetrics = .init(api: nil, logID: 0, cost: 0, result: 0, uploadBytes: 0, downloadBytes: 0) }
        let http = HarnessMockHTTPClient()
        let loader = MeasuredLoader(base: NativeClientHarnessBridge(client: http), measured: measured)
        let client = NativeTextWriteClient(session: session, context: context, runtime: runtime, loader: loader)
        let preparation = NativePreparationHTTPClient(loader: loader, runtime: runtime) { _ = try auth.authorization(for: context) }
        return Setup(auth: auth, runtime: runtime, http: http, client: client, sample: sample, preparation: preparation)
    }

    private func next(_ http: HarnessMockHTTPClient) async throws -> HarnessPendingHTTPCall {
        try await http.waitForPendingCallCount(1)
        return try #require(await http.pendingCalls().first)
    }

    private func samples() throws -> Samples {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        return try JSONDecoder().decode(Samples.self, from: Data(contentsOf:
            root.appendingPathComponent("API/Write/native-ios-http-metrics.json")))
    }

    private struct MeasuredLoader: NativeWriteTransferLoading {
        let base: NativeClientHarnessBridge
        let measured: Bool
        func measuredData(for request: URLRequest, maximumByteCount: Int) async throws -> NativeWriteMeasuredData {
            let result = try await base.data(for: request, maximumByteCount: maximumByteCount)
            return .init(data: result.0, response: result.1, measurement: measured
                ? .init(durationSeconds: 0.25, uploadBytes: 1800, downloadBytes: 700) : nil)
        }
    }
    private struct Setup {
        let auth: SessionAuthContextProvider
        let runtime: NativeClientFixtureRuntime
        let http: HarnessMockHTTPClient
        let client: NativeTextWriteClient
        let sample: NativeClientSample
        let preparation: NativePreparationHTTPClient
        func send() async throws -> NativeWriteDecodedResponse {
            try await client.send(sample.request(), content: .prepared(sample.content), origin: sample.origin())
        }
    }
    private struct Samples: Decodable { let cases: [Sample] }
    private struct Sample: Decodable { let name: String; let input: Input; let expected: Expected }
    private struct Expected: Decodable { let metrics: NativeWriteRequestMetrics }
    private struct Input: Decodable { let protobuf: Bool; let statusCode: Int; let bodyKind: String; let errorCode: Int32 }
}
