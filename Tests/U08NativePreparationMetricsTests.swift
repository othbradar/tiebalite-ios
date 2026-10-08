import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct U08NativePreparationMetricsTests {
    @Test func malformedJSONStatisticsMatchNativeParserReplay() throws {
        for sample in try NativeParserMetricSamples.load().cases where !sample.input.protobuf {
            let response = try HTTPResponse(statusCode: 200, body: sample.input.bytes())
            #expect(NativePreparationResponseMetrics.decode(response, api: .tbs,
                                                            measurement: sample.input.measurement) == sample.expected.metrics)
        }
    }

    @Test func jsonStatisticsMatchNativeReplayIncludingNumericAndStringLogIDs() throws {
        let samples = try samples()
        for sample in samples.cases {
            let input = sample.input
            let api = try #require(NativeWriteAPI(rawValue: input.api))
            let result = NativePreparationResponseMetrics.decode(
                .init(statusCode: 200, body: Data(input.responseJSON.utf8)), api: api,
                measurement: .init(durationSeconds: input.durationSeconds,
                                   uploadBytes: input.uploadBytes, downloadBytes: input.downloadBytes))
            #expect(result == sample.expected, "\(sample.name)")
        }
    }

    @Test func ordinaryAccountHeaderMatchesNativeWithoutAddingProtoHeaders() throws {
        let setup = try setup()
        let authorization = try setup.auth.authorization(for: setup.auth.context())
        let values = try setup.runtime.context(for: .account, authorization: authorization, account: nil)
        for sample in try samples().headers {
            let runtime = NativeWriteRuntimeContext(common: values.common, http: .init(
                userAgent: "fixture-agent", acceptLanguage: nil, clientLogID: sample.clientLogID,
                timeout: 10, responseState: nil, cookies: values.http.cookies), multipartBoundary: values.multipartBoundary)
            let request = try NativeAccountPreparation.request(parameters: ["bdusstoken": "fixture", "net_type": "1"], runtime: runtime)
            #expect(request.headers["client_logid"] == sample.expected["client_logid"])
            #expect(request.headers["User-Agent"] == sample.expected["User-Agent"])
            #expect(request.headers["x_bd_data_type"] == nil && request.url.query == nil)
            #expect(request.body == Data("bdusstoken=fixture&net_type=1".utf8))
        }
    }

    @Test func accountAndOptionalTBSStatisticsReachTheNextRequestWithoutExtraCalls() async throws {
        for needsTBS in [false, true] {
            let setup = try setup()
            let task = Task { try await setup.repository.send(setup.sample.request(), context: setup.auth.context()) }
            let account = try await next(setup.http)
            #expect(account.request.url.path == "/c/s/login")
            #expect(account.request.headers["client_logid"] == "1000001")
            try await setup.http.succeed(account.id, with: accountResponse(tbs: needsTBS ? "" : "fixture-tbs"))
            if needsTBS {
                let tbs = try await next(setup.http)
                #expect(tbs.request.url.path == "/c/s/tbs")
                let form = try #require(String(data: tbs.request.body ?? Data(), encoding: .utf8))
                #expect(form.contains("m_api=c/s/login") && form.contains("m_logid=111"))
                try await setup.http.succeed(tbs.id, with: .init(statusCode: 200, body: Data(
                    #"{"error_code":0,"logid":222,"tbs":"fixture-tbs"}"#.utf8)))
            }
            let write = try await next(setup.http)
            let common = try common(write.request)
            #expect(common.mApi == (needsTBS ? "c/s/tbs" : "c/s/login"))
            #expect(common.mLogid == (needsTBS ? "222" : "111"))
            #expect(common.mSizeU == "1750" && common.mSizeD == "650" && common.mCost == "250.000000")
            try await setup.http.succeed(write.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
            #expect(try await task.value.postID == 401)
            #expect(await setup.http.events().filter { if case .started = $0 { return true }; return false }.count == (needsTBS ? 3 : 2))
        }
    }

    @Test func failedPreparationKeepsNativeResultWithoutSendingAndCannotLeakAcrossAccounts() async throws {
        let setup = try setup()
        let first = Task { try await setup.repository.send(setup.sample.request(), context: setup.auth.context()) }
        let rejected = try await next(setup.http)
        try await setup.http.succeed(rejected.id, with: .init(statusCode: 200, body: Data(#"{"error_code":5,"logid":333}"#.utf8)))
        await #expect(throws: TextWriteFailure.self) { try await first.value }
        #expect(setup.runtime.requestMetrics.api == "c/s/login")
        #expect(setup.runtime.requestMetrics.result == 5 && setup.runtime.requestMetrics.logID == 333)
        #expect(await setup.http.pendingCalls().isEmpty)
        setup.auth.install(try #require(SessionCredential(bduss: "other", stoken: "other")))
        let second = Task { try await setup.repository.send(setup.sample.request(), context: setup.auth.context()) }
        let newAccount = try await next(setup.http)
        let body = try #require(String(data: newAccount.request.body ?? Data(), encoding: .utf8))
        #expect(!body.contains("m_api=") && !body.contains("m_logid="))
        second.cancel()
        await #expect(throws: CancellationError.self) { try await second.value }
        #expect(await setup.http.events().count == 4)
    }

    @Test func cancelledOrOldAccountPreparationCannotPublishMetricsOrWrite() async throws {
        for changesAccount in [false, true] {
            let setup = try setup()
            let task = Task { try await setup.repository.send(setup.sample.request(), context: setup.auth.context()) }
            let call = try await next(setup.http)
            if changesAccount {
                setup.auth.install(try #require(SessionCredential(bduss: "other", stoken: "other")))
                try await setup.http.succeed(call.id, with: accountResponse(tbs: "fixture-tbs"))
            } else {
                task.cancel()
            }
            await #expect(throws: (any Error).self) { try await task.value }
            #expect(setup.runtime.requestMetrics.api == nil && setup.runtime.requestMetrics.logID == 0)
            #expect(await setup.http.events().count == 2)
        }
    }

    @Test func invalidJSONRecordsParseFailureButUnverifiedHTTPFailureDoesNotInventMetrics() throws {
        let measurement = NativeWriteTransferMeasurement(durationSeconds: 0.25, uploadBytes: 1750, downloadBytes: 650)
        for bytes in [Data(), Data([255]), Data("[]".utf8), Data(#"{"logid":999}"#.utf8),
                      Data(#"{"error_code":null,"error":{"errno":[]},"logid":999}"#.utf8)] {
            let metrics = NativePreparationResponseMetrics.decode(
                .init(statusCode: 200, body: bytes), api: .account, measurement: measurement)
            #expect(metrics == .init(api: "c/s/login", logID: 0, cost: 250, result: -3,
                                     uploadBytes: 1750, downloadBytes: 650))
        }
        let valid = Data(#"{"error_code":0,"logid":999}"#.utf8)
        #expect(NativePreparationResponseMetrics.decode(
            .init(statusCode: 503, body: valid), api: .account, measurement: measurement) == nil)
        #expect(NativePreparationResponseMetrics.decode(.init(statusCode: 200, body: valid), api: .reply, measurement: measurement) == nil)
    }

    @Test func parsedMetricsCannotTurnMissingAccountOrTBSIntoSuccess() async throws {
        for missingAccount in [false, true] {
            let setup = try setup()
            let task = Task { try await setup.repository.send(setup.sample.request(), context: setup.auth.context()) }
            let call = try await next(setup.http)
            let invalid = HTTPResponse(statusCode: 200, body: Data(#"{"error_code":0,"logid":444}"#.utf8))
            try await setup.http.succeed(call.id, with: missingAccount ? invalid : accountResponse(tbs: ""))
            if !missingAccount {
                let tbs = try await next(setup.http)
                try await setup.http.succeed(tbs.id, with: invalid)
            }
            await #expect(throws: TextWriteFailure.self) { try await task.value }
            #expect(setup.runtime.requestMetrics.api == (missingAccount ? "c/s/login" : "c/s/tbs"))
            #expect(setup.runtime.requestMetrics.logID == 444)
            let started = await setup.http.events().filter { if case .started = $0 { return true }; return false }
            #expect(started.count == (missingAccount ? 1 : 2))
        }
    }

    private func setup() throws -> Setup {
        let fixture = try NativeClientFixture.load()
        let sample = try #require(fixture.cases.first { $0.kind == "threadReply" })
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: sample)
        runtime.clientLogID = 1000001
        let http = HarnessMockHTTPClient()
        return Setup(auth: auth, http: http, runtime: runtime, sample: sample, repository: NativeLiveTextWriteRepository(
            auth: auth, loader: MeasuredLoader(base: NativeClientHarnessBridge(client: http)), runtime: runtime,
            firstLogin: { true }, didPrepareAccount: {}))
    }

    private func accountResponse(tbs: String) -> HTTPResponse {
        .init(statusCode: 200, body: Data(
            "{\"error_code\":0,\"logid\":111,\"user\":{\"id\":\"42\",\"name\":\"Fixture\"},\"anti\":{\"tbs\":\"\(tbs)\"}}".utf8))
    }

    private func next(_ http: HarnessMockHTTPClient) async throws -> HarnessPendingHTTPCall {
        try await http.waitForPendingCallCount(1)
        return try #require(await http.pendingCalls().first)
    }

    private func common(_ request: HTTPRequest) throws -> TiebaNativeWrite_Common {
        let body = try #require(request.body)
        let start = try #require(body.range(of: Data("\r\n\r\n".utf8))).upperBound
        let end = try #require(body[start...].range(of: Data("\r\n--Boundary+".utf8))).lowerBound
        return try TiebaNativeWrite_PostRequest(serializedBytes: body[start..<end]).data.common
    }

    private struct MeasuredLoader: NativeWriteTransferLoading {
        let base: NativeClientHarnessBridge
        func measuredData(for request: URLRequest, maximumByteCount: Int) async throws -> NativeWriteMeasuredData {
            let result = try await base.data(for: request, maximumByteCount: maximumByteCount)
            return .init(data: result.0, response: result.1,
                         measurement: .init(durationSeconds: 0.25, uploadBytes: 1750, downloadBytes: 650))
        }
    }

    private struct Setup {
        let auth: SessionAuthContextProvider
        let http: HarnessMockHTTPClient
        let runtime: NativeClientFixtureRuntime
        let sample: NativeClientSample
        let repository: NativeLiveTextWriteRepository
    }

    private func samples() throws -> Samples {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        return try JSONDecoder().decode(Samples.self, from: Data(contentsOf:
            root.appendingPathComponent("API/Write/native-ios-form-metrics.json")))
    }
    private struct Samples: Decodable { let cases: [Sample]; let headers: [Header] }
    private struct Sample: Decodable { let name: String; let input: Input; let expected: NativeWriteRequestMetrics }
    private struct Header: Decodable { let clientLogID: Int64; let expected: [String: String] }
    private struct Input: Decodable {
        let api: String
        let responseJSON: String
        let durationSeconds: Double
        let uploadBytes: UInt32
        let downloadBytes: UInt32
    }
}
