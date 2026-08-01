import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

@Suite("Thread content Proto mapper")
struct ThreadContentProtoMapperTests {
    @Test
    func crossLanguageFixtureLoadsDecodesAndMapsInWireOrder() throws {
        let document = try mapFixture()

        #expect(document.source.threadID == 81_001)
        #expect(document.source.postID == 82_001)
        #expect(document.source.scope == .firstPost)
        #expect(document.availability == .available)
        #expect(document.nodes.map(\.rawType) == [
            0, 9, 27, 35, 40, 1, 1, 2, 3, 3, 3, 4, 4, 5, 5, 5,
            10, 20, 999, 999, 0, 0
        ])
        #expect(document.nodes.map(\.id.ordinal) == Array(0..<22))
        #expect(document.poll?.options.count == 2)
    }

    @Test(arguments: [Int32(0), 9, 27, 35, 40])
    func everyTextLikeRawValueRetainsItsOwnBoundary(rawType: Int32) throws {
        let document = try map(nodes: [content(type: rawType, text: "value")])

        #expect(document.nodes.count == 1)
        #expect(document.nodes[0].rawType == rawType)
        #expect(document.nodes[0].payload == .text(
            ThreadTextContent(value: "value")
        ))
    }

    @Test
    func adjacentTextLikeNodesAreNeverMergedOrDropped() throws {
        let document = try map(nodes: [
            content(type: 0, text: "first"),
            content(type: 9, text: "second"),
            content(type: 27, text: "third")
        ])

        #expect(document.nodes.count == 3)
        #expect(document.nodes.map(\.rawType) == [0, 9, 27])
        #expect(document.nodes.map(\.id.ordinal) == [0, 1, 2])
    }

    @Test
    func linksSeparateLabelFromValidatedTargetAndRejectUnsafeSchemes() throws {
        var safe = content(type: 1, text: "safe")
        safe.link = "https://fixture.invalid/safe"
        var http = content(type: 1, text: "http")
        http.link = "http://fixture.invalid/http"
        var unsafe = content(type: 1, text: "blocked")
        unsafe.link = "javascript:fixture()"
        var relative = content(type: 1, text: "relative")
        relative.link = "/not-absolute"

        let document = try map(nodes: [safe, http, unsafe, relative])
        let first = try #require(document.nodes[0].payload.link)
        let second = try #require(document.nodes[1].payload.link)
        let third = try #require(document.nodes[2].payload.link)
        let fourth = try #require(document.nodes[3].payload.link)

        #expect(first.label == "safe")
        #expect(first.intent?.destination.absoluteString ==
            "https://fixture.invalid/safe")
        #expect(second.intent?.destination.scheme == .http)
        #expect(third.label == "blocked")
        #expect(third.intent == nil)
        #expect(third.rejection == .unsupportedScheme)
        #expect(fourth.intent == nil)
        #expect(fourth.rejection == .notAbsolute)
    }

    @Test
    func emojiUsesReadableFallbackWithoutGuessingAResource() throws {
        var node = content(type: 2, text: "registry-key")
        node.c = "synthetic_smile"

        let mapped = try #require(map(nodes: [node]).nodes[0].payload.emoji)

        #expect(mapped.registryKey == "registry-key")
        #expect(mapped.code == "synthetic_smile")
        #expect(mapped.fallbackText == "#(synthetic_smile)")
    }

    @Test
    func imageCandidatesStayOrderedHTTPSOnlyAndDimensionsAreBounded() throws {
        var valid = content(type: 3)
        valid.originSrc = "https://fixture.invalid/origin.jpg"
        valid.bigCdnSrc = "https://fixture.invalid/big-cdn.jpg"
        valid.bigSrc = "http://fixture.invalid/rejected.jpg"
        valid.dynamic = "https://fixture.invalid/dynamic.jpg"
        valid.cdnSrc = "not a url"
        valid.cdnSrcActive = "https://fixture.invalid/active.jpg"
        valid.src = "https://fixture.invalid/source.jpg"
        valid.bsize = "640,480"
        valid.originSize = 4_096
        valid.showOriginalBtn = 1

        var malformed = content(type: 3)
        malformed.src = "javascript:fixture()"
        malformed.bsize = "999999999999999999999999,0"

        let document = try map(nodes: [valid, malformed])
        let first = try #require(document.nodes[0].payload.image)
        let second = try #require(document.nodes[1].payload.image)

        #expect(first.request.candidates.map(\.role) == [
            .original, .bigCDN, .dynamic, .activeCDN, .source
        ])
        #expect(first.dimensions == .known(width: 640, height: 480))
        #expect(first.dimensions.layoutAspectRatio == 4.0 / 3.0)
        #expect(first.showsOriginalControlHint)
        #expect(first.originalByteCount == 4_096)
        #expect(second.request.candidates.isEmpty)
        #expect(second.dimensions == .fallback(.outOfRange))
    }

    @Test
    func mentionKeepsLabelButEmitsNoIntentForDefaultOrInvalidID() throws {
        var valid = content(type: 4, text: "@valid")
        valid.uid = 7_301
        let missing = content(type: 4, text: "@missing")
        var negative = content(type: 4, text: "@negative")
        negative.uid = -1

        let document = try map(nodes: [valid, missing, negative])
        let mentions = try document.nodes.map { node in
            try #require(node.payload.mention)
        }

        #expect(mentions.map(\.userID) == [7_301, nil, nil])
        #expect(mentions.map(\.label) == ["@valid", "@missing", "@negative"])
    }

    @Test
    func allThreeVideoBranchesDegradeWithoutStartingPlayback() throws {
        var player = content(type: 5, text: "https://fixture.invalid/web")
        player.link = "https://fixture.invalid/video.mp4"
        player.src = "https://fixture.invalid/thumb.jpg"
        player.bsize = "1280,720"

        let textLink = content(type: 5, text: "https://fixture.invalid/fallback")

        var thumbnailLink = content(
            type: 5,
            text: "https://fixture.invalid/thumbnail-link"
        )
        thumbnailLink.src = "https://fixture.invalid/thumb-only.jpg"
        thumbnailLink.bsize = "640,360"

        let document = try map(nodes: [player, textLink, thumbnailLink])
        let first = try #require(document.nodes[0].payload.video)
        let second = try #require(document.nodes[1].payload.video)
        let third = try #require(document.nodes[2].payload.video)

        #expect(first.hasThumbnail)
        #expect(first.videoTarget?.absoluteString ==
            "https://fixture.invalid/video.mp4")
        #expect(first.externalIntent?.destination.absoluteString ==
            "https://fixture.invalid/web")
        #expect(!second.hasThumbnail)
        #expect(second.videoTarget == nil)
        #expect(second.externalIntent?.destination.absoluteString ==
            "https://fixture.invalid/fallback")
        #expect(third.hasThumbnail)
        #expect(third.videoTarget == nil)
        #expect(third.externalIntent?.destination.absoluteString ==
            "https://fixture.invalid/thumbnail-link")
    }

    @Test
    func voiceAndAlternateImageRemainSafeDegradedValues() throws {
        var voice = content(type: 10)
        voice.voiceMd5 = "synthetic-resource"
        voice.duringTime = 17
        var alternate = content(type: 20)
        alternate.src = "https://fixture.invalid/alternate.jpg"
        alternate.bsize = "320,240"

        let document = try map(nodes: [voice, alternate])
        let mappedVoice = try #require(document.nodes[0].payload.voice)
        let mappedImage = try #require(document.nodes[1].payload.image)

        #expect(mappedVoice.resourceID == "synthetic-resource")
        #expect(mappedVoice.durationSeconds == 17)
        #expect(mappedImage.rawType == 20)
        #expect(mappedImage.request.candidates.map(\.role) == [.source])
    }

    @Test
    func unknownAndMemeNodesBecomeSafePlaceholdersWithoutDroppingLaterText() throws {
        var unknown = content(type: 999, text: "private body")
        unknown.link = "private:target"
        var meme = Tieba_MemeInfo()
        meme.pckID = 88
        meme.picID = 9_901
        var unknownMeme = content(type: 999)
        unknownMeme.memeInfo = meme

        let document = try map(nodes: [
            content(type: 0, text: "before"),
            unknown,
            unknownMeme,
            content(type: 0, text: "after")
        ])

        #expect(document.nodes.count == 4)
        #expect(document.nodes.map(\.id.ordinal) == [0, 1, 2, 3])
        let firstUnknown = try #require(document.nodes[1].payload.unsupported)
        let secondUnknown = try #require(document.nodes[2].payload.unsupported)
        #expect(firstUnknown.rawType == 999)
        #expect(firstUnknown.presentFields == [.text, .link])
        #expect(firstUnknown.safeDiagnostic == "raw-type:999 fields:link,text")
        #expect(!firstUnknown.safeDiagnostic.contains("private body"))
        #expect(secondUnknown.presentFields == [.memeInfo])
        #expect(document.nodes[3].payload == .text(
            ThreadTextContent(value: "after")
        ))
    }

    @Test
    func pollPresenceAndZeroTotalAreReadOnlyAndNeverDivideByZero() throws {
        var poll = Tieba_PollInfo()
        poll.type = 999
        poll.isMulti = 1
        poll.isPolled = 1
        poll.polledValue = "2"
        poll.title = "Synthetic poll"
        poll.tips = "Read only"
        poll.totalNum = 8
        poll.totalPoll = 0
        poll.status = 999
        var option = Tieba_PollOption()
        option.id = 2
        option.num = 5
        option.text = "Option"
        option.image = "https://fixture.invalid/option.png"
        poll.options = [option]

        let document = try map(nodes: [], poll: poll)
        let mapped = try #require(document.poll)
        let mappedOption = try #require(mapped.options.first)

        #expect(mapped.mode == .multiple)
        #expect(mapped.rawType == 999)
        #expect(mapped.rawStatus == 999)
        #expect(mapped.isPolled)
        #expect(mappedOption.voteRatio == nil)
        #expect(mappedOption.imageWasPresent)
        #expect(mapped.isReadOnly)
    }

    @Test
    func emptyLongAndMalformedNodesHaveDeterministicResults() throws {
        let veryLong = String(repeating: "Synthetic body ", count: 2_000)
        var malformedImage = content(type: 3)
        malformedImage.bsize = "broken"

        let document = try map(nodes: [
            content(type: 0),
            malformedImage,
            content(type: 0, text: veryLong)
        ])

        #expect(document.nodes.count == 3)
        #expect(!document.isVisiblyEmpty)
        #expect(document.nodes[0].payload.text?.value.isEmpty == true)
        #expect(document.nodes[1].payload.image?.dimensions ==
            .fallback(.malformed))
        #expect(document.nodes[2].payload.text?.value == veryLong)

        let empty = try map(nodes: [])
        #expect(empty.isVisiblyEmpty)
    }

    @Test
    func deletionFlagDegradesAvailabilityButRetainsDeterministicMapping() throws {
        var thread = baseThread()
        thread.isDeleted = 7
        thread.firstPostContent = [content(type: 0, text: "retained")]

        let document = try ThreadContentProtoMapper.map(
            serializedThreadInfo: try thread.serializedData()
        )

        #expect(document.availability == .unavailable(
            .deletedFirstPost(rawFlag: 7)
        ))
        #expect(document.nodes.count == 1)
    }

    @Test
    func stableIdentityAndRepeatedMappingAreDeterministic() throws {
        let bytes = try fixtureData()
        let first = try ThreadContentProtoMapper.map(
            serializedThreadInfo: bytes
        )
        let second = try ThreadContentProtoMapper.map(
            serializedThreadInfo: bytes
        )

        #expect(first == second)
        #expect(first.nodes.map(\.id.stableKey) == second.nodes.map(\.id.stableKey))
        #expect(Set(first.nodes.map(\.id)).count == first.nodes.count)
    }

    @Test
    func emptyAndMalformedWireBodiesReturnTypedErrors() {
        #expect(throws: ThreadContentMappingError.emptyBody) {
            try ThreadContentProtoMapper.map(serializedThreadInfo: Data())
        }
        #expect(throws: ThreadContentMappingError.malformedWire) {
            try ThreadContentProtoMapper.map(
                serializedThreadInfo: Data([0x12, 0x05, 0x0A])
            )
        }
    }

    @Test
    func mediaIntentUsesStableDocumentOrderAndSelectedBusinessID() throws {
        var first = content(type: 3)
        first.src = "https://fixture.invalid/one.jpg"
        first.bsize = "400,300"
        var second = content(type: 20)
        second.src = "https://fixture.invalid/two.jpg"
        second.bsize = "400,300"
        let document = try map(nodes: [first, content(type: 0), second])
        let selected = try #require(document.nodes[2].payload.image?.mediaID)

        let intent = try #require(document.mediaIntent(selecting: selected))

        #expect(intent.initialMediaID == selected)
        #expect(intent.items.map(\.mediaID) == [
            document.nodes[0].payload.image?.mediaID,
            document.nodes[2].payload.image?.mediaID
        ])
        #expect(intent.items.map(\.sourceNodeID.ordinal) == [0, 2])
    }

    private func mapFixture() throws -> ThreadContentDocument {
        try ThreadContentProtoMapper.map(serializedThreadInfo: fixtureData())
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: FixtureBundleMarker.self)
        let root = try #require(
            bundle.url(forResource: "Fixtures", withExtension: nil)
        )
        return try FixtureLoader(rootDirectory: root).loadData(
            id: FixtureID("thread-content.first-post.cross-language"),
            expectedFormat: .protobuf
        )
    }

    private func map(
        nodes: [Tieba_PbContent],
        poll: Tieba_PollInfo? = nil
    ) throws -> ThreadContentDocument {
        var thread = baseThread()
        thread.firstPostContent = nodes
        if let poll {
            thread.pollInfo = poll
        }
        return try ThreadContentProtoMapper.map(
            serializedThreadInfo: thread.serializedData()
        )
    }

    private func baseThread() -> Tieba_ThreadInfo {
        var thread = Tieba_ThreadInfo()
        thread.id = 81_001
        thread.threadID = 81_001
        thread.firstPostID = 82_001
        return thread
    }

    private func content(
        type: Int32,
        text: String = ""
    ) -> Tieba_PbContent {
        var content = Tieba_PbContent()
        content.type = type
        content.text = text
        return content
    }
}

