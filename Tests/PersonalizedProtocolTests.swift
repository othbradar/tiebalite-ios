import Foundation
import GeneratedProtobuf
import SwiftProtobuf
import Testing
@testable import TiebaLite

struct PersonalizedProtocolTests {
    @Test
    func requestContractHasGoldenProtobufAndExactMultipartEnvelope() async throws {
        let input = try PersonalizedRequestInput(loadKind: .refresh, page: 1)
        let protobuf = try PersonalizedProtocol.encodeRequest(input)
        let golden = requestGolden()
        #expect(protobuf == golden)

        let descriptor = try PersonalizedProtocol.makeDescriptor(
            host: "fixture.invalid"
        )
        let request = try await EndpointRequestBuilder(
            authorizer: AnonymousRequestAuthorizer()
        ).makeRequest(
            endpoint: descriptor,
            authentication: .anonymous,
            body: try PersonalizedProtocol.makeRequestBody(input)
        )

        var expectedBody = Data()
        expectedBody.append(Data("--\(PersonalizedProtocol.boundary)\r\n".utf8))
        expectedBody.append(
            Data(
                (
                    "Content-Disposition: form-data; name=\"data\"; " +
                        "filename=\"file\"\r\n\r\n"
                ).utf8
            )
        )
        expectedBody.append(golden)
        expectedBody.append(
            Data("\r\n--\(PersonalizedProtocol.boundary)--\r\n".utf8)
        )

        #expect(
            request.url.absoluteString ==
                "https://fixture.invalid/c/f/excellent/personalized?cmd=309264"
        )
        #expect(request.headers["Charset"] == "UTF-8")
        let expectedUserAgent =
            "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Version/4.0 Chrome/135.0.0.0 " +
            "Mobile Safari/537.36 tieba/12.52.1.0"
        #expect(request.headers["User-Agent"] == expectedUserAgent)
        #expect(request.headers["client_type"] == "2")
        #expect(request.headers["x_bd_data_type"] == "protobuf")
        #expect(request.headers["X-BD-Data-Type"] == nil)
        #expect(
            request.headers["Content-Type"] ==
                "multipart/form-data; boundary=\(PersonalizedProtocol.boundary)"
        )
        #expect(request.headers["Authorization"] == nil)
        #expect(request.headers["Cookie"] == nil)
        #expect(request.body == expectedBody)

        let decoded = try Tieba_PersonalizedRequest(
            serializedBytes: protobuf
        )
        #expect(decoded.data.common.from == "1020031h")
        #expect(descriptor.redirectPolicy == .reject)
        #expect(descriptor.retryPolicy == .never)

        #expect(throws: PersonalizedProtocolError.invalidPage) {
            try PersonalizedRequestInput(loadKind: .refresh, page: 0)
        }
    }

    private func requestGolden() -> Data {
        Data([
            0x0A, 0xB7, 0x01, 0x0A, 0xA9, 0x01, 0x08, 0x02,
            0x12, 0x09, 0x31, 0x32, 0x2E, 0x35, 0x32, 0x2E,
            0x31, 0x2E, 0x30, 0x32, 0x08, 0x31, 0x30, 0x32,
            0x30, 0x30, 0x33, 0x31, 0x68, 0xF2, 0x03, 0x8B,
            0x01, 0x4D,
            0x6F, 0x7A, 0x69, 0x6C, 0x6C, 0x61, 0x2F, 0x35,
            0x2E, 0x30, 0x20, 0x28, 0x4C, 0x69, 0x6E, 0x75,
            0x78, 0x3B, 0x20, 0x41, 0x6E, 0x64, 0x72, 0x6F,
            0x69, 0x64, 0x20, 0x31, 0x30, 0x3B, 0x20, 0x4B,
            0x29, 0x20, 0x41, 0x70, 0x70, 0x6C, 0x65, 0x57,
            0x65, 0x62, 0x4B, 0x69, 0x74, 0x2F, 0x35, 0x33,
            0x37, 0x2E, 0x33, 0x36, 0x20, 0x28, 0x4B, 0x48,
            0x54, 0x4D, 0x4C, 0x2C, 0x20, 0x6C, 0x69, 0x6B,
            0x65, 0x20, 0x47, 0x65, 0x63, 0x6B, 0x6F, 0x29,
            0x20, 0x56, 0x65, 0x72, 0x73, 0x69, 0x6F, 0x6E,
            0x2F, 0x34, 0x2E, 0x30, 0x20, 0x43, 0x68, 0x72,
            0x6F, 0x6D, 0x65, 0x2F, 0x31, 0x33, 0x35, 0x2E,
            0x30, 0x2E, 0x30, 0x2E, 0x30, 0x20, 0x4D, 0x6F,
            0x62, 0x69, 0x6C, 0x65, 0x20, 0x53, 0x61, 0x66,
            0x61, 0x72, 0x69, 0x2F, 0x35, 0x33, 0x37, 0x2E,
            0x33, 0x36, 0x20, 0x74, 0x69, 0x65, 0x62, 0x61,
            0x2F, 0x31, 0x32, 0x2E, 0x35, 0x32, 0x2E, 0x31,
            0x2E, 0x30, 0xF8, 0x03, 0x01, 0x20, 0x01, 0x28,
            0x0B, 0x30, 0x01, 0x58, 0x01, 0xB8, 0x01, 0x01
        ])
    }

    @Test
    func crossLanguageFixtureMapsInServerOrderWithoutCanonicalIDGuessing() throws {
        let bytes = try fixtureData()
        let response = try PersonalizedProtocol.decode(bytes)
        #expect(response.hasError)
        #expect(response.hasData)
        #expect(!response.data.threadList[0].hasVideoInfo)
        #expect(response.data.threadList[1].hasVideoInfo)

        let page = try fixtureAdapter(requestedPage: 1).map(
            bytes,
            mimeType: PersonalizedProtocol.fixtureResponseMIMEType
        )
        #expect(page.requestedPage == 1)
        #expect(page.nextPageCandidate == 2)
        #expect(page.terminal == .unknown)
        #expect(page.items.map(\.rawFeedID) == [1001, 1002])
        #expect(page.items.map(\.rawThreadID) == [2001, 2002])
        #expect(page.items[0].rawAuthorID == 7001)
        #expect(page.items[0].author?.nameShow == "Fixture Author")
        #expect(page.items[1].rawThreadType == 999)
        #expect(page.items[1].author == nil)
        #expect(page.items[1].hasVideo)
        #expect(!page.items[1].hasLive)
    }

    @Test
    func envelopePresenceSeparatesEmptyMissingDataAndServerFailure() throws {
        var empty = Tieba_PersonalizedResponse()
        empty.error = Tieba_Error()
        empty.data = Tieba_PersonalizedResponseData()
        let emptyPage = try fixtureAdapter(requestedPage: 4).map(
            try empty.serializedData(),
            mimeType: PersonalizedProtocol.fixtureResponseMIMEType
        )
        #expect(emptyPage.items.isEmpty)
        #expect(emptyPage.terminal == .unknown)
        #expect(emptyPage.nextPageCandidate == 5)

        var missingData = Tieba_PersonalizedResponse()
        missingData.error = Tieba_Error()
        #expect(
            throws: EndpointExecutionError.mapping
        ) {
            try fixtureAdapter(requestedPage: 1).map(
                try missingData.serializedData(),
                mimeType: PersonalizedProtocol.fixtureResponseMIMEType
            )
        }

        var error = Tieba_Error()
        error.errorCode = 17
        error.errorMsg = "synthetic private server text"
        var failed = Tieba_PersonalizedResponse()
        failed.error = error
        #expect(
            throws: EndpointExecutionError.server(code: 17)
        ) {
            try fixtureAdapter(requestedPage: 1).map(
                try failed.serializedData(),
                mimeType: PersonalizedProtocol.fixtureResponseMIMEType
            )
        }
    }

    @Test
    func optionalDefaultPresenceSurvivesRoundTrip() throws {
        let absent = Tieba_AppPosInfo()
        var explicitDefault = Tieba_AppPosInfo()
        explicitDefault.apConnected = false

        #expect(!absent.hasApConnected)
        #expect(explicitDefault.hasApConnected)
        #expect(try absent.serializedData() != explicitDefault.serializedData())

        let decoded = try Tieba_AppPosInfo(
            serializedBytes: explicitDefault.serializedData()
        )
        #expect(decoded.hasApConnected)
        #expect(decoded.apConnected == false)
        var cleared = decoded
        cleared.clearApConnected()
        #expect(!cleared.hasApConnected)
    }

    @Test
    func unknownFieldAndRawUnknownCategorySurviveRoundTrip() throws {
        let originalBytes = try fixtureData()
        let originalPage = try fixtureAdapter(requestedPage: 1).map(
            originalBytes,
            mimeType: PersonalizedProtocol.fixtureResponseMIMEType
        )
        var extendedBytes = originalBytes
        extendedBytes.append(contentsOf: [0xF8, 0x7F, 0x01])

        let decoded = try PersonalizedProtocol.decode(extendedBytes)
        #expect(decoded.unknownFields != SwiftProtobuf.UnknownStorage())
        let reencoded = try decoded.serializedData()
        let decodedAgain = try PersonalizedProtocol.decode(reencoded)
        #expect(decodedAgain.unknownFields == decoded.unknownFields)

        let extendedPage = try PersonalizedProtocol.map(
            decodedAgain,
            requestedPage: 1
        )
        #expect(extendedPage == originalPage)
        #expect(extendedPage.items[1].rawThreadType == 999)
    }

    @Test
    func emptyAndMalformedBodiesRemainDecodeFailures() throws {
        for malformed in [
            Data(),
            Data([0x12, 0x05, 0x0A]),
            Data([0x80])
        ] {
            #expect(throws: EndpointExecutionError.decode) {
                try fixtureAdapter(requestedPage: 1).map(
                    malformed,
                    mimeType: PersonalizedProtocol.fixtureResponseMIMEType
                )
            }
        }
    }

    @Test
    func structuredTaskReturnsOnlySendableDomainValues() async throws {
        let bytes = try fixtureData()
        let adapter = try fixtureAdapter(requestedPage: UInt32.max)
        let page = try await Task {
            try adapter.map(
                bytes,
                mimeType: PersonalizedProtocol.fixtureResponseMIMEType
            )
        }.value

        #expect(page.items.count == 2)
        #expect(page.nextPageCandidate == nil)
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: FixtureBundleMarker.self)
        let root = try #require(
            bundle.url(forResource: "Fixtures", withExtension: nil)
        )
        return try FixtureLoader(rootDirectory: root).loadData(
            id: FixtureID("recommendations.personalized.cross-language"),
            expectedFormat: .protobuf
        )
    }

    private func fixtureAdapter(
        requestedPage: UInt32
    ) throws -> FixtureEndpointAdapter<
        Tieba_PersonalizedResponse,
        RecommendationPage
    > {
        try FixtureEndpointAdapter(
            endpoint: PersonalizedProtocol.makeDescriptor(host: "fixture.invalid"),
            pipeline: PersonalizedProtocol.pipeline(requestedPage: requestedPage)
        )
    }
}
