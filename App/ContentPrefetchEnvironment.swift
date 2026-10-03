import Foundation
import Network

/// App-lifetime policy. Pages own candidates; this object can revoke all speculative consumers.
@MainActor
final class ContentPrefetchEnvironment {
    private struct WeakScope { weak var value: ContentPrefetchScope? }
    private let settings: SettingsStore
    private let monitor = NWPathMonitor()
    private var scopes: [WeakScope] = []
    private var connected = false
    private var expensive = false
    private var constrained = false
    private var active = false

    init(settings: SettingsStore) {
        self.settings = settings
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let expensive = path.isExpensive
            let constrained = path.isConstrained
            Task { @MainActor [weak self] in
                self?.update(connected: connected, expensive: expensive, constrained: constrained)
            }
        }
        monitor.start(queue: DispatchQueue(label: "dev.tiebalite.content-prefetch-path"))
    }

    var permitted: Bool {
        settings.isLoaded && settings.settings.contentPrefetch.permits(
            connected: connected, expensive: expensive, constrained: constrained,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled, active: active)
    }

    func makeScope() -> ContentPrefetchScope {
        let scope = ContentPrefetchScope { [weak self] in self?.permitted == true }
        scopes.removeAll { $0.value == nil }
        scopes.append(WeakScope(value: scope))
        return scope
    }

    func setActive(_ value: Bool) { active = value; policyChanged() }
    func policyChanged() { if !permitted { cancelAll() } }
    func cancelAll() { scopes.forEach { $0.value?.cancel() } }

    private func update(connected: Bool, expensive: Bool, constrained: Bool) {
        self.connected = connected
        self.expensive = expensive
        self.constrained = constrained
        policyChanged()
    }

    deinit { monitor.cancel() }
}
