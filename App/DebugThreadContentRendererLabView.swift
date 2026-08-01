#if DEBUG
import SwiftUI

@MainActor
struct DebugThreadContentRendererLabView: View {
    private static let isolationCanary =
        "TIEBALITE_THREAD_CONTENT_RENDERER_LAB_CANARY"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.motionReductionOverride) private var reductionOverride

    let imageLoader: any ImageLoading

    @State private var mediaIntentLabel = "Media intent: none"
    @State private var externalIntentLabel = "External intent: none"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                Text(Self.isolationCanary)
                    .frame(width: 0, height: 0)
                    .hidden()
                    .accessibilityHidden(true)

                environmentSummary
                intentSummary
                fixtureSection(
                    title: "混合内容与顺序",
                    document: DebugThreadContentRendererFixtures.mixed
                )
                fixtureSection(
                    title: "空内容",
                    document: DebugThreadContentRendererFixtures.empty
                )
                fixtureSection(
                    title: "删除内容",
                    document: DebugThreadContentRendererFixtures.deleted
                )
                fixtureSection(
                    title: "屏蔽内容",
                    document: DebugThreadContentRendererFixtures.blocked
                )
            }
            .padding(Spacing.large)
        }
        .background(SemanticColor.background)
        .navigationTitle("正文 Renderer Lab")
        .accessibilityIdentifier(AppAccessibilityID.threadContentRendererLab)
    }

    private var environmentSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("P0 renderer fixtures: 23 nodes")
                .font(Typography.font(.headline))
            Text(colorScheme == .dark ? "Appearance: Dark" : "Appearance: Light")
                .accessibilityIdentifier(
                    AppAccessibilityID.threadContentRendererAppearance
                )
            Text(
                dynamicTypeSize.isAccessibilitySize
                    ? "Dynamic Type: Accessibility"
                    : "Dynamic Type: Standard"
            )
            .accessibilityIdentifier(
                AppAccessibilityID.threadContentRendererDynamicType
            )
            Text(
                reduceMotion || reductionOverride
                    ? "Reduce Motion: On"
                    : "Reduce Motion: Off"
            )
            .accessibilityIdentifier(
                AppAccessibilityID.threadContentRendererReduceMotion
            )
        }
        .font(Typography.font(.body))
        .foregroundStyle(SemanticColor.primaryText)
    }

    private var intentSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(mediaIntentLabel)
                .accessibilityIdentifier(
                    AppAccessibilityID.threadContentRendererMediaIntent
                )
            Text(externalIntentLabel)
                .accessibilityIdentifier(
                    AppAccessibilityID.threadContentRendererExternalIntent
                )
        }
        .font(Typography.font(.caption))
        .foregroundStyle(SemanticColor.secondaryText)
    }

    private func fixtureSection(
        title: String,
        document: ThreadContentDocument
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text(title)
                .font(Typography.font(.headline))
                .foregroundStyle(SemanticColor.primaryText)
            ThreadContentRenderer(
                document: document,
                imageLoader: imageLoader,
                onOpenMedia: { intent in
                    mediaIntentLabel =
                        "Media intent: \(intent.initialMediaID.stableKey)"
                },
                onOpenExternalLink: { intent in
                    externalIntentLabel =
                        "External intent: \(intent.sourceNodeID.stableKey)"
                }
            )
        }
    }
}

enum DebugThreadContentRendererFixtures {
    static let decodeFailedImageResourceID =
        "renderer-fixture.image.decode-failure"
    static let loadedImageResourceID = "renderer-fixture.image.success"
    static let loadingImageResourceID = "renderer-fixture.image.loading"
    static let failedImageResourceID = "renderer-fixture.image.failure"

