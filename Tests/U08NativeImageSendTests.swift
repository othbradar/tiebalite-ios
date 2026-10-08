import CryptoKit
import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

@MainActor
struct U08NativeImageSendTests {
    @Test func serialChunksAndPhotosProduceOneReplyWithServerTokens() async throws {
        let setup = try makeSetup()
        let first = try photo("serial-first", count: NativeImageUploadProtocol.chunkSize + 13)
        setup.store.draft.photos = [first, try photo("serial-second", count: 25)]
        let task = Task { await setup.store.send() }
        try await login(setup.http)
        for (index, final) in [false, true, true].enumerated() {
            let upload = try await next(setup.http)
            #expect(upload.request.url.path == "/c/s/uploadPicture" && upload.request.url.query == nil)
            let body = try #require(upload.request.body)
            #expect(body.range(of: Data("name=\"chunkNo\"\r\n\r\n\(index == 1 ? 2 : 1)\r\n".utf8)) != nil)
            #expect(body.range(of: Data("name=\"isFinish\"\r\n\r\n\(final ? 1 : 0)\r\n".utf8)) != nil)
            if index < 2 { #expect(body.range(of: Data(first.id.uppercased().utf8)) != nil) }
            #expect(body.range(of: Data("groupId".utf8)) == nil && body.range(of: Data("Android".utf8)) == nil)
            await setup.store.send() // Repeated taps cannot create an upload or write.
            try await setup.http.succeed(upload.id, with: final ? response(index == 1 ? "first" : "second") : partial)
        }
        let write = try await next(setup.http)
        let post = try TiebaNativeWrite_PostRequest(serializedBytes: proto(write.request)).data
        #expect(post.content == "Fixture image\n#(pic,first,320,240)\n#(pic,second,320,240)")
        #expect(post.common.clientType == 1 && post.tid == "101")
        try await setup.http.succeed(write.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        await task.value
        #expect(setup.store.receipt != nil && setup.store.failure == nil && setup.store.mediaFailure == nil)
        #expect(await starts(setup.http) == 5) // Account, three chunks, one final reply.
    }

    @Test func uploadFailureRetainsDraftAndManualRetryReusesOnlyCompletedNativePhoto() async throws {
        let setup = try makeSetup()
        setup.store.draft.photos = [try photo("retry-one", count: 20), try photo("retry-two", count: 21)]
        let task = Task { await setup.store.send() }
        try await login(setup.http)
        let first = try await next(setup.http)
        try await setup.http.succeed(first.id, with: response("first"))
        let second = try await next(setup.http)
        try await setup.http.succeed(second.id, with: .init(statusCode: 200, body: Data(#"{"error_code":4}"#.utf8)))
        await task.value
        #expect(setup.store.receipt == nil && setup.store.mediaFailure != nil)
        #expect(setup.store.draft.content == "Fixture image" && setup.store.draft.photos.count == 2)
        #expect(setup.store.draft.photos.first?.uploaded?.source == NativeImageUploadProtocol.receiptSource)
        #expect(setup.store.draft.photos.last?.uploaded == nil)
        #expect(await setup.http.pendingCalls().isEmpty)
        let retry = Task { await setup.store.send() }
        let retriedImage = try await next(setup.http)
        #expect(retriedImage.request.url.path == "/c/s/uploadPicture")
        try await setup.http.succeed(retriedImage.id, with: response("second"))
        let write = try await next(setup.http)
        #expect(try TiebaNativeWrite_PostRequest(serializedBytes: proto(write.request)).data.content ==
            "Fixture image\n#(pic,first,320,240)\n#(pic,second,320,240)")
        try await setup.http.succeed(write.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        await retry.value
        #expect(setup.store.receipt != nil)
        #expect(await starts(setup.http) == 5)
    }

    @Test func cancellationAndAccountChangeDuringUploadCannotPublishOrCacheReceipt() async throws {
        for cancel in [true, false] {
            let setup = try makeSetup()
            setup.store.draft.photos = [try photo("cancel-\(cancel)", count: 30)]
            let task = Task { await setup.store.send() }
            try await login(setup.http)
            let upload = try await next(setup.http)
            if cancel {
                setup.store.cancelPending()
            } else {
                setup.auth.install(try #require(SessionCredential(bduss: "other", stoken: "other")))
                try await setup.http.succeed(upload.id, with: response("obsolete"))
            }
            await task.value
            #expect(setup.store.receipt == nil && setup.store.draft.photos.first?.uploaded == nil)
            #expect(setup.store.draft.content == "Fixture image")
            #expect(await setup.http.pendingCalls().isEmpty)
            #expect(await starts(setup.http) == 2)
        }
    }

    @Test func finalMissingImageAndChangedFileNeverPublish() async throws {
        for changedFile in [true, false] {
            let setup = try makeSetup()
            let image = try photo("changed-\(changedFile)", count: 40)
            setup.store.draft.photos = [image]
            if changedFile { try Data(repeating: 1, count: 40).write(to: image.file.url) }
            let task = Task { await setup.store.send() }
            try await login(setup.http)
            if !changedFile {
                let upload = try await next(setup.http)
                try await setup.http.succeed(upload.id, with: partial)
            }
            await task.value
            #expect(setup.store.receipt == nil && setup.store.mediaFailure != nil)
            #expect(setup.store.draft.photos.count == 1)
            #expect(await setup.http.pendingCalls().isEmpty)
            #expect(await starts(setup.http) == (changedFile ? 1 : 2))
        }
    }

    @Test func newThreadFloorAndSubpostKeepTheirNativeDestinationWithImages() async throws {
        for kind in [TextComposeTarget.Kind.thread, .floorReply, .subpostReply] {
            let setup = try makeSetup(kind: kind)
            setup.store.draft.photos = [try photo("target-\(kind.rawValue)", count: 33)]
            let task = Task { await setup.store.send() }
            try await login(setup.http)
            let upload = try await next(setup.http)
            try await setup.http.succeed(upload.id, with: response("target"))
            let write = try await next(setup.http)
            let token = "#(pic,target,320,240)"
            if kind == .thread {
                #expect(write.request.url.path == "/c/c/thread/add")
                #expect(try TiebaNativeWrite_ThreadRequest(serializedBytes: proto(write.request)).data.content.contains(token))
            } else {
                #expect(write.request.url.path == "/c/c/post/add")
                let post = try TiebaNativeWrite_PostRequest(serializedBytes: proto(write.request)).data
                #expect(post.content.contains(token) && post.quoteID == "202" && post.repostid == "202")
                if kind == .subpostReply { #expect(post.subPostID == "303" && post.content.hasPrefix("回复 #(reply,")) }
            }
            try await setup.http.succeed(write.id, with: .init(
                statusCode: 200, body: NativeClientFixture.response(kind == .thread ? "thread-success" : "post-success")))
            await task.value
            #expect(setup.store.receipt != nil)
            #expect(await starts(setup.http) == 3)
        }
    }

    @Test func preparedJPEGUploadsTheImportedFileBytes() async throws {
        let input = FileManager.default.temporaryDirectory.appendingPathComponent("native-upload-import.png")
        try TestImageFixtureFactory.png(width: 640, height: 480).write(to: input)
        let image = try await ComposerPhotoPreparation().prepare(file: .init(url: input))
        let bytes = try Data(contentsOf: image.file.url)
        #expect(bytes.starts(with: [0xff, 0xd8, 0xff]) && image.width == 640 && image.height == 480)
        let setup = try makeSetup()
        setup.store.draft.photos = [image]
        let task = Task { await setup.store.send() }
        try await login(setup.http)
        let upload = try await next(setup.http)
        #expect(upload.request.body?.range(of: bytes) != nil)
        try await setup.http.succeed(upload.id, with: response("imported"))
        let write = try await next(setup.http)
        try await setup.http.succeed(write.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        await task.value
        #expect(setup.store.receipt != nil)
    }

    @Test func exactChunkBoundaryProducesOneNonemptyFinalChunk() async throws {
        let setup = try makeSetup()
        setup.store.draft.photos = [try photo("exact-boundary", count: NativeImageUploadProtocol.chunkSize)]
        let task = Task { await setup.store.send() }
        try await login(setup.http)
        let upload = try await next(setup.http)
        let body = try #require(upload.request.body)
        #expect(body.range(of: Data("name=\"isFinish\"\r\n\r\n1\r\n".utf8)) != nil)
        try await setup.http.succeed(upload.id, with: response("exact"))
        let write = try await next(setup.http)
        #expect(write.request.url.path == "/c/c/post/add")
        try await setup.http.succeed(write.id, with: .init(statusCode: 200, body: NativeClientFixture.response()))
        await task.value
        #expect(setup.store.receipt != nil)
        #expect(await starts(setup.http) == 3)
    }

    private struct Setup {
        let auth: SessionAuthContextProvider
        let http: HarnessMockHTTPClient
        let store: TextComposerStore
    }
    private func makeSetup(kind: TextComposeTarget.Kind = .threadReply) throws -> Setup {
        let fixture = try NativeClientFixture.load()
        let runtime = NativeClientFixtureRuntime(fixture: fixture, sample: try #require(fixture.cases.first))
        let auth = SessionAuthContextProvider()
        auth.install(try #require(SessionCredential(bduss: "fx", stoken: "fy")))
        let http = HarnessMockHTTPClient()
        let writer = NativeLiveTextWriteRepository(auth: auth, loader: NativeClientHarnessBridge(client: http), runtime: runtime,
                                                   firstLogin: { true }, didPrepareAccount: {})
        let store = TextComposerStore(target: R09WriteFixture.target(kind), repository: writer, context: auth.context(),
                                      currentContext: { auth.context() }, uploader: writer)
        store.draft = .init(title: "Fixture title", content: "Fixture image")
        return .init(auth: auth, http: http, store: store)
    }
    private func photo(_ name: String, count: Int) throws -> ComposerPhoto {
        // Transport-only synthetic bytes. Real ImageIO output is checked separately below.
        var data = Data([0xff, 0xd8, 0xff])
        data.append(Data(repeating: UInt8(count % 251), count: count - 3))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("native-upload-" + name + ".jpg")
        try data.write(to: url)
        return .init(id: Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                     file: .init(url: url), width: 640, height: 480, byteCount: count)
    }
    private var partial: HTTPResponse { .init(statusCode: 200, body: Data(#"{"error_code":0}"#.utf8)) }
    private func response(_ id: String) -> HTTPResponse {
        let json = "{\"error_code\":0,\"picId\":\"\(id)\",\"picInfo\":{\"originPic\":{\"width\":320,\"height\":240}}}"
        return .init(statusCode: 200, body: Data(json.utf8))
    }
    private func login(_ http: HarnessMockHTTPClient) async throws {
        let call = try await next(http)
        #expect(call.request.url.path == "/c/s/login")
        try await http.succeed(call.id, with: .init(statusCode: 200, body: Data(
            #"{"error_code":0,"user":{"id":"42","name":"Fixture"},"anti":{"tbs":"fixture-tbs"}}"#.utf8)))
    }
    private func next(_ http: HarnessMockHTTPClient) async throws -> HarnessPendingHTTPCall {
        try await http.waitForPendingCallCount(1)
        return try #require(await http.pendingCalls().first)
    }
    private func starts(_ http: HarnessMockHTTPClient) async -> Int {
        await http.events().filter { if case .started = $0 { return true }; return false }.count
    }
    private func proto(_ request: HTTPRequest) throws -> Data {
        let body = try #require(request.body)
        let start = try #require(body.range(of: Data("\r\n\r\n".utf8))).upperBound
        let contentType = try #require(request.headers.first { $0.key.lowercased() == "content-type" }?.value)
        let boundary = try #require(contentType.components(separatedBy: "boundary=").last)
        let end = try #require(body.range(of: Data("\r\n--\(boundary)--\r\n".utf8))).lowerBound
        return body.subdata(in: start..<end)
    }
}
