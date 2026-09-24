import Foundation
import Testing
@testable import TiebaLite

struct R10ComposerMediaTests {
    @Test func cursorInsertionUsesUTF16AndRetainsSurroundingText() {
        let edit = ComposerInsertion.insert("#(滑稽)", into: "甲😀乙", selection: NSRange(location: 3, length: 0))
        #expect(edit.text == "甲😀#(滑稽)乙")
        #expect(edit.selection.location == 8)
    }

    @Test func uploadsRequireMatchingChunkAndFinalServerImage() throws {
        let partial = Data(#"{"error_code":"0","chunkNo":"1"}"#.utf8)
        #expect(try ImageUploadProtocol.decode(partial, chunk: 1, final: false) == nil)
        #expect(throws: ImageUploadFailure.self) { try ImageUploadProtocol.decode(partial, chunk: 1, final: true) }
        let final = Data(#"""
        {"error_code":"0","chunkNo":"2","picId":"fixture_pic","picInfo":{"originPic":{"width":"640","height":"480"}}}
        """#.utf8)
        #expect(try ImageUploadProtocol.decode(final, chunk: 2, final: true)?.token == "#(pic,fixture_pic,640,480)")
        #expect(throws: ImageUploadFailure.self) { try ImageUploadProtocol.decode(final, chunk: 1, final: true) }
    }
}

@MainActor
struct R10ComposerStateTests {
    private let context = AuthContext.active(.init(sessionID: .init(rawValue: 10), generation: 1))
    private let target = TextComposeTarget(kind: .threadReply, forumID: 10, forumName: "样本", threadID: 101)

    @Test func failureRetainsPhotosRetrySkipsUploadedAndPublishesOrderedTokensOnce() async {
        let uploader = R10ControlledUploader()
        let writer = R10Writer()
        let store = TextComposerStore(target: target, repository: writer, context: context,
                                      currentContext: { self.context }, uploader: uploader)
        store.draft.content = "正文#(滑稽)"
        store.appendPhoto(R10TestPhotos.photo("one"))
        store.appendPhoto(R10TestPhotos.photo("two"))
        await store.send()
        #expect(store.mediaFailure != nil)
        #expect(store.draft.photos.map(\.id) == ["one", "two"])
        #expect(store.draft.content == "正文#(滑稽)")
        #expect(await writer.requests.isEmpty)
        await store.send()
        #expect(await uploader.calls == ["one", "two", "two"])
        let requests = await writer.requests
        #expect(requests.count == 1)
        #expect(requests.first?.draft.content == "正文#(滑稽)\n#(pic,one,640,480)\n#(pic,two,640,480)")
        #expect(requests.first?.draft.photos.isEmpty == true)
        await store.send()
        #expect(await writer.requests.count == 1)
    }

    @Test func selectionLimitDeletionOrderAndDraftRestoration() {
        let store = TextComposerStore(target: target, repository: R10Writer(), context: context,
                                      currentContext: { self.context })
        for number in 1...11 { store.appendPhoto(R10TestPhotos.photo(String(number))) }
        #expect(store.draft.photos.count == 9)
        #expect(store.canSend)
        store.appendPhoto(R10TestPhotos.photo("1"))
        store.removePhoto(id: "3")
        #expect(store.draft.photos.map(\.id) == ["1", "2", "4", "5", "6", "7", "8", "9"])
        let drafts = TextComposerDrafts()
        drafts.save(store.draft, target: target, context: context)
        #expect(drafts.load(target: target, context: context).photos == store.draft.photos)
        #expect(drafts.load(target: target, context: .anonymous).photos.isEmpty)
    }

    @Test func cancelAndChangedAccountDuringUploadNeverPublish() async throws {
        for cancel in [true, false] {
            let uploader = R10PausedUploader()
            let writer = R10Writer()
            var active = context
            let store = TextComposerStore(target: target, repository: writer, context: context,
                                          currentContext: { active }, uploader: uploader)
            store.appendPhoto(R10TestPhotos.photo("one"))
            let task = Task { await store.send() }
            try await uploader.started.wait()
            await store.send()
            #expect(store.isSending)
            if cancel { store.cancelPending() } else { active = .anonymous }
            uploader.finished.succeed(())
            await task.value
            #expect(await writer.requests.isEmpty)
            #expect(store.draft.photos.count == 1)
            #expect(store.draft.photos.first?.uploaded == nil)
        }
    }

    @Test func localPreviewUsesExistingLoaderCacheWithoutNetwork() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("r10-loader-photo.png")
        let data = try TestImageFixtureFactory.png(width: 1_200, height: 800)
        try data.write(to: url)
        let transport = HarnessImageDataLoader(outcomes: [:])
        let loader = ProductionImageLoader(loader: transport)
        let photo = ComposerPhoto(id: "local-preview", file: .init(url: url), width: 1_200, height: 800, byteCount: data.count)
        let first = try await loader.loadLocalPhoto(photo)
        try FileManager.default.removeItem(at: url)
        let second = try await loader.loadLocalPhoto(photo)
        #expect(first.pixelSize == .init(width: 240, height: 240))
        #expect(second.decodedImage === first.decodedImage)
        #expect(await transport.recordedRequests().isEmpty)
    }
}

private enum R10TestPhotos {
    static func photo(_ id: String) -> ComposerPhoto {
        .init(id: id, file: .init(url: FileManager.default.temporaryDirectory.appendingPathComponent("r10-unused-" + id)),
              width: 640, height: 480, byteCount: 1)
    }
}
private actor R10Writer: TextWriteRepository {
    private(set) var requests: [TextWriteRequest] = []
    func send(_ request: TextWriteRequest, context: AuthContext) async throws -> TextWriteReceipt {
        requests.append(request)
        return .init(threadID: 101, postID: 202)
    }
}
private actor R10ControlledUploader: ComposerImageUploading {
    private(set) var calls: [String] = []
    func upload(_ photo: ComposerPhoto, forumName: String, context: AuthContext,
                progress: @escaping @Sendable (Double) async -> Void) async throws -> UploadedComposerPhoto {
        calls.append(photo.id)
        await progress(0.5)
        if calls.count == 2 { throw ImageUploadFailure.unavailable }
        return .init(picID: photo.id, width: 640, height: 480)
    }
}
private actor R10PausedUploader: ComposerImageUploading {
    nonisolated let started = HarnessContinuationGate<Void>()
    nonisolated let finished = HarnessContinuationGate<Void>()
    func upload(_ photo: ComposerPhoto, forumName: String, context: AuthContext,
                progress: @escaping @Sendable (Double) async -> Void) async throws -> UploadedComposerPhoto {
        started.succeed(())
        try await finished.wait()
        return .init(picID: photo.id, width: 640, height: 480)
    }
}
