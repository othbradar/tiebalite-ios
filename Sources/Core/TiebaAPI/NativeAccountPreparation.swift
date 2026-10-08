import Foundation

/// The reference's explicit BDUSS login branch, not its Passport SDK bootstrap.
/// No legacy Android account builder/profile request is used in this path.
enum NativeAccountPreparation {
    static func request(parameters: [String: String], runtime: NativeWriteRuntimeContext) throws -> HTTPRequest {
        guard parameters["bdusstoken"]?.isEmpty == false,
              let url = URL(string: "https://tiebac.baidu.com/c/s/login") else { throw TextWriteFailure.authentication }
        var headers = try runtime.http.cookies.headerFields()
        headers["User-Agent"] = runtime.http.userAgent
        headers["Accept-Language"] = runtime.http.acceptLanguage
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        return try HTTPRequest(method: .post, url: url, headers: headers, body: NativeTBSRequest.encode(parameters),
                               timeout: parameters["net_type"] == "1" ? 10 : 25, responseBodyLimit: 1_024 * 1_024)
    }

    static func decode(_ response: HTTPResponse) throws -> TextWriteAccount {
        guard (200..<300).contains(response.statusCode) else { throw HTTPClientError.server(statusCode: response.statusCode) }
        guard String(data: response.body, encoding: .utf8) != nil,
              let object = try JSONSerialization.jsonObject(with: response.body) as? [String: Any],
              let code = scalar(object["error_code"]).flatMap(Int.init) else { throw TextWriteFailure.malformedResponse }
        guard code == 0 else { throw code == 1 ? TextWriteFailure.authentication : .server(code) }
        guard let user = object["user"] as? [String: Any], let id = scalar(user["id"]),
              Int64(id).map({ $0 > 0 }) == true else { throw TextWriteFailure.malformedResponse }
        let anti = object["anti"] as? [String: Any]
        return TextWriteAccount(userID: id, tbs: scalar(anti?["tbs"]) ?? "", nameShow: scalar(user["name"]) ?? "")
    }

    private static func scalar(_ value: Any?) -> String? {
        if let number = value as? NSNumber { return String(number.int64Value) }
        return value as? String
    }
}
