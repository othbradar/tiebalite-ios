import Foundation
import Testing
@testable import TiebaLite

@Suite("Stage 19A production image loader")
struct ProductionImageLoaderTests {
    private struct InvalidTargetInput {
        let width: Double
        let height: Double
        let scale: Double
    }

    @Test
    func validImageUsesAnonymousRequestAndDownsamplesToTarget() async throws {
        let url = try #require(URL(string: "https://images.fixture.invalid/large.png"))
        let data = try TestImageFixtureFactory.png(width: 1_200, height: 800)
        let transport = HarnessImageDataLoader(outcomes: [
            url: [.response(
                statusCode: 200,
                headers: ["Content-Type": "image/png"],
                body: data
            )]
        ])
        let loader = ProductionImageLoader(loader: transport)

        let payload = try await loader.load(request(
            id: "large",
            urls: [url],
            target: ImageTargetPixelSize(width: 300, height: 200)
        ))

        #expect(payload.decodedImage != nil)
        #expect(payload.pixelSize == ImageTargetPixelSize(width: 300, height: 200))
        let sent = try #require(await transport.recordedRequests().first)
        #expect(sent.value(forHTTPHeaderField: "Cookie") == nil)
        #expect(sent.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(!sent.httpShouldHandleCookies)
    }

    @Test
    func extremeAspectFillStaysInsideTheRequestedPixelBox() async throws {
        let url = try #require(URL(
            string: "https://images.fixture.invalid/extreme.png"
        ))
        let data = try TestImageFixtureFactory.png(width: 12_000, height: 100)
        let transport = HarnessImageDataLoader(outcomes: [
            url: [.response(
                statusCode: 200,
                headers: ["Content-Type": "image/png"],
                body: data
            )]
        ])
        let loader = ProductionImageLoader(loader: transport)
        let target = ImageTargetPixelSize(width: 300, height: 300)

        let payload = try await loader.load(request(
            id: "extreme-fill",
            urls: [url],
            target: target,
            resizeMode: .fill
        ))
        let image = try #require(payload.decodedImage?.cgImage)

        #expect(image.width <= target.width)
        #expect(image.height <= target.height)
        #expect(payload.pixelSize == ImageTargetPixelSize(
            width: image.width,
            height: image.height
        ))
    }

    @Test(arguments: [
        (404, ImageLoadingError.httpStatus(404)),
        (503, ImageLoadingError.httpStatus(503))
    ])
    func httpFailuresRemainTyped(
        statusCode: Int,
        expected: ImageLoadingError
    ) async throws {
        let url = try #require(URL(string: "https://images.fixture.invalid/http.png"))
        let transport = HarnessImageDataLoader(outcomes: [
            url: [.response(statusCode: statusCode, headers: [:], body: Data())]
        ])
        let loader = ProductionImageLoader(loader: transport)

        await #expect(throws: expected) {
            _ = try await loader.load(request(id: "http", urls: [url]))
        }
    }

    @Test
    func explicitNonImageMIMEIsRejected() async throws {
        let url = try #require(URL(string: "https://images.fixture.invalid/not-image"))
        let transport = HarnessImageDataLoader(outcomes: [
            url: [.response(
                statusCode: 200,
                headers: ["Content-Type": "text/html"],
                body: Data("not an image".utf8)
            )]
        ])
        let loader = ProductionImageLoader(loader: transport)

        await #expect(throws: ImageLoadingError.invalidMIME) {
            _ = try await loader.load(request(id: "mime", urls: [url]))
        }
    }

    @Test
    func missingMIMEAllowsRecognizableImageButRejectsCorruptBytes() async throws {
        let validURL = try #require(URL(string: "https://images.fixture.invalid/sniff.png"))
        let corruptURL = try #require(URL(string: "https://images.fixture.invalid/corrupt"))
        let validData = try TestImageFixtureFactory.png(width: 32, height: 16)
        let transport = HarnessImageDataLoader(outcomes: [
            validURL: [.response(statusCode: 200, headers: [:], body: validData)],
            corruptURL: [.response(
                statusCode: 200,
                headers: [:],
                body: Data([0x00, 0x01, 0x02])
            )]
        ])
        let loader = ProductionImageLoader(loader: transport)

        #expect(try await loader.load(
            request(id: "sniff", urls: [validURL])
        ).decodedImage != nil)
        await #expect(throws: ImageLoadingError.decodingFailed) {
            _ = try await loader.load(request(id: "corrupt", urls: [corruptURL]))
        }
    }

    @Test
    func oversizedResponseFailsAtTheConfiguredLimit() async throws {
        let url = try #require(URL(string: "https://images.fixture.invalid/oversized.png"))
        let transport = HarnessImageDataLoader(outcomes: [
            url: [.response(
                statusCode: 200,
                headers: ["Content-Type": "image/png"],
                body: Data(repeating: 0x01, count: 9)
            )]
        ])
        let loader = ProductionImageLoader(
            loader: transport,
            responseByteLimit: 8
        )

        await #expect(throws: ImageLoadingError.responseTooLarge(limit: 8)) {
            _ = try await loader.load(request(id: "oversized", urls: [url]))
        }
    }

    @Test
    func firstCandidateFailureFallsBackInDeclaredOrder() async throws {
        let first = try #require(URL(string: "https://images.fixture.invalid/first.png"))
        let second = try #require(URL(string: "https://images.fixture.invalid/second.png"))
        let data = try TestImageFixtureFactory.png(width: 24, height: 12)
        let transport = HarnessImageDataLoader(outcomes: [
            first: [.response(statusCode: 404, headers: [:], body: Data())],
            second: [.response(
                statusCode: 200,
                headers: ["Content-Type": "image/png"],
                body: data
            )]
        ])
        let loader = ProductionImageLoader(loader: transport)

        #expect(try await loader.load(
            request(id: "fallback", urls: [first, second])
        ).decodedImage != nil)
        #expect(await transport.recordedRequests().compactMap(\.url) == [first, second])
    }

    @Test
    func matchingCacheKeyAvoidsSecondTransportWhileTargetSizeSeparatesEntries() async throws {
        let url = try #require(URL(string: "https://images.fixture.invalid/cache.png"))
        let data = try TestImageFixtureFactory.png(width: 400, height: 200)
        let response = HarnessImageDataOutcome.response(
            statusCode: 200,
            headers: ["Content-Type": "image/png"],
            body: data
        )
        let transport = HarnessImageDataLoader(outcomes: [url: [response, response]])
        let loader = ProductionImageLoader(loader: transport)
        let small = request(
            id: "cache",
            urls: [url],
            target: ImageTargetPixelSize(width: 100, height: 50)
        )
        let large = request(
            id: "cache",
            urls: [url],
            target: ImageTargetPixelSize(width: 200, height: 100)
        )

        let first = try await loader.load(small)
        let cached = try await loader.load(small)
        let distinct = try await loader.load(large)

        #expect(first.pixelSize == cached.pixelSize)
        #expect(first.pixelSize != distinct.pixelSize)
        #expect(await transport.recordedRequests().count == 2)
    }

    @Test
    func cancellationCannotReturnOrCacheALateSuccess() async throws {
        let url = try #require(URL(string: "https://images.fixture.invalid/late.png"))
        let transport = HarnessBlockingImageDataLoader()
        let loader = ProductionImageLoader(loader: transport)
        let task = Task {
            try await loader.load(request(id: "late", urls: [url]))
        }
        try await transport.waitUntilStarted()

        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
        #expect(await transport.recordedRequests().count == 1)
    }

    @Test
    func exifTransformProducesDisplayOrientedPixels() async throws {
        let url = try #require(URL(string: "https://images.fixture.invalid/rotated.jpg"))
        let data = try TestImageFixtureFactory.exifRotatedJPEG(width: 40, height: 20)
        let transport = HarnessImageDataLoader(outcomes: [
            url: [.response(
                statusCode: 200,
                headers: ["Content-Type": "image/jpeg"],
                body: data
            )]
        ])
        let loader = ProductionImageLoader(loader: transport)

        let payload = try await loader.load(request(
            id: "exif",
            urls: [url],
            target: ImageTargetPixelSize(width: 40, height: 40)
        ))

        #expect(payload.pixelSize == ImageTargetPixelSize(width: 20, height: 40))
    }

    @Test
    func invalidTargetInputsUseFinitePurposeFallback() {
        let fallback = ImageTargetPixelSize.default(for: .listThumbnail)
        let invalidValues = [
            InvalidTargetInput(width: 0, height: 100, scale: 2),
            InvalidTargetInput(width: -1, height: 100, scale: 2),
            InvalidTargetInput(width: .nan, height: 100, scale: 2),
            InvalidTargetInput(width: .infinity, height: 100, scale: 2),
            InvalidTargetInput(width: 100, height: 100, scale: .infinity)
        ]

        for input in invalidValues {
            #expect(ImageTargetPixelSize.normalized(
                pointWidth: input.width,
                pointHeight: input.height,
                displayScale: input.scale,
                purpose: .listThumbnail
            ) == fallback)
        }
    }

    @Test
    func safeErrorsNeverExposeCandidateURLsOrCredentials() async throws {
        let url = try #require(URL(
            string: "https://images.fixture.invalid/image.png?token=private"
        ))
        let transport = HarnessImageDataLoader(outcomes: [
            url: [.response(statusCode: 403, headers: [:], body: Data())]
        ])
        let loader = ProductionImageLoader(loader: transport)

        do {
            _ = try await loader.load(request(id: "redacted", urls: [url]))
            Issue.record("Expected image failure")
        } catch let error as ImageLoadingError {
            #expect(!error.safeDescription.contains("token"))
            #expect(!error.safeDescription.contains("private"))
            #expect(!error.safeDescription.contains(url.host ?? "fixture"))
        }
    }

    private func request(
        id: String,
        urls: [URL],
        target: ImageTargetPixelSize = .default(for: .listThumbnail),
        resizeMode: ImageResizeMode = .fit
    ) -> ImageRequest {
        ImageRequest(
            resourceID: id,
            candidateURLs: urls.map(\.absoluteString),
            targetPixelSize: target,
            purpose: .listThumbnail,
            resizeMode: resizeMode
        )
    }
}
