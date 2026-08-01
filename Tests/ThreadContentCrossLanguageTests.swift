import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

@Suite("Thread content cross-language payload contract")
struct ThreadContentCrossLanguageTests {
    @Test
    func binaryFixtureMapsEveryPayloadFamilyEndToEnd() throws {
        let document = try mapFixture()
        try #require(document.nodes.count == 22)

        try verifyTextLinksAndEmoji(document)
        try verifyImagesAndMentions(document)
        try verifyVideoVoiceAndUnsupported(document)
        try verifyPoll(document)
    }

    @Test
    func imageDimensionFailuresRemainDistinctAndLocal() throws {
        let rawDimensions = [
            "",
            "broken",
            "0,480",
            "-1,480",
            "20000,480",
            "1000,1",
            "1,1000"
        ]
        let nodes = rawDimensions.map { rawValue -> Tieba_PbContent in
            var node = content(type: 3)
            node.src = "https://fixture.invalid/image.png"
            node.bsize = rawValue
            return node
        }

        let document = try map(nodes: nodes)

        #expect(document.nodes.compactMap { node in
            node.payload.fixtureImage?.dimensions
        } == [
            .fallback(.missing),
            .fallback(.malformed),
            .fallback(.nonPositive),
            .fallback(.nonPositive),
            .fallback(.outOfRange),
            .fallback(.extremeAspectRatio),
            .fallback(.extremeAspectRatio)
        ])
        #expect(document.nodes.map(\.id.ordinal) == Array(0..<rawDimensions.count))
    }

    @Test
    func emptyOptionalValuesAndUnsafeAlternateImageDegradeDeterministically() throws {
        let emptyLink = content(type: 1)
        let emptyEmoji = content(type: 2)
        let emptyMention = content(type: 4)
        let emptyVoice = content(type: 10)
        var maximumVoice = content(type: 10)
        maximumVoice.voiceMd5 = "synthetic-maximum-duration"
        maximumVoice.duringTime = .max
        var alternateImage = content(type: 20)
        alternateImage.src = "javascript:fixture()"
        alternateImage.bsize = "0,0"

        let document = try map(nodes: [
            emptyLink,
            emptyEmoji,
            emptyMention,
            emptyVoice,
            maximumVoice,
            alternateImage
        ])

        #expect(document.nodes[0].payload.fixtureLink?.rejection == .empty)
        #expect(document.nodes[0].payload.fixtureLink?.label.isEmpty == true)
        #expect(document.nodes[1].payload.fixtureEmoji?.fallbackText == "[表情]")
        #expect(document.nodes[2].payload.fixtureMention?.userID == nil)
        #expect(document.nodes[2].payload.fixtureMention?.label.isEmpty == true)
        #expect(document.nodes[3].payload.fixtureVoice?.resourceID == nil)
        #expect(document.nodes[3].payload.fixtureVoice?.durationSeconds == 0)
        #expect(document.nodes[4].payload.fixtureVoice?.durationSeconds == .max)
        #expect(document.nodes[5].payload.fixtureImage?.request.candidates.isEmpty == true)
        #expect(document.nodes[5].payload.fixtureImage?.dimensions ==
            .fallback(.nonPositive))

        let onlyEmptyText = try map(nodes: [content(type: 0)])
        #expect(onlyEmptyText.isVisiblyEmpty)
    }

    @Test
    func positivePollTotalMapsRatioWhileAbsentMessageStaysAbsent() throws {
        var poll = Tieba_PollInfo()
        poll.totalPoll = 12
        poll.totalNum = 7
        var option = Tieba_PollOption()
        option.id = 4
        option.num = 3
        option.text = "Synthetic ratio option"
        poll.options = [option]

        let present = try map(nodes: [], poll: poll)
        let absent = try map(nodes: [])

        #expect(present.poll?.options.first?.voteRatio == 0.25)
        #expect(present.poll?.isReadOnly == true)
        #expect(absent.poll == nil)
    }

    private func verifyTextLinksAndEmoji(
        _ document: ThreadContentDocument
    ) throws {
        #expect(document.nodes[0].payload.fixtureText?.value ==
            "Synthetic alpha\nSynthetic beta")
        #expect(document.nodes[1...4].compactMap { node in
            node.payload.fixtureText?.value
        } == [
            "Synthetic type 9",
            "Synthetic type 27",
            "Synthetic type 35",
            "Synthetic type 40"
        ])
        let safeLink = try #require(document.nodes[5].payload.fixtureLink)
        let blockedLink = try #require(document.nodes[6].payload.fixtureLink)
        #expect(safeLink.label == "Synthetic HTTPS link")
        #expect(safeLink.intent?.destination.absoluteString ==
            "https://fixture.invalid/thread/link")
        #expect(blockedLink.intent == nil)
        #expect(blockedLink.rejection == .unsupportedScheme)
        #expect(document.nodes[7].payload.fixtureEmoji == ThreadEmojiContent(
            registryKey: "synthetic-emoticon-key",
            code: "synthetic_smile"
        ))
    }

    private func verifyImagesAndMentions(
        _ document: ThreadContentDocument
    ) throws {
        let image = try #require(document.nodes[8].payload.fixtureImage)
        let malformed = try #require(document.nodes[9].payload.fixtureImage)
        let missing = try #require(document.nodes[10].payload.fixtureImage)
        #expect(image.request.candidates.map(\.role) == [
            .original,
            .bigCDN,
            .big,
            .dynamic,
            .cdn,
            .activeCDN,
            .source
        ])
        #expect(image.request.candidates.map(\.destination.absoluteString) == [
            "https://fixture.invalid/media/original.jpg",
            "https://fixture.invalid/media/big-cdn.jpg",
            "https://fixture.invalid/media/big.jpg",
            "https://fixture.invalid/media/dynamic.jpg",
            "https://fixture.invalid/media/cdn.jpg",
            "https://fixture.invalid/media/active.jpg",
            "https://fixture.invalid/media/source.jpg"
        ])
        #expect(image.dimensions == .known(width: 640, height: 480))
        #expect(image.alternativeText == "图片")
        #expect(image.originalByteCount == 4_096)
        #expect(image.showsOriginalControlHint)
        #expect(malformed.request.candidates.isEmpty)
        #expect(malformed.dimensions == .fallback(.outOfRange))
        #expect(missing.request.candidates.isEmpty)
        #expect(missing.dimensions == .fallback(.missing))
        #expect(document.nodes[11].payload.fixtureMention == ThreadMentionContent(
            userID: 7_301,
            label: "@SyntheticMember"
        ))
        #expect(document.nodes[12].payload.fixtureMention?.userID == nil)
    }

    private func verifyVideoVoiceAndUnsupported(
        _ document: ThreadContentDocument
    ) throws {
        let player = try #require(document.nodes[13].payload.fixtureVideo)
        let fallback = try #require(document.nodes[14].payload.fixtureVideo)
        let thumbnail = try #require(document.nodes[15].payload.fixtureVideo)
        #expect(player.hasThumbnail)
        #expect(player.videoTarget?.absoluteString ==
            "https://fixture.invalid/video/file.mp4")
        #expect(player.externalIntent?.destination.absoluteString ==
            "https://fixture.invalid/video/web")
        #expect(player.thumbnail?.candidates.first?.destination.absoluteString ==
            "https://fixture.invalid/video/thumbnail.jpg")
        #expect(!fallback.hasThumbnail)
        #expect(fallback.videoTarget == nil)
        #expect(fallback.externalIntent?.destination.absoluteString ==
            "https://fixture.invalid/video/fallback")
        #expect(thumbnail.hasThumbnail)
        #expect(thumbnail.videoTarget == nil)
        #expect(thumbnail.thumbnail?.candidates.first?.destination.absoluteString ==
            "https://fixture.invalid/video/thumbnail-only.jpg")
        #expect(thumbnail.externalIntent?.destination.absoluteString ==
            "https://fixture.invalid/video/thumbnail-link")
        #expect(document.nodes[16].payload.fixtureVoice == ThreadVoiceContent(
            resourceID: "synthetic-voice-resource",
            durationSeconds: 17
        ))
        #expect(document.nodes[17].payload.fixtureImage?.rawType == 20)
        #expect(document.nodes[18].payload.fixtureUnsupported?.presentFields == [
            .text,
            .link
        ])
        #expect(document.nodes[19].payload.fixtureUnsupported?.presentFields == [
            .memeInfo
        ])
        #expect(document.nodes[20].payload.fixtureText?.value.isEmpty == true)
        #expect(document.nodes[21].payload.fixtureText?.value ==
            "Synthetic trailing text")
    }

    private func verifyPoll(_ document: ThreadContentDocument) throws {
        let poll = try #require(document.poll)
        #expect(poll.rawType == 999)
        #expect(poll.mode == .multiple)
        #expect(poll.title == "Synthetic poll")
        #expect(poll.tips == "Synthetic read-only poll")
        #expect(poll.totalParticipants == 8)
        #expect(poll.totalVotes == 0)
        #expect(poll.isPolled)
        #expect(poll.polledValue == "2")
        #expect(poll.endTime == 1_700_000_000)
        #expect(poll.rawStatus == 999)
        #expect(poll.lastTime == 120)
        #expect(poll.options.map(\.rawOptionID) == [1, 2])
        #expect(poll.options.map(\.text) == [
            "Synthetic option A",
            "Synthetic option B"
        ])
        #expect(poll.options.map(\.voteCount) == [3, 5])
        #expect(poll.options.map(\.imageWasPresent) == [false, true])
        #expect(poll.options.allSatisfy { $0.voteRatio == nil })
    }

    private func mapFixture() throws -> ThreadContentDocument {
        let bundle = Bundle(for: FixtureBundleMarker.self)
        let root = try #require(
            bundle.url(forResource: "Fixtures", withExtension: nil)
        )
        let data = try FixtureLoader(rootDirectory: root).loadData(
            id: FixtureID("thread-content.first-post.cross-language"),
            expectedFormat: .protobuf
        )
        return try ThreadContentProtoMapper.map(serializedThreadInfo: data)
    }

    private func map(
        nodes: [Tieba_PbContent],
        poll: Tieba_PollInfo? = nil
    ) throws -> ThreadContentDocument {
        var thread = Tieba_ThreadInfo()
        thread.id = 81_001
        thread.threadID = 81_001
        thread.firstPostID = 82_001
        thread.firstPostContent = nodes
        if let poll {
            thread.pollInfo = poll
        }
        return try ThreadContentProtoMapper.map(
            serializedThreadInfo: thread.serializedData()
        )
    }

    private func content(
        type: Int32,
        text: String = ""
    ) -> Tieba_PbContent {
        var node = Tieba_PbContent()
        node.type = type
        node.text = text
        return node
    }
}

private extension ThreadContentPayload {
    var fixtureText: ThreadTextContent? {
        if case let .text(value) = self { value } else { nil }
    }

    var fixtureLink: ThreadLinkContent? {
        if case let .link(value) = self { value } else { nil }
    }

    var fixtureEmoji: ThreadEmojiContent? {
        if case let .emoji(value) = self { value } else { nil }
    }

    var fixtureImage: ThreadImageContent? {
        if case let .image(value) = self { value } else { nil }
    }

    var fixtureMention: ThreadMentionContent? {
        if case let .mention(value) = self { value } else { nil }
    }

    var fixtureVideo: ThreadVideoContent? {
        if case let .video(value) = self { value } else { nil }
    }

    var fixtureVoice: ThreadVoiceContent? {
        if case let .voice(value) = self { value } else { nil }
    }

    var fixtureUnsupported: ThreadUnsupportedContent? {
        if case let .unsupported(value) = self { value } else { nil }
    }
}
