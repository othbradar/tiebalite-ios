import Foundation
import GeneratedProtobuf
import SwiftProtobuf

enum ProfileProtocolError: Error, Equatable, Sendable {
    case emptyBody
    case identityMismatch
    case invalidStaticConfiguration
    case missingData
    case missingUser
}

enum ProfileProtocol {
    enum RepositoryMapping: Sendable {
        case empty
        case loaded(UserProfile)
    }

    struct WireInspection: Equatable, Sendable {
        let decoded: Bool
        let hasServerError: Bool
        let displayFieldCount: Int
    }

    static let boundary = PersonalizedProtocol.boundary
    static let fixtureResponseMIMEType = "application/x-protobuf"
    static let liveResponseMIMEType = "application/octet-stream"

    static func makeDescriptor(host: String) throws -> EndpointDescriptor {
        guard let identifier = EndpointID("user.profile") else {
            throw ProfileProtocolError.invalidStaticConfiguration
        }
        return try EndpointDescriptor(
            id: identifier,
            method: .post,
            host: host,
            path: "/c/u/user/profile",
            queryItems: [
                EndpointField(name: "cmd", value: "303012"),
                EndpointField(name: "format", value: "protobuf")
            ],
            fixedHeaders: PersonalizedProtocol.anonymousV12Headers,
            bodyCodec: .multipartBinary,
            responseFamily: .protobuf,
            allowedResponseMIMETypes: [
                fixtureResponseMIMEType,
                liveResponseMIMEType
            ],
            authentication: .anonymous,
            timeout: 30,
            responseBodyLimit: 8 * 1_024 * 1_024,
            redirectPolicy: .reject,
            retryPolicy: .never
        )
    }

    static func encodeRequest(route: UserProfileRoute) throws -> Data {
        var common = Tieba_CommonRequest()
        common.clientType = 2
        common.clientVersion = PersonalizedProtocol.androidClientVersion
        common.from = "1020031h"
        common.userAgent = PersonalizedProtocol.androidUserAgent
        common.personalizedRecSwitch = 1

        var data = Tieba_Profile_ProfileRequestData()
        data.common = common
        data.friendUid = route.userID.rawValue
        data.friendUidPortrait = ""
        data.hasPlist_p = 1
        data.isFromUsercenter = 1
        data.isGuest = 1
        data.needPostCount = 1
        data.page = 1
        data.pn = 1
        data.qType = 0
        data.rn = 20

        var request = Tieba_Profile_ProfileRequest()
        request.data = data
        var options = BinaryEncodingOptions()
        options.useDeterministicOrdering = true
        return try request.serializedData(options: options)
    }

    static func makeRequestBody(
        route: UserProfileRoute
    ) throws -> EndpointRequestBody {
        .multipartBinary(
            boundary: boundary,
            fields: [],
            part: MultipartBinaryPart(
                name: "data",
                filename: "file",
                mimeType: nil,
                data: try encodeRequest(route: route)
            )
        )
    }

    static func decode(_ bytes: Data) throws -> Tieba_Profile_ProfileResponse {
        guard !bytes.isEmpty else {
            throw ProfileProtocolError.emptyBody
        }
        let response = try Tieba_Profile_ProfileResponse(
            serializedBytes: bytes
        )
        if response.hasError, response.error.errorCode != 0 {
            throw EndpointWireFailure.server(
                code: Int(response.error.errorCode)
            )
        }
        return response
    }

    static func map(
        _ response: Tieba_Profile_ProfileResponse,
        requestedRoute: UserProfileRoute
    ) throws -> UserProfile {
        guard response.hasData else {
            throw ProfileProtocolError.missingData
        }
        guard response.data.hasUser else {
            throw ProfileProtocolError.missingUser
        }
        let user = response.data.user
        guard user.id == requestedRoute.userID.rawValue else {
            throw ProfileProtocolError.identityMismatch
        }
        let displayName = nonempty(
            user.nameShow,
            fallback: nonempty(
                user.name,
                fallback: requestedRoute.fallbackDisplayName
            )
        )
        return UserProfile(
            userID: requestedRoute.userID,
            displayName: displayName,
            portraitResourceID: nonempty(user.portrait)
                ?? requestedRoute.portraitResourceID,
            introduction: nonempty(user.intro),
            sex: mapSex(user.sex),
            followingCount: Int(max(0, user.concernNum)),
            followerCount: Int(max(0, user.fansNum)),
            postCount: Int(max(0, user.postNum)),
            threadCount: Int(max(0, user.threadNum)),
            totalAgreeCount: Int(user.totalAgreeNum),
            displayTiebaID: nonempty(user.tiebaUid)
        )
    }

    static func pipeline(
        requestedRoute: UserProfileRoute
    ) -> EndpointPipeline<Tieba_Profile_ProfileResponse, RepositoryMapping> {
        EndpointPipeline(
            decode: decode,
            map: { response in
                guard response.hasData, response.data.hasUser else {
                    return .empty
                }
                return .loaded(try map(
                    response,
                    requestedRoute: requestedRoute
                ))
            }
        )
    }

    static func inspectForDiagnostics(_ bytes: Data) -> WireInspection {
        guard !bytes.isEmpty,
              let response = try? Tieba_Profile_ProfileResponse(
                  serializedBytes: bytes
              ) else {
            return WireInspection(
                decoded: false,
                hasServerError: false,
                displayFieldCount: 0
            )
        }
        let user = response.hasData && response.data.hasUser
            ? response.data.user
            : nil
        return WireInspection(
            decoded: true,
            hasServerError: response.hasError && response.error.errorCode != 0,
            displayFieldCount: user.map { displayFieldCount($0) } ?? 0
        )
    }

    private static func displayFieldCount(_ user: Tieba_User) -> Int {
        [
            user.id > 0,
            !user.name.isEmpty || !user.nameShow.isEmpty,
            !user.portrait.isEmpty,
            !user.intro.isEmpty,
            user.sex == 1 || user.sex == 2,
            user.concernNum > 0,
            user.fansNum > 0,
            user.postNum > 0,
            user.threadNum > 0,
            user.totalAgreeNum > 0,
            !user.tiebaUid.isEmpty
        ].filter { $0 }.count
    }

    private static func mapSex(_ rawValue: Int32) -> UserProfileSex? {
        switch rawValue {
        case 1:
            .male
        case 2:
            .female
        default:
            nil
        }
    }

    private static func nonempty(
        _ value: String,
        fallback: String
    ) -> String {
        nonempty(value) ?? fallback
    }

    private static func nonempty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