@Suite("Thread content renderer contracts")
struct ThreadContentRendererContractTests {
    @Test
    @MainActor
    func injectedImageLoaderSeparatesRenderedAndFetchFailure() async throws {
        let request = fixtureImageRequest(
            resourceID: DebugThreadContentRendererFixtures.loadedImageResourceID
        )

        let rendered = try await ThreadContentImageLoad.resolve(
            request,
            using: HarnessRendererImageLoader()
        )
        let failed = try await ThreadContentImageLoad.resolve(
            request,
            using: ImmediateImageLoader(
                result: .failure(ImageLoadingError.unavailable)
            )
        )

        #expect(rendered.phase == .rendered)
        #expect(failed.phase == .failedToFetch)
    }

    @Test
    @MainActor
    func imageRequestWithoutSafeCandidatesFailsBeforeCallingTheLoader() async throws {
        let renderState = try await ThreadContentImageLoad.resolve(
            ThreadImageRequestDescriptor(
                resourceID: "fixture.invalid-image",
                candidates: []
            ),
            using: UnexpectedImageLoader()
        )

        #expect(renderState.phase == .failedToFetch)
    }

    @Test
    @MainActor
    func imageLoadCancellationIsNotDisplayedAsFailure() async throws {
        let loader = BlockingImageLoader()
        let task = Task {
            try await ThreadContentImageLoad.resolve(
                fixtureImageRequest(),
                using: loader
            )
        }
        try await loader.waitUntilStarted()

        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected image load cancellation")
        } catch is CancellationError {
            #expect(true)
        } catch {
            Issue.record("Cancellation changed into an image failure")
        }
    }

    @Test(arguments: [
        ThreadContentImagePhase.idle,
        ThreadContentImagePhase.loading,
        .rendered,
        .failedToFetch,
        .failedToDecode,
        .cancelled
    ])
    func loadingSuccessAndFailureUseTheSameLayoutRatio(
        phase: ThreadContentImagePhase
    ) {
        let dimensions = ThreadMediaDimensions.known(width: 640, height: 480)

        #expect(
            ThreadContentImagePresentation.layoutAspectRatio(
                dimensions: dimensions,
                phase: phase
            ) == 4.0 / 3.0
        )
    }

    @Test
    func extremeMediaRatiosClampToReadableStableLayoutBounds() {
        let wide = ThreadMediaDimensions.known(width: 1_000, height: 100)
        let tall = ThreadMediaDimensions.known(width: 100, height: 1_000)

        #expect(ThreadContentImagePresentation.layoutAspectRatio(
            dimensions: wide,
            phase: .loading
        ) == ThreadContentImagePresentation.maximumLayoutAspectRatio)
        #expect(ThreadContentImagePresentation.layoutAspectRatio(
            dimensions: tall,
            phase: .failedToFetch
        ) == ThreadContentImagePresentation.minimumLayoutAspectRatio)
    }

    @Test
    func imageTaskIdentityChangesWhenCandidateRequestChanges() {
        let first = ThreadImageRequestDescriptor(
            resourceID: "fixture.image",
            candidates: [ThreadImageCandidate(
                role: .source,
                destination: ValidatedWebDestination(
                    absoluteString: "https://fixture.invalid/one.png",
                    scheme: .https
                )
            )]
        )
        let second = ThreadImageRequestDescriptor(
            resourceID: "fixture.image",
            candidates: [ThreadImageCandidate(
                role: .source,
                destination: ValidatedWebDestination(
                    absoluteString: "https://fixture.invalid/two.png",
                    scheme: .https
                )
            )]
        )

        #expect(first != second)
    }

    private func fixtureImageRequest(
        resourceID: String = "fixture.image"
    ) -> ThreadImageRequestDescriptor {
        ThreadImageRequestDescriptor(
            resourceID: resourceID,
            candidates: [ThreadImageCandidate(
                role: .source,
                destination: ValidatedWebDestination(
                    absoluteString: "https://fixture.invalid/image.png",
                    scheme: .https
                )
            )]
        )
    }
}

