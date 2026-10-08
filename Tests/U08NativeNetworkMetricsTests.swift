import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct U08NativeNetworkMetricsTests {
    @Test func urlFailuresMatchNativeReplayAndNeverUsePartialBytes() throws {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-network-failure-metrics.json"))
        for sample in try JSONDecoder().decode(Samples.self, from: data).cases where sample.input.state == 4 {
            guard let code = sample.input.errorCode else { continue }
            let failure = try #require(NativeWriteTransferFailure(error: URLError(URLError.Code(rawValue: code)),
                                                                  durationSeconds: sample.input.durationSeconds))
            #expect(failure.metrics(api: sample.input.api) == sample.expected.metrics)
            #expect(String(reflecting: failure) == "NativeWriteTransferFailure(redacted)")
        }
        #expect(NativeWriteTransferFailure(error: URLError(.cancelled), durationSeconds: 1) == nil)
        #expect(NativeWriteTransferFailure(error: CancellationError(), durationSeconds: 1) == nil)
        #expect(NativeWriteTransferFailure(error: HTTPClientError.responseTooLarge(limit: 100), durationSeconds: 1) == nil)
        #expect(NativeWriteTransferFailure(error: URLError(.timedOut), durationSeconds: .nan) == nil)
    }

    @Test func failureIsConsumedOnlyByTheNextExplicitWriteWithoutRetry() async throws {
        let setup = try setup()
        let first = Task { try await setup.send() }
        let failed = try await next(setup.http)
        try await setup.http.fail(failed.id, with: .timedOut)
        await #expect(throws: HTTPClientError.timedOut) { try await first.value }
        #expect(setup.runtime.requestMetrics.result == -2)
        #expect(await setup.http.pendingCalls().isEmpty)
        #expect(await setup.http.events().count == 2)
        let second = Task { try await setup.send() }
        let call = try await next(setup.http)
        let body = try #require(call.request.body)
        let start = try #require(body.range(of: Data("\r\n\r\n".utf8))).upperBound
        let end = try #require(body[start...].range(of: Data("\r\n--Boundary+".utf8))).lowerBound
        let common = try TiebaNativeWrite_PostRequest(serializedBytes: body[start..<end]).data.common
        #expect(common.mApi == "c/c/post/add" && common.mResult == "-2" && common.mCost == "250.000000")
        // The native Common builder omits consumed zero counters entirely.
        #expect(!common.hasMSizeU && !common.hasMSizeD && !common.hasMLogid)
        #expect(setup.runtime.requestMetrics.api == nil)
        try await setup.http.succeed(call.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        #expect(try await second.value.errorCode == 0)
        #expect(await setup.http.events().count == 4)
    }

    @Test func cancelledOrOldAccountNetworkFailureCannotPublishStatistics() async throws {
        for changesAccount in [false, true] {
            let setup = try setup()
            let task = Task { try await setup.send() }
            let call = try await next(setup.http)
            if changesAccount {
                setup.auth.install(try #require(SessionCredential(bduss: "other", stoken: "other")))
                try await setup.http.fail(call.id, with: .offline)
            } else {
                task.cancel()
            }
            await #expect(throws: (any Error).self) { try await task.value }
            #expect(setup.runtime.requestMetrics.api == nil)
            #expect(setup.client.receivedResponseState == nil)
            #expect(await setup.http.events().count == 2)
        }
    }

    @Test func preparationFailureRecordsItsOwnAPIAndHonorsAuthorization() async throws {
        for changesAccount in [false, true] {
            let setup = try setup()
            let context = setup.auth.context()
            let client = NativePreparationHTTPClient(
                loader: HarnessNativeFailureLoader(base: .init(client: setup.http)), runtime: setup.runtime
            ) { _ = try setup.auth.authorization(for: context) }
            let request = try HTTPRequest(method: .post, url: #require(URL(string: "https://tiebac.baidu.com/c/s/login")))
            let task = Task { try await client.execute(request) }
            let call = try await next(setup.http)
            if changesAccount { setup.auth.install(try #require(SessionCredential(bduss: "other", stoken: "other"))) }
            try await setup.http.fail(call.id, with: .offline)
            await #expect(throws: (any Error).self) { try await task.value }
            #expect(setup.runtime.requestMetrics.api == (changesAccount ? nil : "c/s/login"))
            #expect(setup.runtime.requestMetrics.result == (changesAccount ? 0 : -1))
            #expect(await setup.http.events().count == 2)
        }
    }

    @Test func debugObservationRecognizesWrappedFailureWithoutExposingUnderlyingDescription() throws {
        let failure = try #require(NativeWriteTransferFailure(error: URLError(.timedOut), durationSeconds: 0.25))
        #expect(DebugNativeWriteDiagnostics.Failure.classify(failure) == .timeout)
        #expect(String(describing: failure) == "NativeWriteTransferFailure(redacted)")
    }

    @Test func timedOutNativeWriteKeepsFailureAndRecordsNextRequestStatistics() async throws {
        let fixture = try NativeClientFixture.load()
        let sample = try #require(fixture.cases.first { $0.kind == "threadReply" })
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let session = try NativeWriteSession(auth: auth, context: auth.context(), account: .init(
            userID: "42", tbs: "fixture-tbs", nameShow: "FixtureName"))
        let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: sample)
        let configuration = URLSessionHTTPClient.makeEphemeralConfiguration()
        configuration.protocolClasses = [HarnessNativeTimeoutURLProtocol.self]
        let client = NativeTextWriteClient(session: session, context: auth.context(), runtime: runtime,
                                           loader: NativeWriteMeasuredLoader(base: URLSessionDataLoader(configuration: configuration)))
        await #expect(throws: HTTPClientError.timedOut) {
            try await client.send(sample.request(), content: .prepared(sample.content), origin: sample.origin())
        }
        #expect(client.didStartWrite && client.receivedResponseState == nil)
        #expect(runtime.requestMetrics.api == "c/c/post/add")
        #expect(runtime.requestMetrics.result == -2)
        #expect(runtime.requestMetrics.cost >= 0)
        #expect(runtime.requestMetrics.uploadBytes == 0 && runtime.requestMetrics.downloadBytes == 0)
    }

    private func setup() throws -> Setup {
        let fixture = try NativeClientFixture.load()
        let sample = try #require(fixture.cases.first { $0.kind == "threadReply" })
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let session = try NativeWriteSession(auth: auth, context: auth.context(), account: .init(
            userID: "42", tbs: "fixture-tbs", nameShow: "FixtureName"))
        let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: sample)
        let http = HarnessMockHTTPClient()
        let client = NativeTextWriteClient(session: session, context: auth.context(), runtime: runtime,
                                           loader: HarnessNativeFailureLoader(base: .init(client: http)))
        return Setup(auth: auth, runtime: runtime, http: http, client: client, sample: sample)
    }

    private func next(_ http: HarnessMockHTTPClient) async throws -> HarnessPendingHTTPCall {
        try await http.waitForPendingCallCount(1)
        return try #require(await http.pendingCalls().first)
    }

    private struct Setup {
        let auth: SessionAuthContextProvider
        let runtime: NativeClientFixtureRuntime
        let http: HarnessMockHTTPClient
        let client: NativeTextWriteClient
        let sample: NativeClientSample
        func send() async throws -> NativeWriteDecodedResponse {
            try await client.send(sample.request(), content: .prepared(sample.content), origin: sample.origin())
        }
    }
    private struct Samples: Decodable { let cases: [Sample] }
    private struct Sample: Decodable { let input: Input; let expected: Expected }
    private struct Input: Decodable { let api: String; let state: Int; let errorCode: Int?; let durationSeconds: Double }
    private struct Expected: Decodable { let metrics: NativeWriteRequestMetrics }
}
