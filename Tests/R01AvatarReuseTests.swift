import Foundation
import Testing
@testable import TiebaLite

@MainActor
struct R01AvatarReuseTests {
    @Test(arguments: [false, true])
    func lateAvatarCannotOverwriteTheNewUserOrChangedPortrait(sameUser: Bool) async throws {
        let loader = R01ControlledAvatarLoader()
        let presentation = TiebaImagePresentation()
        let first = request("a", resourceID: sameUser ? "shared-user" : nil)
        let second = request("b", resourceID: sameUser ? "shared-user" : nil)
        let firstTask = Task { await presentation.load(first, using: loader) }
        try await loader.waitForStart("a")
        #expect(presentation.displayedImage(for: second) == nil)
        #expect(presentation.displayedPhase(for: second) == .loading)
        let secondTask = Task { await presentation.load(second, using: loader) }
        try await loader.waitForStart("b")
        try await loader.finish("b")
        await secondTask.value
        let currentImage = presentation.displayedImage(for: second)
        #expect(currentImage != nil)
        try await loader.finish("a")
        await firstTask.value
        #expect(presentation.request == second)
        #expect(presentation.displayedImage(for: second) === currentImage)
        #expect(presentation.displayedImage(for: first) == nil)
    }

    @Test
    func cancelledAvatarCannotPublishLateSuccess() async throws {
        let loader = R01ControlledAvatarLoader()
        let presentation = TiebaImagePresentation()
        let requested = request("a")
        let task = Task { await presentation.load(requested, using: loader) }
        try await loader.waitForStart("a")
        task.cancel()
        try await loader.finish("a")
        await task.value
        #expect(presentation.displayedImage(for: requested) == nil)
        #expect(presentation.displayedPhase(for: requested) == .cancelled)
    }

    @Test
    func failedAvatarUsesTheSameNeutralPresentationState() async {
        let presentation = TiebaImagePresentation()
        let requested = request("a")
        await presentation.load(requested, using: DisabledImageLoader())
        #expect(presentation.displayedImage(for: requested) == nil)
        #expect(presentation.displayedPhase(for: requested) == .failed)
    }

    private func request(_ key: String, resourceID: String? = nil) -> ImageRequest {
        ImageRequest(
            resourceID: resourceID ?? key,
            candidateURLs: ["https://images.fixture.invalid/\(key)"],
            targetPixelSize: ImageTargetPixelSize(width: 108, height: 108),
            purpose: .avatar,
            resizeMode: .fill
        )
    }
}

private actor R01ControlledAvatarLoader: ImageLoading {
    private let starts = ["a": HarnessContinuationGate<Void>(), "b": HarnessContinuationGate<Void>()]
    private var continuations: [String: CheckedContinuation<ImagePayload, Never>] = [:]

    func load(_ request: ImageRequest) async throws -> ImagePayload {
        let key = request.candidateURLs.first.flatMap(URL.init(string:))?.lastPathComponent ?? ""
        return await withCheckedContinuation { continuation in
            continuations[key] = continuation
            starts[key]?.succeed(())
        }
    }

    func waitForStart(_ key: String) async throws {
        try await starts[key]?.wait()
    }

    func finish(_ key: String) throws {
        let data = try TestImageFixtureFactory.png(width: 12, height: 12)
        continuations.removeValue(forKey: key)?.resume(returning: ImagePayload(data: data, mediaType: "image/png"))
    }
}
