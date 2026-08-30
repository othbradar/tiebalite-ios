import SwiftUI
import UIKit

private enum ThreadContentLayout {
    static let minimumInteractiveDimension: CGFloat = 44
}

@MainActor
struct ThreadContentRenderer: View {
    let document: ThreadContentDocument
    let imageLoader: any ImageLoading
    let readingTextSize: ReadingTextSizePreference
    let onOpenMedia: (ThreadMediaIntent) -> Void
    let onOpenExternalLink: (ExternalLinkIntent) -> Void

    init(
        document: ThreadContentDocument,
        imageLoader: any ImageLoading,
        readingTextSize: ReadingTextSizePreference = .standard,
        onOpenMedia: @escaping (ThreadMediaIntent) -> Void = { _ in },
        onOpenExternalLink: @escaping (ExternalLinkIntent) -> Void = { _ in }
    ) {
        self.document = document
        self.imageLoader = imageLoader
        self.readingTextSize = readingTextSize
        self.onOpenMedia = onOpenMedia
        self.onOpenExternalLink = onOpenExternalLink
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            switch document.availability {
            case .available:
                availableContent
            case let .unavailable(reason):
                ThreadUnavailableContentView(reason: reason)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ThreadContentAccessibilityID.document)
    }

    @ViewBuilder
    private var availableContent: some View {
        if document.isVisiblyEmpty {
            ThreadEmptyContentView()
        } else {
            ForEach(document.nodes) { node in
                ThreadContentNodeView(
                    node: node,
                    document: document,
                    imageLoader: imageLoader,
                    readingTextSize: readingTextSize,
                    onOpenMedia: onOpenMedia,
                    onOpenExternalLink: onOpenExternalLink
                )
            }
            if let poll = document.poll {
                ThreadReadOnlyPollView(poll: poll)
            }
        }
    }
}

@MainActor
private struct ThreadContentNodeView: View {
    let node: ThreadContentNode
    let document: ThreadContentDocument
    let imageLoader: any ImageLoading
    let readingTextSize: ReadingTextSizePreference
    let onOpenMedia: (ThreadMediaIntent) -> Void
    let onOpenExternalLink: (ExternalLinkIntent) -> Void

    @ViewBuilder
    var body: some View {
        Group {
            switch node.payload {
            case let .text(content):
                Text(content.value)
                    .textSelection(.enabled)
            case let .link(content):
                ThreadLinkView(
                    content: content,
                    onOpenExternalLink: onOpenExternalLink
                )
            case let .emoji(content):
                Text(content.fallbackText)
                    .accessibilityLabel("表情，\(content.fallbackText)")
            case let .mention(content):
                Text(content.label.isEmpty ? "提及用户" : content.label)
                    .foregroundStyle(SemanticColor.accent)
                    .accessibilityLabel(
                        content.label.isEmpty ? "提及用户" : content.label
                    )
            case let .image(content):
                ThreadContentImageView(
                    content: content,
                    mediaIntent: document.mediaIntent(selecting: content.mediaID),
                    imageLoader: imageLoader,
                    onOpenMedia: onOpenMedia
                )
            case let .video(content):
                ThreadVideoPlaceholderView(
                    content: content,
                    onOpenExternalLink: onOpenExternalLink
                )
            case let .voice(content):
                ThreadVoicePlaceholderView(content: content)
            case let .unsupported(content):
                ThreadUnsupportedContentView(
                    content: content,
                    nodeID: node.id
                )
            }
        }
        .font(Typography.threadContentFont(readingTextSize))
        .foregroundStyle(SemanticColor.primaryText)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(
            ThreadContentAccessibilityID.node(node.id)
        )
    }
}

@MainActor
private struct ThreadLinkView: View {
    let content: ThreadLinkContent
    let onOpenExternalLink: (ExternalLinkIntent) -> Void

