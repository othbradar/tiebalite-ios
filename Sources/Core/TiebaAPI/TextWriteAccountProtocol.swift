import Foundation

enum TextWriteAccountProtocol {
    static func descriptor() throws -> EndpointDescriptor {
        guard let id = EndpointID("write.accountMetadata") else { throw TextWriteFailure.authentication }
        return try EndpointDescriptor(id: id, method: .post, host: "c.tieba.baidu.com", path: "/c/s/login",
                                      fixedHeaders: ["User-Agent": "bdtb for Android 11.10.8.6", "Cookie": "ka=open"],
                                      bodyCodec: .formURLEncoded, responseFamily: .json,
                                      allowedResponseMIMETypes: TextWriteProtocol.jsonResponseMIMETypes,
                                      authentication: .active, timeout: 30, responseBodyLimit: 1_024 * 1_024)
    }

    static func body(_ authorization: SessionAuthorization) -> EndpointRequestBody {
        .formURLEncoded(TextWriteProtocol.signedFields([
            "bdusstoken": authorization.bduss + "|null", "stoken": authorization.stoken,
            "channel_id": "", "channel_uid": "", "authsid": "null",
            "_client_version": "11.10.8.6", "_client_type": "2"
        ]))
    }

    static func decode(_ data: Data) throws -> TextWriteAccount {
        let response = try JSONDecoder().decode(AccountResponse.self, from: data)
        guard response.errorCode == "0" else {
            throw EndpointWireFailure.server(code: Int(response.errorCode ?? "") ?? -1)
        }
        guard let tbs = response.anti?.tbs, !tbs.isEmpty,
              let uid = response.user?.id, let numericID = Int64(uid), numericID > 0 else {
            throw TextWriteFailure.authentication
        }
        return TextWriteAccount(userID: uid, tbs: tbs)
    }

    static func addingDisplayName(to account: TextWriteAccount, client: any HTTPClient) async throws -> TextWriteAccount {
        guard let uid = Int64(account.userID),
              let route = UserProfileRoute(userID: uid, fallbackDisplayName: "") else {
            throw TextWriteFailure.authentication
        }
        let executor = EndpointExecutor(client: client, requestBuilder: .init(authorizer: AnonymousRequestAuthorizer()))
        return try await executor.execute(
            endpoint: ProfileProtocol.makeDescriptor(host: "tiebac.baidu.com"), authentication: .anonymous,
            body: ProfileProtocol.makeRequestBody(route: route),
            pipeline: .init(decode: ProfileProtocol.decode, map: { response in
                guard response.hasData, response.data.hasUser, response.data.user.id == uid else {
                    throw ProfileProtocolError.identityMismatch
                }
                var result = account
                // The wire display name is distinct from login name and UI fallback labels.
                // Android AddPost uses an empty string when this optional field is absent.
                result.nameShow = response.data.user.nameShow
                return result
            }))
    }

}

private struct AccountResponse: Decodable {
    struct Anti: Decodable { let tbs: String? }
    struct User: Decodable { let id: String? }
    let errorCode: String?
    let anti: Anti?
    let user: User?
    enum CodingKeys: String, CodingKey { case errorCode = "error_code", anti, user }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        errorCode = try values.flexibleString(forKey: .errorCode)
        anti = try values.decodeIfPresent(Anti.self, forKey: .anti)
        user = try values.decodeIfPresent(User.self, forKey: .user)
    }
}
