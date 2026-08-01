import Foundation
import GeneratedProtobuf
import SwiftProtobuf

enum ThreadContentMappingError: Error, Equatable, Sendable {
    case emptyBody
    case malformedWire
}

enum ThreadContentProtoMapper {
    private static let maximumURLLength = 2_048
    private static let maximumMediaDimension = 16_384
    private static let maximumVoiceResourceLength = 256

    static func map(serializedThreadInfo bytes: Data) throws -> ThreadContentDocument {
        guard !bytes.isEmpty else {
            throw ThreadContentMappingError.emptyBody
        }

        let thread: Tieba_ThreadInfo
        do {
            thread = try Tieba_ThreadInfo(serializedBytes: bytes)
        } catch {
            throw ThreadContentMappingError.malformedWire
        }
        return map(thread)
    }

    private static func map(_ thread: Tieba_ThreadInfo) -> ThreadContentDocument {
        let threadID = firstPositive(thread.threadID, thread.id)
        let postID = firstPositive(thread.firstPostID, thread.postID)
        let source = ThreadContentSource(
            threadID: threadID,
            postID: postID,
            scope: .firstPost
        )
        let nodes = thread.firstPostContent.enumerated().map { ordinal, wire in
            let id = ThreadContentNodeID(source: source, ordinal: ordinal)
            return ThreadContentNode(
                id: id,
                rawType: wire.type,
                payload: map(wire, id: id)
            )
        }
        let availability: ThreadContentAvailability = thread.isDeleted == 0
            ? .available
            : .unavailable(.deletedFirstPost(rawFlag: thread.isDeleted))
        return ThreadContentDocument(
            source: source,
            availability: availability,
            nodes: nodes,
            poll: thread.hasPollInfo ? map(thread.pollInfo, source: source) : nil
        )
    }

    private static func map(
        _ wire: Tieba_PbContent,
        id: ThreadContentNodeID
    ) -> ThreadContentPayload {
        switch wire.type {
        case 0, 9, 27, 35, 40:
            .text(ThreadTextContent(value: wire.text))
        case 1:
            .link(mapLink(label: wire.text, rawTarget: wire.link, id: id))
        case 2:
            .emoji(ThreadEmojiContent(registryKey: wire.text, code: wire.c))
        case 3, 20:
            .image(mapImage(wire, id: id))
        case 4:
            .mention(ThreadMentionContent(
                userID: wire.uid > 0 ? wire.uid : nil,
                label: wire.text
            ))
        case 5:
            .video(mapVideo(wire, id: id))
        case 10:
            .voice(ThreadVoiceContent(
                resourceID: validatedVoiceResource(wire.voiceMd5),
                durationSeconds: wire.duringTime
            ))
        default:
            .unsupported(mapUnsupported(wire))
        }
    }

    private static func mapLink(
        label: String,
        rawTarget: String,
        id: ThreadContentNodeID
    ) -> ThreadLinkContent {
        switch validateWebDestination(rawTarget) {
        case let .success(destination):
            return ThreadLinkContent(
                label: label,
                intent: ExternalLinkIntent(
                    sourceNodeID: id,
                    label: label,
                    destination: destination
                ),
                rejection: nil
            )
        case let .failure(reason):
            return ThreadLinkContent(
                label: label,
                intent: nil,
                rejection: reason
            )
        }
    }

    private static func mapImage(
        _ wire: Tieba_PbContent,
        id: ThreadContentNodeID
    ) -> ThreadImageContent {
        let candidates: [(ThreadImageCandidateRole, String)]
        if wire.type == 20 {
            candidates = [(.source, wire.src)]
        } else {
            candidates = [
                (.original, wire.originSrc),
                (.bigCDN, wire.bigCdnSrc),
                (.big, wire.bigSrc),
                (.dynamic, wire.dynamic),
                (.cdn, wire.cdnSrc),
                (.activeCDN, wire.cdnSrcActive),
                (.source, wire.src)
            ]
        }
        let request = ThreadImageRequestDescriptor(
            resourceID: id.stableKey,
            candidates: validatedImageCandidates(candidates)
        )
        return ThreadImageContent(
            rawType: wire.type,
            mediaID: ThreadMediaID(sourceNodeID: id),
            request: request,
            dimensions: mapDimensions(wire.bsize),
            alternativeText: "图片",
            originalByteCount: wire.originSize > 0 ? wire.originSize : nil,
            showsOriginalControlHint: wire.showOriginalBtn == 1
        )
    }

    private static func mapVideo(
        _ wire: Tieba_PbContent,
        id: ThreadContentNodeID
    ) -> ThreadVideoContent {
        let thumbnailCandidates = validatedImageCandidates([(.source, wire.src)])
        let thumbnail = thumbnailCandidates.isEmpty
            ? nil
            : ThreadImageRequestDescriptor(
                resourceID: "\(id.stableKey).video-thumbnail",
                candidates: thumbnailCandidates
            )
        let videoTarget = validateHTTPSDestination(wire.link)
        let externalIntent: ExternalLinkIntent?
        switch validateWebDestination(wire.text) {
        case let .success(destination):
            externalIntent = ExternalLinkIntent(
                sourceNodeID: id,
                label: "视频",
                destination: destination
            )
        case .failure:
            externalIntent = nil
        }
        return ThreadVideoContent(
            thumbnail: thumbnail,
            dimensions: mapDimensions(wire.bsize),
            videoTarget: videoTarget,
            externalIntent: externalIntent
        )
    }