    @ViewBuilder
    var body: some View {
        if let intent = content.intent {
            Button {
                onOpenExternalLink(intent)
            } label: {
                Label(
                    content.label.isEmpty ? "打开链接" : content.label,
                    systemImage: "link"
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: ThreadContentLayout.minimumInteractiveDimension,
                    alignment: .leading
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(SemanticColor.accent)
            .accessibilityHint("生成外部链接意图")
        } else {
            Label(
                content.label.isEmpty ? "链接不可用" : content.label,
                systemImage: "link.badge.plus"
            )
            .foregroundStyle(SemanticColor.secondaryText)
            .accessibilityValue("链接不可用")
        }
    }
}

@MainActor
private struct ThreadContentImageView: View {
    let content: ThreadImageContent
    let mediaIntent: ThreadMediaIntent?
    let imageLoader: any ImageLoading
    let onOpenMedia: (ThreadMediaIntent) -> Void

    @State private var requestGeneration: UInt64 = 0
    @State private var renderState = ThreadContentImageRenderState.idle

    var body: some View {
        Group {
            if let availableIntent = currentRenderState.mediaIntent(
                from: mediaIntent
            ) {
                Button {
                    onOpenMedia(availableIntent)
                } label: {
                    stableImageFrame
                }
                .buttonStyle(.plain)
                .accessibilityLabel(content.alternativeText)
                .accessibilityHint(ThreadContentImageCopy.openMediaHint)
                .accessibilityValue(
                    currentRenderState.phase.accessibilityValue
                )
                .accessibilityIdentifier(
                    ThreadContentAccessibilityID.imageAction(content.mediaID)
                )
            } else {
                stableImageFrame
                    .accessibilityLabel(content.alternativeText)
            }
        }
        .accessibilityElement(children: .contain)
        .task(id: content.request) {
            let request = content.request
            requestGeneration &+= 1
            let generation = requestGeneration
            renderState = .loading(request)
            do {
                let resolved = try await ThreadContentImageLoad.resolve(
                    request,
                    using: imageLoader
                )
                guard requestGeneration == generation,
                      !Task.isCancelled else {
                    return
                }
                renderState = resolved
            } catch is CancellationError {
                guard requestGeneration == generation else {
                    return
                }
                renderState = .cancelled(request)
            } catch {
                guard requestGeneration == generation else {
                    return
                }
                renderState = .failedToFetch(request)
            }
        }
    }

    private var currentRenderState: ThreadContentImageRenderState {
        renderState.projected(for: content.request)
    }

    private var stableImageFrame: some View {
        Color.clear
        .aspectRatio(
            ThreadContentImagePresentation.layoutAspectRatio(
                dimensions: content.dimensions,
                phase: currentRenderState.phase
            ),
            contentMode: .fit
        )
        .frame(
            maxWidth: .infinity,
            minHeight: ThreadContentLayout.minimumInteractiveDimension
        )
        .background {
            GeometryReader { geometry in
                phaseContent
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .clipped()
            }
        }
        .background(SemanticColor.surface)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.alternativeText)
        .accessibilityValue(currentRenderState.phase.accessibilityValue)
        .accessibilityIdentifier(
            ThreadContentAccessibilityID.imageState(content.mediaID)
        )
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch currentRenderState {
        case .idle:
            imageStatusContent(
                systemImage: "photo",
                message: ThreadContentImageCopy.idleMessage
            )
        case .loading:
            VStack(spacing: Spacing.small) {
                ProgressView()
                Text(ThreadContentImageCopy.loadingMessage)
                    .font(Typography.font(.caption))
            }
            .foregroundStyle(SemanticColor.secondaryText)
        case let .rendered(_, image):
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        case .failedToDecode, .failedToFetch:
            imageStatusContent(
                systemImage: "photo.badge.exclamationmark",
                message: ThreadContentImageCopy.failureMessage
            )
        case .cancelled:
            imageStatusContent(
                systemImage: "photo",
                message: ThreadContentImageCopy.cancelledMessage
            )
        }
    }

    private func imageStatusContent(
        systemImage: String,
        message: String
    ) -> some View {
        VStack(spacing: Spacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: IconSize.large))
                .accessibilityHidden(true)
            Text(message)
                .font(Typography.font(.caption))
        }
        .foregroundStyle(SemanticColor.secondaryText)
    }
}

