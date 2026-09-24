import Foundation

actor LiveComposerImageUploader: ComposerImageUploading {
    let client: any HTTPClient
    let authContextProvider: any AuthContextProviding

    init(client: any HTTPClient, authContextProvider: any AuthContextProviding) {
        self.client = client
        self.authContextProvider = authContextProvider
    }

    func upload(_ photo: ComposerPhoto, forumName: String, context: AuthContext,
                progress: @escaping @Sendable (Double) async -> Void) async throws -> UploadedComposerPhoto {
        guard photo.byteCount > 0, photo.byteCount <= 5_242_880, photo.width > 0, photo.height > 0 else {
            throw ImageUploadFailure.invalidImage
        }
        let executor = EndpointExecutor(client: client, requestBuilder: EndpointRequestBuilder(
            authorizer: ActiveSessionRequestAuthorizer(authContextProvider: authContextProvider)))
        let file = try FileHandle(forReadingFrom: photo.file.url)
        defer { try? file.close() }
        let total = (photo.byteCount + ImageUploadProtocol.chunkSize - 1) / ImageUploadProtocol.chunkSize
        for chunk in 1...total {
            try Task.checkCancellation()
            let auth = try await authContextProvider.authorization(for: context)
            let count = min(ImageUploadProtocol.chunkSize, photo.byteCount - (chunk - 1) * ImageUploadProtocol.chunkSize)
            guard let bytes = try file.read(upToCount: count), bytes.count == count else {
                throw ImageUploadFailure.invalidImage
            }
            let responseBytes = try await executor.execute(
                endpoint: ImageUploadProtocol.descriptor(), authentication: context,
                body: ImageUploadProtocol.body(photo: photo, chunk: chunk, bytes: bytes, forumName: forumName, authorization: auth),
                pipeline: EndpointPipeline(decode: { $0 }, map: { $0 }))
            let response = try ImageUploadProtocol.decode(responseBytes, chunk: chunk, final: chunk == total)
            try Task.checkCancellation()
            _ = try await authContextProvider.authorization(for: context)
            await progress(Double(min(chunk * ImageUploadProtocol.chunkSize, photo.byteCount)) / Double(photo.byteCount))
            if let response { return response }
        }
        throw ImageUploadFailure.malformedResponse
    }
}
