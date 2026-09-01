import Foundation

struct ThreadContentSource: Hashable, Sendable {
    enum Scope: String, Hashable, Sendable {
        case firstPost
        case post
        case subPost
    }

    let threadID: Int64
    let postID: Int64
    let scope: Scope
}

struct ThreadContentNodeID: Hashable, Sendable {
    let source: ThreadContentSource
    let ordinal: Int

    var stableKey: String {
        "t\(source.threadID).p\(source.postID).s\(source.scope.rawValue).n\(ordinal)"
    }
}

struct ThreadContentNode: Identifiable, Equatable, Sendable {
    let id: ThreadContentNodeID
    let rawType: Int32
    let payload: ThreadContentPayload
}

enum ThreadContentPayload: Equatable, Sendable {
    case emoji(ThreadEmojiContent)
    case image(ThreadImageContent)
    case link(ThreadLinkContent)
    case mention(ThreadMentionContent)
    case text(ThreadTextContent)
    case unsupported(ThreadUnsupportedContent)
    case video(ThreadVideoContent)
    case voice(ThreadVoiceContent)

    var isVisiblyEmpty: Bool {
        switch self {
        case let .text(content):
            content.value.isEmpty
        case .emoji, .image, .link, .mention, .unsupported, .video, .voice:
            false
        }
    }
}

struct ThreadTextContent: Equatable, Sendable {
    let value: String
}

enum ThreadWebScheme: String, Equatable, Sendable {
    case http
    case https
}

struct ValidatedWebDestination: Hashable, Sendable {
    let absoluteString: String
    let scheme: ThreadWebScheme
}

enum ThreadURLRejection: Error, Equatable, Sendable {
    case empty
    case malformed
    case notAbsolute
    case tooLong
    case unsupportedScheme
}

struct ExternalLinkIntent: Equatable, Sendable {
    let sourceNodeID: ThreadContentNodeID
    let label: String
    let destination: ValidatedWebDestination
}

struct ThreadLinkContent: Equatable, Sendable {
    let label: String
    let intent: ExternalLinkIntent?
    let rejection: ThreadURLRejection?
}

struct ThreadEmojiContent: Equatable, Sendable {
    let registryKey: String
    let code: String

    var fallbackText: String {
        code.isEmpty ? "[表情]" : "#(\(code))"
    }
}

struct ThreadMentionContent: Equatable, Sendable {
    let userID: Int64?
    let label: String
}

enum ThreadImageCandidateRole: String, Equatable, Sendable {
    case activeCDN
    case big
    case bigCDN
    case cdn
    case dynamic
    case original
    case source
}

struct ThreadImageCandidate: Hashable, Sendable {
    let role: ThreadImageCandidateRole
    let destination: ValidatedWebDestination
}

struct ThreadImageRequestDescriptor: Hashable, Sendable {
    let resourceID: String
    let candidates: [ThreadImageCandidate]

    var isLoadable: Bool {
        !candidates.isEmpty
    }

    func imageRequest(
        purpose: ImageRequestPurpose,
        targetPixelSize: ImageTargetPixelSize
    ) -> ImageRequest {
        let orderedRoles: [ThreadImageCandidateRole]
        switch purpose {
        case .mediaViewer:
            orderedRoles = [
                .original, .bigCDN, .big, .dynamic,
                .cdn, .activeCDN, .source
            ]
        case .threadContent:
            orderedRoles = [
                .bigCDN, .big, .dynamic, .cdn,
                .activeCDN, .source, .original
            ]
        case .avatar, .fixture, .listThumbnail:
            orderedRoles = [
                .original, .bigCDN, .big, .dynamic,
                .cdn, .activeCDN, .source
            ]
        }
        let rank = Dictionary(
            uniqueKeysWithValues: orderedRoles.enumerated().map {
                ($0.element, $0.offset)
            }
        )
        let orderedCandidates = candidates.enumerated().sorted { lhs, rhs in
            let lhsRank = rank[lhs.element.role] ?? Int.max
            let rhsRank = rank[rhs.element.role] ?? Int.max
            return lhsRank == rhsRank
                ? lhs.offset < rhs.offset
                : lhsRank < rhsRank
        }
        let resource = ImageResourceDescriptor(
            resourceID: resourceID,
            candidateURLs: orderedCandidates.map {
                $0.element.destination.absoluteString
            }
        )
        return ImageRequest(
            resource: resource,
            targetPixelSize: targetPixelSize,
            purpose: purpose,
            resizeMode: .fit
        )
    }
}

enum ThreadMediaDimensionFallback: Equatable, Sendable {
    case extremeAspectRatio
    case malformed
    case missing
    case nonPositive
    case outOfRange
}

