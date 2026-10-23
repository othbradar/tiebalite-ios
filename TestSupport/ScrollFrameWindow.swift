import QuartzCore
import UIKit

/// Fixed-step CPU/display-link diagnostic, never presented as natural-pan/GPU FPS.
@MainActor final class ScrollFrameWindow: NSObject {
    struct Result {
        var intervals: [Double] = []
        var work: [Double] = []
        var overBudget = 0
        var drift: CGFloat = 0
        var frames = 0
        func report() -> String {
            func percentiles(_ values: [Double]) -> String {
                let sorted = values.sorted()
                guard !sorted.isEmpty else { return "empty" }
                return [0.50, 0.95, 0.99, 1.0].map {
                    String(format: "%.3f", sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * $0))] * 1_000)
                }.joined(separator: "/")
            }
            return "frames=\(frames) interval p50/95/99/max ms=\(percentiles(intervals))"
                + " work=\(percentiles(work)) overBudget=\(overBudget) drift=\(drift)"
        }
    }
    private var link: CADisplayLink?
    private var completion: CheckedContinuation<Result, Never>?
    private var result = Result()
    private var previous: CFTimeInterval?
    private var count = 0
    private var step: ((Int) -> CGFloat)?
    func run(frames: Int, step: @escaping (Int) -> CGFloat) async -> Result {
        result = Result(); previous = nil; count = frames; self.step = step
        return await withCheckedContinuation { continuation in
            completion = continuation
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            self.link = link
            link.add(to: .main, forMode: .common)
        }
    }
    @objc private func tick(_ link: CADisplayLink) {
        if let previous {
            let interval = link.timestamp - previous
            result.intervals.append(interval)
            if interval > (link.targetTimestamp - link.timestamp) * 1.5 { result.overBudget += 1 }
        }
        previous = link.timestamp
        let start = CACurrentMediaTime()
        result.drift = max(result.drift, step?(result.frames) ?? 0)
        result.work.append(CACurrentMediaTime() - start)
        result.frames += 1
        if result.frames == count {
            link.invalidate(); self.link = nil; step = nil
            completion?.resume(returning: result); completion = nil
        }
    }
}
