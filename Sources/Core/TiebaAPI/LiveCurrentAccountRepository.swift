import Foundation

struct LiveCurrentAccountRepository: CurrentAccountRepository {
    let client: any HTTPClient
    let authContextProvider: any AuthContextProviding

    func loadProfile(context: AuthContext) async throws -> UserProfile {
        let authorization = try await authContextProvider.authorization(for: context)
        let executor = EndpointExecutor(client: client, requestBuilder: .init(
            authorizer: ActiveSessionRequestAuthorizer(authContextProvider: authContextProvider)))
        // R09 already verified this account-metadata request. Do not invoke write preparation or nickname mutation.
        let route = try await executor.execute(
            endpoint: TextWriteAccountProtocol.descriptor(), authentication: context,
            body: TextWriteAccountProtocol.body(authorization),
            pipeline: .init(decode: CurrentAccountIdentity.decode, map: { $0 }))
        try Task.checkCancellation()
        _ = try await authContextProvider.authorization(for: context)
        let profile = try await LiveUserProfileRepository(client: client).loadProfile(route: route)
        try Task.checkCancellation()
        _ = try await authContextProvider.authorization(for: context)
        return profile
    }
}

enum CurrentAccountIdentity {
    static func decode(_ data: Data) throws -> UserProfileRoute {
        let response = try JSONDecoder().decode(CurrentAccountIdentityResponse.self, from: data)
        guard response.errorCode == "0" else {
            throw EndpointWireFailure.server(code: Int(response.errorCode ?? "") ?? -1)
        }
        guard let user = response.user, let id = Int64(user.id ?? ""),
              let route = UserProfileRoute(userID: id, fallbackDisplayName: user.name ?? "当前账户",
                                           portraitResourceID: user.portrait) else {
            throw EndpointExecutionError.mapping
        }
        return route
    }
}

private struct CurrentAccountIdentityResponse: Decodable {
    let errorCode: String?
    let user: CurrentAccountIdentityUser?
    enum CodingKeys: String, CodingKey { case errorCode = "error_code", user }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        errorCode = try values.flexibleString(forKey: .errorCode)
        user = try values.decodeIfPresent(CurrentAccountIdentityUser.self, forKey: .user)
    }
}

private struct CurrentAccountIdentityUser: Decodable {
    let id: String?
    let name: String?
    let portrait: String?
    enum CodingKeys: String, CodingKey { case id, name, portrait }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.flexibleString(forKey: .id)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        portrait = try values.decodeIfPresent(String.self, forKey: .portrait)
    }
}
