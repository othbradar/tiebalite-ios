import Foundation
import Testing
@testable import TiebaLite

struct U08NativeImageUploadTests {
    @Test func imageBusinessFieldsMatchNativeBranches() throws {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-image-upload.json"))
        let fixture = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cases = try #require(fixture["cases"] as? [[String: Any]])
        for sample in cases.prefix(3) {
            let input = try #require(sample["input"] as? [String: Any])
            let chunk = try #require(input["chunk"] as? [String: Any])
            let model = try #require(input["model"] as? [String: Any])
            let photo = ComposerPhoto(
                id: "0123456789abcdef0123456789abcdef", file: .init(url: URL(fileURLWithPath: "/unused"), removesOnRelease: false),
                width: 640, height: 480, byteCount: 600_000)
            let actual = NativeImageUploadProtocol.fields(photo: photo, chunk: 1,
                                                          final: chunk["isFinish"] as? Int == 1,
                                                          forumName: try #require(model["barName"] as? String))
            let expected = try #require(sample["expected"] as? [String: Any])
            #expect(actual == expected["fields"] as? [String: String])
            #expect(actual["groupId"] == nil && actual["resourceId"] == photo.id.uppercased())
        }
    }

    @Test func uploadCommonAndSignMatchNativeReplay() throws {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-image-upload.json"))
        for sample in try JSONDecoder().decode(Fixture.self, from: data).forms {
            var builder = NativeWriteCommonParameters()
            var metrics = sample.metrics
            let context = NativeWriteCommonContext(
                staticValues: sample.staticContext, staticMode: sample.name == "standard" ? .cached : .recomputed,
                dynamicValues: sample.input, metadata: .init(packageVersion: nil, experimentHits: nil, experimentMisses: nil))
            #expect(try builder.prepareImageUpload(context, business: sample.business, metrics: &metrics) == sample.expected)
        }
    }

    @MainActor @Test func multipartUsesActualChunkAndNativeTimeoutWithoutProtoOrAndroidFields() throws {
        let fixture = try NativeClientFixture.load()
        let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: try #require(fixture.cases.first))
        runtime.clientLogID = 77
        let context = try runtime.context(for: .imageUpload, authorization: .init(bduss: "fx", stoken: "fy"),
                                          account: .init(userID: "42", tbs: "fixture-tbs"))
        for count in [13, 1_023, 1_024, NativeImageUploadProtocol.chunkSize] {
            let bytes = Data(repeating: 0xa5, count: count)
            let request = try NativeImageUploadProtocol.request(
                fields: ["sign": "fixture-sign", "BDUSS": "fx", "_client_type": "1"], bytes: bytes, runtime: context)
            #expect(request.url.absoluteString == "https://tiebac.baidu.com/c/s/uploadPicture")
            #expect(request.timeout == (count >= 1_024 ? 120 : 19))
            #expect(request.headers["client_logid"] == "77" && request.headers["x_bd_data_type"] == nil)
            let body = try #require(request.body)
            let header = Data("name=\"chunk\"; filename=\"chunk\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8)
            let start = try #require(body.range(of: header)).upperBound
            #expect(body[start..<(start + count)] == bytes)
            #expect(request.headers["Content-Length"] == String(body.count))
        }
    }

    @Test func finalServerDimensionsAndIDAreRequiredBeforeContentTokenExists() throws {
        let partial = HTTPResponse(statusCode: 200, body: Data(#"{"error_code":0}"#.utf8))
        #expect(try NativeImageUploadProtocol.decode(partial, final: false) == nil)
        #expect(throws: ImageUploadFailure.malformedResponse) { try NativeImageUploadProtocol.decode(partial, final: true) }
        let final = response(#"{"error_code":0,"picId":"fixture_pic","picInfo":{"originPic":{"width":"640","height":480}}}"#)
        let receipt = try #require(try NativeImageUploadProtocol.decode(final, final: true))
        #expect(receipt.token == "#(pic,fixture_pic,640,480)" && receipt.source == NativeImageUploadProtocol.receiptSource)
        for json in [#"{"error_code":4}"#, #"{"error_code":true}"#, #"{}"#,
                     #"{"error_code":0,"picId":"invalid),token","picInfo":{"originPic":{"width":1,"height":1}}}"#,
                     #"{"error_code":0,"picId":"fixture","picInfo":{"originPic":{"width":0,"height":1}}}"#] {
            #expect(throws: ImageUploadFailure.self) { try NativeImageUploadProtocol.decode(response(json), final: true) }
        }
        #expect(throws: HTTPClientError.server(statusCode: 503)) {
            try NativeImageUploadProtocol.decode(.init(statusCode: 503, body: final.body), final: true)
        }
    }

    private func response(_ json: String) -> HTTPResponse { .init(statusCode: 200, body: Data(json.utf8)) }
    private struct Fixture: Decodable { let forms: [Form] }
    private struct Form: Decodable {
        let name: String
        let input: NativeWriteDynamicCommonContext
        let staticContext: NativeWriteStaticCommonContext
        let business: [String: String]
        let metrics: NativeWriteRequestMetrics
        let expected: [String: String]
    }
}
