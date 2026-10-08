import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct U08NativeTransferMetricsTests {
    @Test func lastNetworkTransactionIncludesHeadersAndDoesNotAcceptLateCallbacks() {
        let capture = NativeWriteTransferDelegate()
        capture.record(networkLoad: false, requestHeader: 90, requestBody: 900, responseHeader: 90, responseBody: 900)
        capture.record(networkLoad: true, requestHeader: 10, requestBody: 100, responseHeader: 20, responseBody: 200)
        capture.record(networkLoad: true, requestHeader: 30, requestBody: 300, responseHeader: 40, responseBody: 400)
        capture.record(networkLoad: false, requestHeader: 0, requestBody: 999, responseHeader: 0, responseBody: 999)
        #expect(capture.finish(durationSeconds: 0.25) == .init(durationSeconds: 0.25, uploadBytes: 330, downloadBytes: 440))
        capture.record(networkLoad: true, requestHeader: 1, requestBody: 1, responseHeader: 1, responseBody: 1)
        #expect(capture.finish(durationSeconds: 0.5) == nil)
        #expect(NativeWriteTransferDelegate().finish(durationSeconds: 0.25) == nil)
    }

    @Test func parsedMetricsMatchNativeParserWithoutUsingClientLogID() throws {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let samples = try JSONDecoder().decode(Samples.self, from: Data(contentsOf:
            root.appendingPathComponent("API/Write/native-ios-transfer-metrics.json")))
        for sample in samples.cases {
            let input = sample.input
            let transfer = NativeWriteTransferMeasurement(durationSeconds: input.durationSeconds,
                                                          uploadBytes: input.uploadBytes, downloadBytes: input.downloadBytes)
            #expect(transfer.parsedMetrics(api: input.api, errorCode: input.errorCode) == sample.expected)
        }
    }

    @Test func nextExplicitSendConsumesActualPreviousTransferOnce() async throws {
        let setup = try setup()
        let first = Task { try await setup.send() }
        let firstCall = try await next(setup.http)
        try await setup.http.succeed(firstCall.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        _ = try await first.value
        #expect(setup.runtime.requestMetrics == transfer.parsedMetrics(api: "/c/c/post/add", errorCode: 0))
        let second = Task { try await setup.send() }
        let secondCall = try await next(setup.http)
        let body = try #require(secondCall.request.body)
        let start = try #require(body.range(of: Data("\r\n\r\n".utf8))).upperBound
        let end = try #require(body[start...].range(of: Data("\r\n--Boundary+".utf8))).lowerBound
        let common = try TiebaNativeWrite_PostRequest(serializedBytes: body[start..<end]).data.common
        #expect(common.mApi == "c/c/post/add")
        #expect(common.mSizeU == "1800" && common.mSizeD == "700")
        #expect(common.mCost == "125.000000" && !common.hasMLogid)
        #expect(setup.runtime.requestMetrics.api == nil)
        second.cancel()
        await #expect(throws: CancellationError.self) { try await second.value }
        #expect(setup.runtime.requestMetrics.api == nil)
        #expect(await setup.http.events().count == 4)
    }

    @Test func accountChangeAndCancellationCannotPublishLateMetrics() async throws {
        for changeAccount in [false, true] {
            let setup = try setup()
            let task = Task { try await setup.send() }
            let call = try await next(setup.http)
            if changeAccount {
                setup.auth.install(try #require(SessionCredential(bduss: "other", stoken: "other")))
                try await setup.http.succeed(call.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
            } else {
                task.cancel()
            }
            await #expect(throws: (any Error).self) { try await task.value }
            #expect(setup.runtime.requestMetrics.api == nil)
            #expect(await setup.http.events().count == 2)
        }
    }

    @Test func serverRejectionAndMalformedResponseRecordDifferentNativeResultsWithoutRetry() async throws {
        for malformed in [false, true] {
            let setup = try setup()
            let task = Task { try await setup.send() }
            let call = try await next(setup.http)
            let bytes = malformed ? Data([255]) : try NativeClientFixture.response("post-error-with-ids")
            try await setup.http.succeed(call.id, with: .init(statusCode: 200, body: bytes))
            if malformed {
                await #expect(throws: (any Error).self) { try await task.value }
                #expect(setup.runtime.requestMetrics.result == -3)
                #expect(setup.runtime.requestMetrics.api == "c/c/post/add")
                #expect(setup.runtime.requestMetrics.uploadBytes == 1800 && setup.runtime.requestMetrics.downloadBytes == 700)
            } else {
                #expect(try await task.value.serverRejected)
                #expect(setup.runtime.requestMetrics == transfer.parsedMetrics(api: "/c/c/post/add", errorCode: 5))
            }
            #expect(await setup.http.events().count == 2)
        }
    }

    @Test func missingPayloadRecordsParserMetricsButCannotClaimSuccessfulReply() async throws {
        let setup = try setup()
        let task = Task { try await setup.send() }
        let call = try await next(setup.http)
        try await setup.http.succeed(call.id, with: .init(statusCode: 200, body: NativeClientFixture.response("post-missing-data")))
        let response = try await task.value
        let target = try setup.sample.request().target
        #expect(!response.hasPayload && response.correlatedReceipt(for: target) == nil)
        #expect(setup.runtime.requestMetrics == transfer.parsedMetrics(api: "/c/c/post/add", errorCode: 0))
        #expect(await setup.http.events().count == 2)
    }

    @Test func protobufParserStatisticsMatchNativeReplayIncludingAbsentPayload() async throws {
        for sample in try NativeParserMetricSamples.load().cases where sample.input.protobuf {
            let setup = try setup(measurement: sample.input.measurement)
            let task = Task { try await setup.send() }
            let call = try await next(setup.http)
            try await setup.http.succeed(call.id, with: .init(statusCode: 200, body: sample.input.bytes()))
            if sample.expected.metrics.result == -3 {
                await #expect(throws: (any Error).self) { try await task.value }
                #expect(setup.client.receivedResponseState == nil)
            } else {
                let result = try await task.value
                let target = try setup.sample.request().target
                #expect(result.correlatedReceipt(for: target) == nil)
            }
            #expect(setup.runtime.requestMetrics == sample.expected.metrics)
            #expect(await setup.http.events().count == 2)
        }
    }

    @Test func emptyResponseRemainsUnknownAndItsFailureIsConsumedByNextExplicitSend() async throws {
        let setup = try setup()
        let first = Task { try await setup.send() }
        let call = try await next(setup.http)
        try await setup.http.succeed(call.id, with: .init(statusCode: 200, body: Data()))
        await #expect(throws: HTTPClientError.malformedResponse) { try await first.value }
        #expect(setup.client.receivedResponseState == nil)
        #expect(await setup.http.events().count == 2)
        let second = Task { try await setup.send() }
        let nextCall = try await next(setup.http)
        let body = try #require(nextCall.request.body)
        let start = try #require(body.range(of: Data("\r\n\r\n".utf8))).upperBound
        let end = try #require(body[start...].range(of: Data("\r\n--Boundary+".utf8))).lowerBound
        let common = try TiebaNativeWrite_PostRequest(serializedBytes: body[start..<end]).data.common
        #expect(common.mApi == "c/c/post/add" && common.mResult == "-3")
        #expect(common.mSizeU == "1800" && common.mSizeD == "700")
        #expect(common.mCost == "125.000000" && !common.hasMLogid)
        #expect(setup.runtime.requestMetrics.api == nil)
        second.cancel()
        await #expect(throws: CancellationError.self) { try await second.value }
    }

    private var transfer: NativeWriteTransferMeasurement {
        .init(durationSeconds: 0.125, uploadBytes: 1800, downloadBytes: 700)
    }

    private func setup(measurement: NativeWriteTransferMeasurement? = nil) throws -> Setup {
        let fixture = try NativeClientFixture.load()
        let sample = try #require(fixture.cases.first { $0.kind == "threadReply" })
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let session = try NativeWriteSession(auth: auth, context: auth.context(), account: .init(
            userID: "42", tbs: "fixture-tbs", nameShow: "FixtureName"))
        let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: sample)
        let http = HarnessMockHTTPClient()
        let client = NativeTextWriteClient(session: session, context: auth.context(), runtime: runtime,
                                           loader: MeasuredLoader(base: NativeClientHarnessBridge(client: http),
                                                                  measurement: measurement ?? transfer))
        return Setup(auth: auth, runtime: runtime, http: http, client: client, sample: sample)
    }

    private func next(_ http: HarnessMockHTTPClient) async throws -> HarnessPendingHTTPCall {
        try await http.waitForPendingCallCount(1)
        return try #require(await http.pendingCalls().first)
    }

    private struct MeasuredLoader: NativeWriteTransferLoading {
        let base: NativeClientHarnessBridge
        let measurement: NativeWriteTransferMeasurement
        func measuredData(for request: URLRequest, maximumByteCount: Int) async throws -> NativeWriteMeasuredData {
            let result = try await base.data(for: request, maximumByteCount: maximumByteCount)
            return .init(data: result.0, response: result.1, measurement: measurement)
        }
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
    private struct Sample: Decodable { let input: Input; let expected: NativeWriteRequestMetrics }
    private struct Input: Decodable {
        let api: String
        let durationSeconds: Double
        let errorCode: Int32
        let uploadBytes: UInt32
        let downloadBytes: UInt32
    }
}

struct NativeParserMetricSamples: Decodable {
    let cases: [Sample]
    struct Sample: Decodable { let input: Input; let expected: Expected }
    struct Expected: Decodable { let metrics: NativeWriteRequestMetrics }
    struct Input: Decodable {
        let protobuf: Bool
        let rawHex: String
        let durationSeconds: Double
        let uploadBytes: UInt32
        let downloadBytes: UInt32
        var measurement: NativeWriteTransferMeasurement {
            .init(durationSeconds: durationSeconds, uploadBytes: uploadBytes, downloadBytes: downloadBytes)
        }
        func bytes() throws -> Data {
            let characters = Array(rawHex)
            #expect(characters.count.isMultiple(of: 2))
            return try Data(stride(from: 0, to: characters.count, by: 2).map {
                try #require(UInt8(String(characters[$0...$0 + 1]), radix: 16))
            })
        }
    }
    static func load() throws -> Self {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf:
            root.appendingPathComponent("API/Write/native-ios-parse-failure-metrics.json")))
    }
}