private struct UnexpectedImageLoader: ImageLoading {
    func load(_ request: ImageRequest) async throws -> ImagePayload {
        _ = request
        Issue.record("Invalid image request reached the injected loader")
        throw ImageLoadingError.unavailable
    }
}

private struct ImmediateImageLoader: ImageLoading {
    let result: Result<ImagePayload, any Error>

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        _ = request
        return try result.get()
    }
}

private final class BlockingImageLoader: ImageLoading, Sendable {
    private let started = HarnessContinuationGate<Void>()
    private let response = HarnessContinuationGate<ImagePayload>()

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        _ = request
        started.succeed(())
        return try await withTaskCancellationHandler {
            try await response.wait()
        } onCancel: {
            response.cancel()
        }
    }

    func waitUntilStarted() async throws {
        try await started.wait()
    }
}

private extension ThreadContentPayload {
    var text: ThreadTextContent? {
        if case let .text(value) = self { value } else { nil }
    }

    var link: ThreadLinkContent? {
        if case let .link(value) = self { value } else { nil }
    }

    var emoji: ThreadEmojiContent? {
        if case let .emoji(value) = self { value } else { nil }
    }

    var image: ThreadImageContent? {
        if case let .image(value) = self { value } else { nil }
    }

    var mention: ThreadMentionContent? {
        if case let .mention(value) = self { value } else { nil }
    }

    var video: ThreadVideoContent? {
        if case let .video(value) = self { value } else { nil }
    }

    var voice: ThreadVoiceContent? {
        if case let .voice(value) = self { value } else { nil }
    }

    var unsupported: ThreadUnsupportedContent? {
        if case let .unsupported(value) = self { value } else { nil }
    }
}
