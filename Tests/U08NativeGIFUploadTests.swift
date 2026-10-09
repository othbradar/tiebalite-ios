import CryptoKit
import Foundation
import ImageIO
import Testing
@testable import TiebaLite

struct U08NativeGIFUploadTests {
    @Test func uploadSizePolicyMatchesNativeInstructionReplay() throws {
        let root = try #require(Bundle(for: FixtureBundleMarker.self).url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: root.appendingPathComponent("API/Write/native-ios-gif-policy.json"))
        let fixture = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for sample in try #require(fixture["sizes"] as? [[String: Any]]) {
            let size = try #require(sample["byteCount"] as? Int)
            #expect((size < ComposerGIFData.byteLimit) == (sample["accepted"] as? Bool))
        }
    }

    @Test func importedGIFRetainsEncodedFramesAndDraftReopeningRetainsBytes() async throws {
        let bytes = try TestImageFixtureFactory.animatedGIF()
        let photo = try await prepare(bytes, name: "draft")
        #expect(try Data(contentsOf: photo.file.url) == bytes)
        #expect(photo.width == 12 && photo.height == 8)
        #expect(photo.id == digest(bytes))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("native-gif-draft")
        defer { try? FileManager.default.removeItem(at: folder) }
        let key = ComposerDraftStorage.Key(namespace: "fixture", target: "reply-101")
        var draft = TextDraft(content: "Fixture animation")
        draft.photos = [photo]
        try await ComposerDraftStorage(directory: folder).save(draft, key: key)
        let restored = try await ComposerDraftStorage(directory: folder).load(key)
        let stored = try #require(restored.photos.first)
        let data = try Data(contentsOf: stored.file.url)
        #expect(data == bytes && stored.uploaded == nil)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        #expect(CGImageSourceGetCount(source) == 2)
    }

    @Test func gifThumbnailUsesExistingLoaderAndKeepsUploadFileIntact() async throws {
        let bytes = try TestImageFixtureFactory.animatedGIF()
        let photo = try await prepare(bytes, name: "thumbnail")
        let network = HarnessImageDataLoader(outcomes: [:])
        let loader = ProductionImageLoader(loader: network)
        let thumbnail = try await loader.loadLocalPhoto(photo)
        let size = try #require(thumbnail.pixelSize)
        #expect(size.width > 0 && size.height > 0)
        #expect(try Data(contentsOf: photo.file.url) == bytes)
        #expect(await network.recordedRequests().isEmpty)
    }

    @Test func gifSizeLimitRejectsAtTenMiBWithoutFlattening() async throws {
        for size in [10 * 1_024 * 1_024 - 1, 10 * 1_024 * 1_024, 10 * 1_024 * 1_024 + 1] {
            let bytes = try paddedGIF(size: size)
            if size < 10 * 1_024 * 1_024 {
                let photo = try await prepare(bytes, name: "limit-\(size)")
                #expect(photo.byteCount == size)
                #expect(try Data(contentsOf: photo.file.url) == bytes)
            } else {
                await #expect(throws: ImageUploadFailure.tooLarge) { try await prepare(bytes, name: "limit-\(size)") }
            }
        }
    }

    @MainActor @Test func gifLargerThanJPEGLimitUsesExactBytesAcrossNativeChunks() async throws {
        let bytes = try paddedGIF(size: 5_242_900)
        // Bypass import here so this also catches a JPEG-only upload preflight.
        let photo = try rawPhoto(bytes, name: "chunks")
        let http = RecordingGIFClient()
        let fixture = try NativeClientFixture.load()
        let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: try #require(fixture.cases.first))
        let context = try runtime.context(for: .imageUpload, authorization: .init(bduss: "fx", stoken: "fy"),
                                          account: .init(userID: "42", tbs: "fixture-tbs"))
        let uploader = NativeImageUploadClient(client: http, validateAuthorization: {}, makeRequest: { photo, chunk, final, data in
            var fields = NativeImageUploadProtocol.fields(photo: photo, chunk: chunk, final: final, forumName: "FixtureForum")
            fields.merge(["sign": "fixture-sign", "BDUSS": "fx", "_client_type": "1"]) { _, value in value }
            return try NativeImageUploadProtocol.request(fields: fields, bytes: data, runtime: context)
        })
        let receipt = try await uploader.upload(photo, progress: { _ in })
        #expect(receipt.token == "#(pic,fixture_gif,12,8)")
        let requests = await http.requests
        #expect(requests.count == (bytes.count + NativeImageUploadProtocol.chunkSize - 1) / NativeImageUploadProtocol.chunkSize)
        var joined = Data()
        for (index, request) in requests.enumerated() {
            let body = try #require(request.body)
            let header = Data("name=\"chunk\"; filename=\"chunk\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8)
            let start = try #require(body.range(of: header)).upperBound
            let size = min(NativeImageUploadProtocol.chunkSize, bytes.count - joined.count)
            joined.append(body[start..<(start + size)])
            #expect(body.range(of: Data("name=\"chunkNo\"\r\n\r\n\(index + 1)\r\n".utf8)) != nil)
            #expect(body.range(of: Data("name=\"saveOrigin\"\r\n\r\n0\r\n".utf8)) != nil)
            #expect(body.range(of: Data(photo.id.uppercased().utf8)) != nil)
        }
        #expect(joined == bytes)
    }

    @MainActor @Test func invalidOrChangedGIFCannotReachTransport() async throws {
        for changed in [true, false] {
            let bytes = changed ? try TestImageFixtureFactory.animatedGIF() : Data("GIF89a-invalid".utf8)
            let photo = try rawPhoto(bytes, name: "invalid-\(changed)")
            if changed { try Data(repeating: 0, count: bytes.count).write(to: photo.file.url) }
            let http = RecordingGIFClient()
            let uploader = NativeImageUploadClient(client: http, validateAuthorization: {}, makeRequest: { _, _, _, _ in
                throw HTTPClientError.unavailable
            })
            await #expect(throws: ImageUploadFailure.invalidImage) { try await uploader.upload(photo, progress: { _ in }) }
            #expect(await http.requests.isEmpty)
        }
    }

    @MainActor @Test func gifSupportDoesNotRelaxExistingJPEGLimit() async throws {
        var bytes = Data([0xff, 0xd8, 0xff])
        bytes.append(Data(repeating: 1, count: 5_242_880))
        let photo = try rawPhoto(bytes, name: "oversized-jpeg")
        let uploader = NativeImageUploadClient(client: DisabledHTTPClient(), validateAuthorization: {}, makeRequest: { _, _, _, _ in
            throw HTTPClientError.unavailable
        })
        await #expect(throws: ImageUploadFailure.invalidImage) { try await uploader.upload(photo, progress: { _ in }) }
    }

    private func prepare(_ bytes: Data, name: String) async throws -> ComposerPhoto {
        let photo = try rawPhoto(bytes, name: name)
        return try await ComposerPhotoPreparation().prepare(file: photo.file)
    }

    private func rawPhoto(_ bytes: Data, name: String) throws -> ComposerPhoto {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("native-gif-\(name).gif")
        try bytes.write(to: url)
        return .init(id: digest(bytes), file: .init(url: url), width: 12, height: 8, byteCount: bytes.count)
    }

    private func digest(_ bytes: Data) -> String {
        Insecure.MD5.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    private func paddedGIF(size: Int) throws -> Data {
        var bytes = try TestImageFixtureFactory.animatedGIF()
        #expect(bytes.last == 0x3b)
        bytes.removeLast()
        bytes.append(contentsOf: [0x21, 0xfe]) // Legal GIF comment extension, no additional decoded frames.
        var remaining = size - bytes.count - 2 // Terminator and trailer.
        while remaining > 0 {
            var count = min(255, remaining - 1)
            if remaining - count - 1 == 1 { count -= 1 }
            bytes.append(UInt8(count))
            bytes.append(Data(repeating: 0x61, count: count))
            remaining -= count + 1
        }
        bytes.append(contentsOf: [0, 0x3b])
        return bytes
    }
}

private actor RecordingGIFClient: HTTPClient {
    private(set) var requests: [HTTPRequest] = []
    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        let final = request.body?.range(of: Data("name=\"isFinish\"\r\n\r\n1\r\n".utf8)) != nil
        let response = final
            ? #"{"error_code":0,"picId":"fixture_gif","picInfo":{"originPic":{"width":12,"height":8}}}"#
            : #"{"error_code":0}"#
        return .init(statusCode: 200, body: Data(response.utf8))
    }
}