    private static func mapUnsupported(
        _ wire: Tieba_PbContent
    ) -> ThreadUnsupportedContent {
        var presentFields: [ThreadUnsupportedField] = []
        if !wire.text.isEmpty {
            presentFields.append(.text)
        }
        if !wire.link.isEmpty {
            presentFields.append(.link)
        }
        if !wire.src.isEmpty || !wire.originSrc.isEmpty {
            presentFields.append(.image)
        }
        if !wire.voiceMd5.isEmpty {
            presentFields.append(.voice)
        }
        if wire.hasMemeInfo {
            presentFields.append(.memeInfo)
        }
        return ThreadUnsupportedContent(
            rawType: wire.type,
            presentFields: presentFields
        )
    }

    private static func map(
        _ wire: Tieba_PollInfo,
        source: ThreadContentSource
    ) -> ThreadReadOnlyPoll {
        let mode: ThreadPollMode
        switch wire.isMulti {
        case 0:
            mode = .single
        case 1:
            mode = .multiple
        default:
            mode = .unknown(rawValue: wire.isMulti)
        }
        let options = wire.options.enumerated().map { ordinal, option in
            let ratio: Double?
            if wire.totalPoll > 0 {
                ratio = min(
                    1,
                    max(0, Double(option.num) / Double(wire.totalPoll))
                )
            } else {
                ratio = nil
            }
            return ThreadPollOption(
                id: ThreadPollOptionID(source: source, ordinal: ordinal),
                rawOptionID: option.id,
                text: option.text,
                voteCount: option.num,
                voteRatio: ratio,
                imageWasPresent: !option.image.isEmpty
            )
        }
        return ThreadReadOnlyPoll(
            rawType: wire.type,
            mode: mode,
            title: wire.title.isEmpty ? "投票" : wire.title,
            tips: wire.tips,
            totalParticipants: wire.totalNum,
            totalVotes: wire.totalPoll,
            isPolled: wire.isPolled == 1,
            polledValue: wire.polledValue,
            endTime: wire.endTime,
            rawStatus: wire.status,
            lastTime: wire.lastTime,
            options: options
        )
    }

    private static func mapDimensions(_ rawValue: String) -> ThreadMediaDimensions {
        guard !rawValue.isEmpty else {
            return .fallback(.missing)
        }
        let components = rawValue.split(
            separator: ",",
            omittingEmptySubsequences: false
        )
        guard components.count == 2 else {
            return .fallback(.malformed)
        }
        let width = parseDimension(String(components[0]))
        let height = parseDimension(String(components[1]))
        switch (width, height) {
        case let (.success(width), .success(height)):
            let ratio = Double(width) / Double(height)
            guard ratio >= 0.1, ratio <= 10 else {
                return .fallback(.extremeAspectRatio)
            }
            return .known(width: width, height: height)
        case (.failure(.outOfRange), _), (_, .failure(.outOfRange)):
            return .fallback(.outOfRange)
        case (.failure(.nonPositive), _), (_, .failure(.nonPositive)):
            return .fallback(.nonPositive)
        case (.failure, _), (_, .failure):
            return .fallback(.malformed)
        }
    }

    private enum DimensionParseFailure: Error {
        case malformed
        case nonPositive
        case outOfRange
    }

    private static func parseDimension(
        _ rawValue: String
    ) -> Result<Int, DimensionParseFailure> {
        let trimmed = rawValue.trimmingCharacters(in: .whitespaces)
        guard let parsed = Int64(trimmed) else {
            let unsignedDigits = !trimmed.isEmpty && trimmed.allSatisfy(\.isNumber)
            return .failure(unsignedDigits ? .outOfRange : .malformed)
        }
        guard parsed > 0 else {
            return .failure(.nonPositive)
        }
        guard parsed <= Int64(maximumMediaDimension) else {
            return .failure(.outOfRange)
        }
        return .success(Int(parsed))
    }

    private static func validatedImageCandidates(
        _ rawCandidates: [(ThreadImageCandidateRole, String)]
    ) -> [ThreadImageCandidate] {
        var seen: Set<String> = []
        return rawCandidates.compactMap { role, rawValue in
            guard let destination = validateHTTPSDestination(rawValue),
                  seen.insert(destination.absoluteString).inserted else {
                return nil
            }
            return ThreadImageCandidate(role: role, destination: destination)
        }
    }

    private static func validateHTTPSDestination(
        _ rawValue: String
    ) -> ValidatedWebDestination? {
        guard case let .success(destination) = validateWebDestination(rawValue),
              destination.scheme == .https else {
            return nil
        }
        return destination
    }

    private static func validateWebDestination(
        _ rawValue: String
    ) -> Result<ValidatedWebDestination, ThreadURLRejection> {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.empty)
        }
        guard trimmed.utf8.count <= maximumURLLength else {
            return .failure(.tooLong)
        }
        guard let components = URLComponents(string: trimmed) else {
            return .failure(.malformed)
        }
        guard let rawScheme = components.scheme?.lowercased() else {
            return .failure(.notAbsolute)
        }
        let scheme: ThreadWebScheme
        switch rawScheme {
        case "http":
            scheme = .http
        case "https":
            scheme = .https
        default:
            return .failure(.unsupportedScheme)
        }
        guard components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              let url = components.url,
              url.absoluteURL == url else {
            return .failure(.malformed)
        }
        return .success(ValidatedWebDestination(
            absoluteString: url.absoluteString,
            scheme: scheme
        ))
    }

    private static func validatedVoiceResource(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.utf8.count <= maximumVoiceResourceLength else {
            return nil
        }
        return trimmed
    }

    private static func firstPositive(_ first: Int64, _ second: Int64) -> Int64 {
        if first > 0 {
            return first
        }
        return second > 0 ? second : 0
    }
}
