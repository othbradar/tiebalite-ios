import Foundation

/// The owned temporary file lives exactly as long as its in-session draft references.
final class ComposerPhotoFile: Sendable, Equatable {
    let url: URL
    init(url: URL) { self.url = url }
    deinit { try? FileManager.default.removeItem(at: url) }
    static func == (lhs: ComposerPhotoFile, rhs: ComposerPhotoFile) -> Bool { lhs.url == rhs.url }
}

struct ComposerPhoto: Identifiable, Equatable, Sendable {
    static let limit = 9
    let id: String
    let file: ComposerPhotoFile
    let width: Int
    let height: Int
    let byteCount: Int
    var uploaded: UploadedComposerPhoto?
}

struct UploadedComposerPhoto: Equatable, Sendable {
    let picID: String
    let width: Int
    let height: Int
    var token: String { "#(pic,\(picID),\(width),\(height))" }
}

enum ImageUploadFailure: Error, Equatable, Sendable {
    case invalidImage, tooLarge, unavailable, server(Int), malformedResponse
    var message: String {
        switch self {
        case .invalidImage: "无法读取这张图片，请重新选择。"
        case .tooLarge: "图片过大，请选择较小图片。"
        case .unavailable: "图片上传失败，请重试。文字和图片已保留。"
        case .server(let code): "图片上传失败（服务端代码 \(code)），草稿已保留。"
        case .malformedResponse: "未获得有效图片信息，尚未发布。请重试上传。"
        }
    }
}

protocol ComposerImageUploading: Sendable {
    func upload(_ photo: ComposerPhoto, forumName: String, context: AuthContext,
                progress: @escaping @Sendable (Double) async -> Void) async throws -> UploadedComposerPhoto
}

struct UnavailableComposerUploader: ComposerImageUploading {
    func upload(_ photo: ComposerPhoto, forumName: String, context: AuthContext,
                progress: @escaping @Sendable (Double) async -> Void) async throws -> UploadedComposerPhoto {
        throw ImageUploadFailure.unavailable
    }
}

enum ComposerInsertion {
    static func insert(_ token: String, into text: String, selection: NSRange) -> (text: String, selection: NSRange) {
        let original = text as NSString
        let location = min(max(0, selection.location), original.length)
        let range = NSRange(location: location, length: min(max(0, selection.length), original.length - location))
        return (original.replacingCharacters(in: range, with: token), NSRange(location: location + token.utf16.count, length: 0))
    }
}
