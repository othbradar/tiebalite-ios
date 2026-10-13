import Foundation

/// iOS 22.11.1 TBCFavoriateModel ordinary JSON/form requests. No Android
/// request builder, Protobuf transport or text-write state is used here.
enum NativeFavoriteRequest {
    enum Operation: Sendable {
        case list(Int), save(ThreadFavorite), remove(Int64)
        var path: String {
            switch self {
            case .list: "/c/f/post/threadstore"
            case .save: "/c/c/post/addstore"
            case .remove: "/c/c/post/rmstore"
            }
        }
        var isWrite: Bool { if case .list = self { return false }; return true }
        func business(userID: String) throws -> [String: String] {
            guard Int64(userID).map({ $0 > 0 }) == true else { throw FavoriteFailure.accountUnavailable }
            switch self {
            case let .list(offset):
                guard offset >= 0 else { throw FavoriteFailure.invalidData }
                return ["rn": "20", "offset": String(offset), "user_id": userID]
            case let .save(entry):
                guard entry.id > 0, let pid = entry.target.postID, pid > 0, !entry.isDeleted else { throw FavoriteFailure.invalidData }
                let records = [["tid": String(entry.id), "pid": String(pid), "status": String(entry.status)]]
                let data = try JSONSerialization.data(withJSONObject: records, options: [.sortedKeys])
                guard let json = String(data: data, encoding: .utf8) else { throw FavoriteFailure.invalidData }
                return ["data": json]
            case let .remove(id):
                guard id > 0 else { throw FavoriteFailure.invalidData }
                // Native deleteFavoriate:forumID: uses "0" when no forum ID is available.
                return ["tid": String(id), "fid": "0"]
            }
        }
    }

    static func make(_ operation: Operation, account: String, runtime: NativeWriteRuntimeContext) throws -> HTTPRequest {
        let business = try operation.business(userID: account)
        var parameters = NativeWriteStaticCommonParameters()
        let fields = parameters.parameters(runtime.common.staticValues, mode: runtime.common.staticMode)
        var metrics = NativeWriteRequestMetrics(api: nil, logID: 0, cost: 0, result: 0, uploadBytes: 0, downloadBytes: 0)
        // All three paths and TBS take the same ordinary Common branch. The
        // runtime value is only provider data; this does not request TBS/login.
        let common = NativeWriteDynamicCommonParameters.prepare(
            staticFields: fields, business: business, context: runtime.common.dynamicValues, metrics: &metrics)
        let signed = NativeWriteSigning.tbsForm(common, business: business)
        guard signed["BDUSS"]?.isEmpty == false else { throw FavoriteFailure.accountUnavailable }
        var headers = try runtime.http.cookies.headerFields()
        headers["User-Agent"] = runtime.http.userAgent
        headers["Accept-Language"] = runtime.http.acceptLanguage
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        if runtime.http.clientLogID != 0 && runtime.http.clientLogID != -1 { headers["client_logid"] = String(runtime.http.clientLogID) }
        guard let url = URL(string: "https://tiebac.baidu.com" + operation.path) else { throw FavoriteFailure.invalidData }
        return try HTTPRequest(method: .post, url: url, headers: headers, body: NativeTBSRequest.encode(signed),
                               timeout: signed["net_type"] == "1" ? 10 : 25, responseBodyLimit: 2 * 1_024 * 1_024)
    }
}
