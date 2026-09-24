import Foundation

enum ImageUploadProtocol {
    static let chunkSize = 512_000

    static func descriptor() throws -> EndpointDescriptor {
        guard let id = EndpointID("write.image") else { throw ImageUploadFailure.unavailable }
        return try EndpointDescriptor(
            id: id, method: .post, host: "c.tieba.baidu.com", path: "/c/s/uploadPicture",
            fixedHeaders: ["User-Agent": "bdtb for Android 12.41.7.1", "Cookie": "ka=open"],
            bodyCodec: .multipartBinary, responseFamily: .json,
            allowedResponseMIMETypes: TextWriteProtocol.jsonResponseMIMETypes,
            authentication: .active, timeout: 60, responseBodyLimit: 1_024 * 1_024, redirectPolicy: .reject, retryPolicy: .never)
    }

    static func body(photo: ComposerPhoto, chunk: Int, bytes: Data, forumName: String,
                     authorization: SessionAuthorization) -> EndpointRequestBody {
        let isFinal = chunk * chunkSize >= photo.byteCount
        let fields = TextWriteProtocol.signedFields([
            "BDUSS": authorization.bduss, "_client_type": "2", "_client_version": "12.41.7.1", "net_type": "1",
            "cmode": "1", "cuid_gid": "", "extra": "", "framework_ver": "3340042", "from": "tieba",
            "is_teenager": "0", "start_scheme": "", "start_type": "1",
            "alt": "json", "chunkNo": String(chunk), "forum_name": forumName, "groupId": "1",
            "height": String(photo.height), "isFinish": isFinal ? "1" : "0", "is_bjh": "0", "pic_water_type": "2",
            "resourceId": photo.id + String(chunkSize), "saveOrigin": "0", "size": String(photo.byteCount),
            "small_flow_fname": forumName, "width": String(photo.width)
        ])
        return .multipartBinary(boundary: PersonalizedProtocol.boundary, fields: fields,
                                part: .init(name: "chunk", filename: "file", mimeType: nil, data: bytes))
    }

    static func decode(_ data: Data, chunk: Int, final: Bool) throws -> UploadedComposerPhoto? {
        do {
            let response = try JSONDecoder().decode(UploadResponse.self, from: data)
            guard let error = response.errorCode.flatMap(Int.init) else { throw ImageUploadFailure.malformedResponse }
            guard error == 0 else { throw ImageUploadFailure.server(error) }
            guard response.chunkNo.flatMap(Int.init) == chunk else { throw ImageUploadFailure.malformedResponse }
            guard final else { return nil }
            guard let id = response.picId, !id.isEmpty, id.count <= 256,
                  id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "_-".contains($0)) }),
                  let origin = response.picInfo?.originPic,
                  let width = origin.width.flatMap(Int.init), let height = origin.height.flatMap(Int.init),
                  width > 0, height > 0 else { throw ImageUploadFailure.malformedResponse }
            return .init(picID: id, width: width, height: height)
        } catch let error as ImageUploadFailure { throw error } catch { throw ImageUploadFailure.malformedResponse }
    }
}

private struct UploadResponse: Decodable {
    let errorCode: String?
    let chunkNo: String?
    let picId: String?
    let picInfo: PictureInfo?
    enum CodingKeys: String, CodingKey { case errorCode = "error_code", chunkNo, picId, picInfo }
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        errorCode = try values.flexibleString(forKey: .errorCode)
        chunkNo = try values.flexibleString(forKey: .chunkNo)
        picId = try values.flexibleString(forKey: .picId)
        picInfo = try values.decodeIfPresent(PictureInfo.self, forKey: .picInfo)
    }
}
private struct PictureInfo: Decodable { let originPic: PictureSize }
private struct PictureSize: Decodable {
    let width: String?
    let height: String?
    enum CodingKeys: CodingKey { case width, height }
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        width = try values.flexibleString(forKey: .width)
        height = try values.flexibleString(forKey: .height)
    }
}
