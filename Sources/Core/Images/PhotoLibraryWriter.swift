import Foundation
import Photos

struct PhotoLibraryWriter: PhotoLibraryWriting {
    func authorizeAddOnly() async throws {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let status = current == .notDetermined ? await PHPhotoLibrary.requestAuthorization(for: .addOnly) : current
        try Task.checkCancellation()
        guard status == .authorized || status == .limited else { throw ImageExportFailure.permissionDenied }
    }

    func write(_ file: ImageExportFile) async throws {
        try Task.checkCancellation()
        do {
            // PhotoKit consumes the original encoded file. Never convert it to UIImage/JPEG.
            // Once submitted this is not cancellable: retain the file until the completion callback.
            try await PHPhotoLibrary.shared().performChanges {
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false
                options.uniformTypeIdentifier = file.typeIdentifier
                PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: file.url, options: options)
            }
        } catch {
            let permission = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            if permission == .denied || permission == .restricted { throw ImageExportFailure.permissionDenied }
            let failure = error as NSError
            if failure.domain == PHPhotosErrorDomain && failure.code == PHPhotosError.Code.invalidResource.rawValue {
                throw ImageExportFailure.unsupportedFormat
            }
            throw ImageExportFailure.write
        }
    }
}
