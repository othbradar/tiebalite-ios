import Foundation

/// Captured by the action, never looked up again using the Viewer's changing selection.
struct ImageExportRequest: Equatable, Sendable {
    let mediaID: String
    let position: Int
    let descriptor: ThreadImageRequestDescriptor
}

struct ImageExportFile: Equatable, Sendable {
    let request: ImageExportRequest
    let url: URL
    let directory: URL
    let typeIdentifier: String
    let isOriginal: Bool
}

enum ImageExportFailure: Error, Equatable, Sendable {
    case originalUnavailable
    case permissionDenied
    case download
    case filePreparation
    case unsupportedFormat
    case write

    var message: String {
        switch self {
        case .originalUnavailable: "原图不可用，未保存缩略图；可以分享可用版本"
        case .permissionDenied: "没有添加照片的权限，请在设置中允许后重试"
        case .download: "图片下载失败，请重试"
        case .filePreparation: "无法准备图片文件，请检查可用空间后重试"
        case .unsupportedFormat: "相册不支持此格式，可分享或存储到文件"
        case .write: "写入相册失败，请重试，或存储到文件"
        }
    }
}

protocol ImageFileFetching: Sendable {
    func fetch(_ request: ImageExportRequest) async throws -> ImageExportFile
    func remove(_ file: ImageExportFile) async
}

protocol PhotoLibraryWriting: Sendable {
    func authorizeAddOnly() async throws
    /// Returns only after the photo library has finished using the file.
    func write(_ file: ImageExportFile) async throws
}

// Uses only original roles supplied by the mapper; never synthesizes a CDN address.
extension ThreadImageRequestDescriptor {
    var originalOnly: Self {
        Self(resourceID: resourceID, candidates: candidates.filter { $0.role == .original })
    }
}
