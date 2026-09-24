#if UITESTING
import Foundation

actor FixtureComposerImageUploader: ComposerImageUploading {
    private var failed = false
    private var pending: CheckedContinuation<Void, Error>?

    func finishSample() {
        pending?.resume(throwing: ImageUploadFailure.unavailable)
        pending = nil
    }

    func upload(_ photo: ComposerPhoto, forumName: String, context: AuthContext,
                progress: @escaping @Sendable (Double) async -> Void) async throws -> UploadedComposerPhoto {
        if !failed {
            failed = true
            await progress(0.5)
            try await withTaskCancellationHandler {
                try Task.checkCancellation()
                try await withCheckedThrowingContinuation { pending = $0 }
            } onCancel: { Task { await self.cancel() } }
        }
        await progress(1)
        return .init(picID: "fixture_" + photo.id, width: photo.width, height: photo.height)
    }

    private func cancel() {
        pending?.resume(throwing: CancellationError())
        pending = nil
    }
}
#endif