@MainActor
private struct ThreadVideoPlaceholderView: View {
    let content: ThreadVideoContent
    let onOpenExternalLink: (ExternalLinkIntent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Label("视频内容", systemImage: "play.rectangle")
                .font(Typography.font(.headline))
            Text(content.hasThumbnail ? "已保留安全缩略图描述" : "没有可用缩略图")
                .font(Typography.font(.caption))
                .foregroundStyle(SemanticColor.secondaryText)
            if let intent = content.externalIntent {
                Button {
                    onOpenExternalLink(intent)
                } label: {
                    Text("生成视频外链意图")
                        .frame(
                            minHeight: ThreadContentLayout
                                .minimumInteractiveDimension
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .tint(SemanticColor.accent)
            }
        }
        .padding(Spacing.medium)
        .background(SemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .accessibilityElement(children: .contain)
    }
}

@MainActor
private struct ThreadVoicePlaceholderView: View {
    let content: ThreadVoiceContent

    var body: some View {
        Label(
            content.durationSeconds == 0
                ? "语音内容，时长未知"
                : "语音内容，\(content.durationSeconds) 秒",
            systemImage: "waveform"
        )
        .padding(Spacing.medium)
        .background(SemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .accessibilityValue(
            content.resourceID == nil ? "资源不可用" : "只读占位"
        )
    }
}

@MainActor
private struct ThreadUnsupportedContentView: View {
    let content: ThreadUnsupportedContent
    let nodeID: ThreadContentNodeID

    var body: some View {
        Label("暂不支持的内容（类型 \(content.rawType)）", systemImage: "questionmark.square")
            .font(Typography.font(.subheadline))
            .foregroundStyle(SemanticColor.secondaryText)
            .padding(Spacing.small)
            .background(SemanticColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(
                ThreadContentAccessibilityID.unsupported(nodeID)
            )
    }
}

@MainActor
private struct ThreadReadOnlyPollView: View {
    let poll: ThreadReadOnlyPoll

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                Text(poll.title)
                    .font(Typography.font(.headline))
                Text(modeLabel)
                    .font(Typography.font(.caption))
                    .foregroundStyle(SemanticColor.accent)
            }
            if !poll.tips.isEmpty {
                Text(poll.tips)
                    .font(Typography.font(.subheadline))
                    .foregroundStyle(SemanticColor.secondaryText)
            }
            ForEach(poll.options) { option in
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(option.text.isEmpty ? "未命名选项" : option.text)
                        Spacer(minLength: Spacing.small)
                        Text("\(option.voteCount) 票")
                            .foregroundStyle(SemanticColor.secondaryText)
                    }
                    ProgressView(value: option.voteRatio ?? 0)
                        .tint(SemanticColor.accent)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(
                    ThreadContentAccessibilityID.pollOption(option.id.ordinal)
                )
            }
            Text("只读投票，不提供提交操作")
                .font(Typography.font(.caption))
                .foregroundStyle(SemanticColor.secondaryText)
        }
        .padding(Spacing.medium)
        .background(SemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ThreadContentAccessibilityID.poll)
    }

    private var modeLabel: String {
        switch poll.mode {
        case .single:
            "单选"
        case .multiple:
            "多选"
        case .unknown:
            "类型未知"
        }
    }
}

@MainActor
private struct ThreadEmptyContentView: View {
    var body: some View {
        Label("内容暂不可用", systemImage: "text.page.slash")
            .font(Typography.font(.body))
            .foregroundStyle(SemanticColor.secondaryText)
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity)
            .background(SemanticColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .accessibilityIdentifier(ThreadContentAccessibilityID.empty)
    }
}

@MainActor
private struct ThreadUnavailableContentView: View {
    let reason: ThreadContentUnavailableReason

    var body: some View {
        Label(message, systemImage: "eye.slash")
            .font(Typography.font(.body))
            .foregroundStyle(SemanticColor.secondaryText)
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity)
            .background(SemanticColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .accessibilityIdentifier(ThreadContentAccessibilityID.unavailable)
    }

    private var message: String {
        switch reason {
        case .blocked:
            "内容已被屏蔽"
        case .deletedFirstPost:
            "内容已删除或不可见"
        case let .folded(message):
            message?.isEmpty == false ? message ?? "内容已折叠" : "内容已折叠"
        }
    }
}

enum ThreadContentAccessibilityID {
    static let document = "thread-reader.content.document"
    static let empty = "thread-reader.content.empty"
    static let poll = "thread-reader.content.poll"
    static let unavailable = "thread-reader.content.unavailable"

    static func node(_ id: ThreadContentNodeID) -> String {
        "thread-reader.content.node.\(id.stableKey)"
    }

    static func imageState(_ id: ThreadMediaID) -> String {
        "thread-reader.content.image.\(id.stableKey).state"
    }

    static func imageAction(_ id: ThreadMediaID) -> String {
        "thread-reader.content.image.\(id.stableKey).action"
    }

    static func unsupported(_ id: ThreadContentNodeID) -> String {
        "thread-reader.content.unsupported.\(id.stableKey)"
    }

    static func pollOption(_ ordinal: Int) -> String {
        "thread-reader.content.poll.option.\(ordinal)"
    }
}
