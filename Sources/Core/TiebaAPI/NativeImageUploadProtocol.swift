import CoreFoundation
import Foundation

/// Ordinary JPEG/GIF upload from the verified iOS 22.11.1 image model.
enum NativeImageUploadProtocol {
    static let chunkSize = 501_760 // Native fallback when imageChunkSize is zero.
    static let receiptSource = "ios-22.11.1"

    static func fields(photo: ComposerPhoto, chunk: Int, final: Bool, forumName: String) -> [String: String] {
        var fields = ["resourceId": photo.id.uppercased(), "isFinish": final ? "1" : "0", "chunkNo": String(chunk),
                      "width": String(photo.width), "height": String(photo.height), "size": String(photo.byteCount),
                      "smallWidth": "0", "smallHeight": "0", "alt": "json", "saveOrigin": "0",
                      "pic_water_type": "3", "is_bjh": "0"]
        if !forumName.isEmpty { fields["small_flow_fname"] = forumName }
        return fields
    }

    static func request(fields: [String: String], bytes: Data, runtime: NativeWriteRuntimeContext) throws -> HTTPRequest {
        guard !bytes.isEmpty, bytes.count <= chunkSize, fields["sign"]?.isEmpty == false,
              fields["_client_type"] == "1", fields["BDUSS"]?.isEmpty == false,
              let url = URL(string: "https://tiebac.baidu.com/c/s/uploadPicture") else {
            throw ImageUploadFailure.invalidImage
        }
        let body = EndpointRequestBody.multipartBinary(
            boundary: runtime.multipartBoundary, fields: fields.keys.sorted().map { .init(name: $0, value: fields[$0] ?? "") },
            part: .init(name: "chunk", filename: "chunk", mimeType: "image/jpeg", data: bytes))
        let encoded = try EndpointRequestBuilder.encode(body, codec: .multipartBinary)
        var headers = try runtime.http.cookies.headerFields()
        headers["User-Agent"] = runtime.http.userAgent
        headers["Accept-Language"] = runtime.http.acceptLanguage
        headers["Content-Type"] = encoded.contentType
        headers["Content-Length"] = String(encoded.data?.count ?? 0)
        if runtime.http.clientLogID != 0 && runtime.http.clientLogID != -1 {
            headers["client_logid"] = String(runtime.http.clientLogID)
        }
        return try HTTPRequest(method: .post, url: url, headers: headers, body: encoded.data,
                               timeout: bytes.count >= 1_024 ? 120 : runtime.http.timeout, responseBodyLimit: 1_024 * 1_024)
    }

    static func decode(_ response: HTTPResponse, final: Bool) throws -> UploadedComposerPhoto? {
        guard (200..<300).contains(response.statusCode) else { throw HTTPClientError.server(statusCode: response.statusCode) }
        guard let object = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any],
              let error = scalar(object["error_code"]).flatMap(Int.init) else { throw ImageUploadFailure.malformedResponse }
        guard error == 0 else { throw ImageUploadFailure.server(error) }
        guard final else { return nil }
        guard let id = scalar(object["picId"]), !id.isEmpty, id.count <= 256,
              id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "_-".contains($0)) }),
              let pictures = object["picInfo"] as? [String: Any], let origin = pictures["originPic"] as? [String: Any],
              let width = scalar(origin["width"]).flatMap(Int.init), let height = scalar(origin["height"]).flatMap(Int.init),
              width > 0, height > 0 else { throw ImageUploadFailure.malformedResponse }
        return .init(picID: id, width: width, height: height, source: receiptSource)
    }

    private static func scalar(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() { return number.stringValue }
        return nil
    }
}