enum ThreadMediaDimensions: Equatable, Sendable {
    case fallback(ThreadMediaDimensionFallback)
    case known(width: Int, height: Int)

    static let fallbackAspectRatio = 4.0 / 3.0

    var layoutAspectRatio: Double {
        switch self {
        case .fallback:
            Self.fallbackAspectRatio
        case let .known(width, height):
            Double(width) / Double(height)
        }
    }
}

struct ThreadMediaID: Hashable, Sendable {
    let sourceNodeID: ThreadContentNodeID

    var stableKey: String {
        sourceNodeID.stableKey
    }
}

struct ThreadImageContent: Equatable, Sendable {
    let rawType: Int32
    let mediaID: ThreadMediaID
    let request: ThreadImageRequestDescriptor
    let dimensions: ThreadMediaDimensions
    let alternativeText: String
    let originalByteCount: UInt32?
    let showsOriginalControlHint: Bool
}

struct ThreadVideoContent: Equatable, Sendable {
    let thumbnail: ThreadImageRequestDescriptor?
    let dimensions: ThreadMediaDimensions
    let videoTarget: ValidatedWebDestination?
    let externalIntent: ExternalLinkIntent?

    var hasThumbnail: Bool {
        thumbnail?.isLoadable == true
    }
}

struct ThreadVoiceContent: Equatable, Sendable {
    let resourceID: String?
    let durationSeconds: UInt32
}

enum ThreadUnsupportedField: String, Equatable, Sendable {
    case image
    case link
    case memeInfo = "meme-info"
    case text
    case voice
}

struct ThreadUnsupportedContent: Equatable, Sendable {
    let rawType: Int32
    let presentFields: [ThreadUnsupportedField]

    var safeDiagnostic: String {
        let fields = presentFields.map(\.rawValue).sorted().joined(separator: ",")
        return fields.isEmpty
            ? "raw-type:\(rawType) fields:none"
            : "raw-type:\(rawType) fields:\(fields)"
    }
}

enum ThreadContentUnavailableReason: Equatable, Sendable {
    case blocked
    case deletedFirstPost(rawFlag: Int32)
    case folded(message: String?)
}

enum ThreadContentAvailability: Equatable, Sendable {
    case available
    case unavailable(ThreadContentUnavailableReason)
}

enum ThreadPollMode: Equatable, Sendable {
    case multiple
    case single
    case unknown(rawValue: Int32)
}

struct ThreadPollOptionID: Hashable, Sendable {
    let source: ThreadContentSource
    let ordinal: Int
}

struct ThreadPollOption: Identifiable, Equatable, Sendable {
    let id: ThreadPollOptionID
    let rawOptionID: Int32
    let text: String
    let voteCount: Int64
    let voteRatio: Double?
    let imageWasPresent: Bool
}

struct ThreadReadOnlyPoll: Equatable, Sendable {
    let rawType: Int32
    let mode: ThreadPollMode
    let title: String
    let tips: String
    let totalParticipants: Int64
    let totalVotes: Int64
    let isPolled: Bool
    let polledValue: String
    let endTime: Int32
    let rawStatus: Int32
    let lastTime: UInt32
    let options: [ThreadPollOption]

    let isReadOnly = true
}

struct ThreadMediaItem: Equatable, Sendable {
    let mediaID: ThreadMediaID
    let sourceNodeID: ThreadContentNodeID
    let request: ThreadImageRequestDescriptor
    let dimensions: ThreadMediaDimensions
    let alternativeText: String
}

struct ThreadMediaIntent: Equatable, Sendable {
    let initialMediaID: ThreadMediaID
    let items: [ThreadMediaItem]
}

struct ThreadContentDocument: Equatable, Sendable {
    let source: ThreadContentSource
    let availability: ThreadContentAvailability
    let nodes: [ThreadContentNode]
    let poll: ThreadReadOnlyPoll?

    var isVisiblyEmpty: Bool {
        poll == nil && nodes.allSatisfy { $0.payload.isVisiblyEmpty }
    }

    func mediaIntent(selecting selected: ThreadMediaID) -> ThreadMediaIntent? {
        let items = nodes.compactMap { node -> ThreadMediaItem? in
            guard case let .image(content) = node.payload,
                  content.request.isLoadable else {
                return nil
            }
            return ThreadMediaItem(
                mediaID: content.mediaID,
                sourceNodeID: node.id,
                request: content.request,
                dimensions: content.dimensions,
                alternativeText: content.alternativeText
            )
        }
        guard items.contains(where: { $0.mediaID == selected }) else {
            return nil
        }
        return ThreadMediaIntent(initialMediaID: selected, items: items)
    }
}