    static var mixed: ThreadContentDocument {
        let source = ThreadContentSource(
            threadID: 91_001,
            postID: 92_001,
            scope: .firstPost
        )
        let safeDestination = ValidatedWebDestination(
            absoluteString: "https://fixture.invalid/renderer/link",
            scheme: .https
        )
        let imageDestination = ValidatedWebDestination(
            absoluteString: "https://fixture.invalid/renderer/image.png",
            scheme: .https
        )
        var nodes: [ThreadContentNode] = []

        func append(
            rawType: Int32,
            payload: (ThreadContentNodeID) -> ThreadContentPayload
        ) {
            let id = ThreadContentNodeID(source: source, ordinal: nodes.count)
            nodes.append(ThreadContentNode(
                id: id,
                rawType: rawType,
                payload: payload(id)
            ))
        }

        append(rawType: 0) { _ in
            .text(ThreadTextContent(value: "合成短文本。"))
        }
        append(rawType: 0) { _ in
            .text(ThreadTextContent(value: "第一段合成文本。\n第二段保留换行。"))
        }
        for rawType in [Int32(9), 27, 35, 40] {
            append(rawType: rawType) { _ in
                .text(ThreadTextContent(value: "raw \(rawType) 文本降级"))
            }
        }
        append(rawType: 1) { id in
            .link(ThreadLinkContent(
                label: "合成安全链接",
                intent: ExternalLinkIntent(
                    sourceNodeID: id,
                    label: "合成安全链接",
                    destination: safeDestination
                ),
                rejection: nil
            ))
        }
        append(rawType: 1) { _ in
            .link(ThreadLinkContent(
                label: "危险 scheme 已拒绝",
                intent: nil,
                rejection: .unsupportedScheme
            ))
        }
        append(rawType: 2) { _ in
            .emoji(ThreadEmojiContent(
                registryKey: "synthetic-emoticon-key",
                code: "synthetic_smile"
            ))
        }
        append(rawType: 3) { id in
            imagePayload(
                rawType: 3,
                id: id,
                resourceID: loadedImageResourceID,
                destination: imageDestination
            )
        }
        append(rawType: 3) { id in
            imagePayload(
                rawType: 3,
                id: id,
                resourceID: loadingImageResourceID,
                destination: imageDestination
            )
        }
        append(rawType: 3) { id in
            imagePayload(
                rawType: 3,
                id: id,
                resourceID: failedImageResourceID,
                destination: imageDestination
            )
        }
        append(rawType: 3) { id in
            imagePayload(
                rawType: 3,
                id: id,
                resourceID: decodeFailedImageResourceID,
                destination: imageDestination,
                alternativeText: "不可解码图片"
            )
        }
        append(rawType: 4) { _ in
            .mention(ThreadMentionContent(
                userID: 7_301,
                label: "@SyntheticMember"
            ))
        }
        append(rawType: 5) { id in
            .video(ThreadVideoContent(
                thumbnail: ThreadImageRequestDescriptor(
                    resourceID: "renderer-fixture.video.thumbnail",
                    candidates: [ThreadImageCandidate(
                        role: .source,
                        destination: imageDestination
                    )]
                ),
                dimensions: .known(width: 1_280, height: 720),
                videoTarget: safeDestination,
                externalIntent: ExternalLinkIntent(
                    sourceNodeID: id,
                    label: "视频",
                    destination: safeDestination
                )
            ))
        }
        append(rawType: 10) { _ in
            .voice(ThreadVoiceContent(
                resourceID: "synthetic-voice-resource",
                durationSeconds: 17
            ))
        }
        append(rawType: 20) { id in
            imagePayload(
                rawType: 20,
                id: id,
                resourceID: loadedImageResourceID,
                destination: imageDestination
            )
        }
        append(rawType: 999) { _ in
            .unsupported(ThreadUnsupportedContent(
                rawType: 999,
                presentFields: [.text, .link]
            ))
        }
        append(rawType: 999) { _ in
            .unsupported(ThreadUnsupportedContent(
                rawType: 999,
                presentFields: [.memeInfo]
            ))
        }
        append(rawType: 0) { _ in
            .text(ThreadTextContent(value: ""))
        }
        append(rawType: 0) { _ in
            .text(ThreadTextContent(
                value: String(repeating: "超长连续文本", count: 80)
            ))
        }
        append(rawType: 0) { _ in
            .text(ThreadTextContent(
                value: String(
                    repeating: "这是用于 Dynamic Type 换行验证的合成长正文。",
                    count: 35
                )
            ))
        }
        append(rawType: 0) { _ in
            .text(ThreadTextContent(value: "未知节点之后的合成尾部文本。"))
        }

        let poll = ThreadReadOnlyPoll(
            rawType: 999,
            mode: .multiple,
            title: "合成只读投票",
            tips: "总票数为零时不进行除法。",
            totalParticipants: 8,
            totalVotes: 0,
            isPolled: true,
            polledValue: "2",
            endTime: 1_700_000_000,
            rawStatus: 999,
            lastTime: 120,
            options: [
                ThreadPollOption(
                    id: ThreadPollOptionID(source: source, ordinal: 0),
                    rawOptionID: 1,
                    text: "合成选项 A",
                    voteCount: 3,
                    voteRatio: nil,
                    imageWasPresent: false
                ),
                ThreadPollOption(
                    id: ThreadPollOptionID(source: source, ordinal: 1),
                    rawOptionID: 2,
                    text: "合成选项 B",
                    voteCount: 5,
                    voteRatio: nil,
                    imageWasPresent: true
                )
            ]
        )
        return ThreadContentDocument(
            source: source,
            availability: .available,
            nodes: nodes,
            poll: poll
        )
    }

    static var empty: ThreadContentDocument {
        document(
            threadID: 91_002,
            postID: 92_002,
            availability: .available
        )
    }

    static var deleted: ThreadContentDocument {
        document(
            threadID: 91_003,
            postID: 92_003,
            availability: .unavailable(.deletedFirstPost(rawFlag: 1))
        )
    }

    static var blocked: ThreadContentDocument {
        document(
            threadID: 91_004,
            postID: 92_004,
            availability: .unavailable(.blocked)
        )
    }

    private static func imagePayload(
        rawType: Int32,
        id: ThreadContentNodeID,
        resourceID: String,
        destination: ValidatedWebDestination,
        alternativeText: String? = nil
    ) -> ThreadContentPayload {
        .image(ThreadImageContent(
            rawType: rawType,
            mediaID: ThreadMediaID(sourceNodeID: id),
            request: ThreadImageRequestDescriptor(
                resourceID: resourceID,
                candidates: [ThreadImageCandidate(
                    role: .source,
                    destination: destination
                )]
            ),
            dimensions: .known(width: 640, height: 480),
            alternativeText: alternativeText
                ?? (rawType == 20 ? "替代图片" : "合成图片"),
            originalByteCount: nil,
            showsOriginalControlHint: false
        ))
    }

    private static func document(
        threadID: Int64,
        postID: Int64,
        availability: ThreadContentAvailability
    ) -> ThreadContentDocument {
        ThreadContentDocument(
            source: ThreadContentSource(
                threadID: threadID,
                postID: postID,
                scope: .firstPost
            ),
            availability: availability,
            nodes: [],
            poll: nil
        )
    }
}
#endif
