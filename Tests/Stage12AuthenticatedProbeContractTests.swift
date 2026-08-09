import Foundation
import GeneratedProtobuf
import Testing
@testable import TiebaLite

struct Stage12AuthenticatedProbeContractTests {
    @Test
    func authenticatedPersonalizedBodyUsesTheActiveLeaseFieldsWithoutChangingAnonymousGolden() throws {
        let input = try PersonalizedRequestInput(loadKind: .refresh, page: 1)
        let anonymous = try PersonalizedProtocol.encodeRequest(input)
        let authorization = SessionAuthorization(
            bduss: "fx-auth-b",
            stoken: "fx-auth-s"
        )
        let body = try PersonalizedProtocol.makeAuthenticatedRequestBody(
            input,
            authorization: authorization
        )

        guard case let .multipartBinary(_, fields, part) = body else {
            Issue.record("Authenticated probe changed multipart body family")
            return
        }
        let request = try Tieba_PersonalizedRequest(
            serializedBytes: part.data
        )
        #expect(request.data.common.bduss == "fx-auth-b")
        #expect(request.data.common.stoken == "fx-auth-s")
        #expect(fields == [
            EndpointField(name: "stoken", value: "fx-auth-s")
        ])
        #expect(try PersonalizedProtocol.encodeRequest(input) == anonymous)
        #expect(
            try PersonalizedProtocol.makeActiveDescriptor(
                host: "fixture.invalid"
            ).authentication == .active
        )
    }

#if DEBUG
    @Test
    func decodedServerFailureIsReportedAsTypedServerOutcome() throws {
        var error = Tieba_Error()
        error.errorCode = 17
        var response = Tieba_PersonalizedResponse()
        response.error = error
        let endpoint = try PersonalizedProtocol.makeActiveDescriptor(
            host: "fixture.invalid"
        )

        let result = DebugAuthenticatedSessionProbe.map(
            response: HTTPResponse(
                statusCode: 200,
                headers: [
                    "content-type": PersonalizedProtocol.liveResponseMIMEType
                ],
                body: try response.serializedData()
            ),
            endpoint: endpoint
        )

        #expect(result.decoded)
        #expect(result.itemCount == nil)
        #expect(result.outcome == .server)
    }
#endif
}
