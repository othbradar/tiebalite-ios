import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

struct U08NativeWriteDiagnosticTests {
    @Test func metadataDistinguishesProtobufJSONAndMissingReceiptWithoutExportingValues() throws {
        var envelope = TiebaNativeWrite_Response()
        let sample = "NeverExportThisValue"
        envelope.error.errorno = 0
        envelope.error.errmsg = "NeverExportThisValue"
        envelope.data.tid = "9007199254740993"
        envelope.data.pid = "9007199254740994"
        envelope.data.info.passToken = sample
        let metadata = NativeWriteResponseDiagnostic(
            status: 200, contentType: "application/protobuf", body: try envelope.serializedData())
        #expect(metadata.protobufDecoded && metadata.hasPayload && metadata.hasError)
        #expect(metadata.protobufErrorCode == 0 && metadata.threadID == .positive && metadata.postID == .positive)
        let encoded = try #require(String(data: JSONEncoder().encode(metadata), encoding: .utf8))
        #expect(!encoded.contains("NeverExportThisValue") && !encoded.contains("900719925474099"))

        let json = NativeWriteResponseDiagnostic(
            status: 200, contentType: "application/json; charset=utf-8",
            body: Data(#"{"error_code":"5","error_msg":"NeverExportThisValue","error":{"errno":6}}"#.utf8))
        #expect(json.isJSONObject && !json.protobufDecoded && json.mediaType == .json)
        #expect(json.jsonErrorCode == 5 && json.nestedJSONErrorCode == 6)
        let empty = NativeWriteResponseDiagnostic(status: 200, contentType: nil, body: Data())
        #expect(!empty.protobufDecoded && !empty.hasPayload && empty.postID == .absent)
        let noReceipt = NativeWriteResponseDiagnostic(status: 200, contentType: "text/html",
                                                      body: Data([0x0A, 0x02, 0x08, 0x00]))
        #expect(noReceipt.protobufDecoded && noReceipt.protobufErrorCode == 0 && noReceipt.postID == .absent)
    }

    @Test func observerForwardsIdenticalRequestResponseAndMakesExactlyOneCall() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let base = DiagnosticFixtureLoader()
        let loader = DebugNativeWriteDataLoader(base: base, diagnostics: DebugNativeWriteDiagnostics(directory: directory))
        let request = try fixtureRequest()
        let result = try await loader.data(for: request, maximumByteCount: 1_024)
        #expect(result.0 == Data([0x0A, 0x02, 0x08, 0x00]))
        #expect((result.1 as? HTTPURLResponse)?.statusCode == 200)
        #expect(await base.requests == [request])
        #expect(await base.limits == [1_024])
        let events = try recorded(directory)
        #expect(events.count == 1 && events[0].operation == "reply" && events[0].failure == nil)
        #expect(events[0].response?.protobufDecoded == true && events[0].response?.hasPayload == false)
    }

    @Test func observerPreservesFailureAndDoesNotRetry() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let base = DiagnosticFixtureLoader(fails: true)
        let loader = DebugNativeWriteDataLoader(base: base, diagnostics: DebugNativeWriteDiagnostics(directory: directory))
        let request = try fixtureRequest()
        await #expect(throws: URLError(.timedOut)) { try await loader.data(for: request, maximumByteCount: 1_024) }
        #expect(await base.requests.count == 1)
        let events = try recorded(directory)
        #expect(events.count == 1 && events[0].failure == .timeout && events[0].response == nil)
    }

    @Test func diagnosticFileIsBoundedAndOnlyContainsClosedMetadata() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let diagnostics = DebugNativeWriteDiagnostics(directory: directory)
        let response = NativeWriteResponseDiagnostic(
            status: 403, contentType: "NeverExportThisValue", body: Data("NeverExportThisValue".utf8))
        for _ in 0..<10 { await diagnostics.record(api: .reply, response: response, failure: nil) }
        let events = try recorded(directory)
        #expect(events.count == 8 && events.first?.sequence == 3 && events.last?.sequence == 10)
        #expect(events.allSatisfy { $0.response?.mediaType == .other })
        let bytes = try Data(contentsOf: directory.appendingPathComponent("NativeWriteDiagnostics-v1.json"))
        #expect(!(try #require(String(data: bytes, encoding: .utf8))).contains("NeverExportThisValue"))
    }

    private func fixtureRequest() throws -> URLRequest {
        var request = URLRequest(url: try #require(URL(string: "https://tiebac.baidu.com/c/c/post/add")))
        request.httpMethod = "POST"
        request.httpBody = Data("Fixture wire bytes".utf8)
        request.setValue("multipart/form-data; boundary=FixtureBoundary", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func recorded(_ directory: URL) throws -> [DebugNativeWriteDiagnostics.Event] {
        try JSONDecoder().decode(
            [DebugNativeWriteDiagnostics.Event].self,
            from: Data(contentsOf: directory.appendingPathComponent("NativeWriteDiagnostics-v1.json")))
    }
}

private actor DiagnosticFixtureLoader: HTTPDataLoading {
    private(set) var requests: [URLRequest] = []
    private(set) var limits: [Int] = []
    let fails: Bool
    init(fails: Bool = false) { self.fails = fails }

    func data(for request: URLRequest, maximumByteCount: Int) throws -> (Data, URLResponse) {
        requests.append(request)
        limits.append(maximumByteCount)
        if fails { throw URLError(.timedOut) }
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(
            url: url, statusCode: 200,
            httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/protobuf"]))
        return (Data([0x0A, 0x02, 0x08, 0x00]), response)
    }
}
