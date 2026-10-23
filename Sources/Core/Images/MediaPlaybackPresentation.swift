import Observation

/// A progress tick must not invalidate every media row that only observes the owner/phase.
@MainActor @Observable
final class MediaPlaybackPresentation {
    struct Status: Equatable {
        let owner: String?
        let generation: UInt64
        let phase: MediaPlaybackState.Phase
    }
    struct Progress: Equatable {
        let elapsed: Double
        let duration: Double
        var fraction: Double { duration > 0 ? min(1, max(0, elapsed / duration)) : 0 }
    }
    private(set) var status = Status(owner: nil, generation: 0, phase: .idle)
    private(set) var progress = Progress(elapsed: 0, duration: 0)
    func update(_ state: MediaPlaybackState) {
        let nextStatus = Status(owner: state.owner, generation: state.generation, phase: state.phase)
        let nextProgress = Progress(elapsed: state.elapsed, duration: state.duration)
        if status != nextStatus { status = nextStatus }
        if progress != nextProgress { progress = nextProgress }
    }
}
