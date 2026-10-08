import CoreTelephony
import Foundation
import Network

@MainActor
enum NativeWriteNetworkEnvironment {
    static func currentType() async throws -> String {
        let monitor = NWPathMonitor()
        let updates = AsyncStream<NWPath> { continuation in
            monitor.pathUpdateHandler = { path in
                continuation.yield(path)
                continuation.finish()
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "dev.tiebalite.native-write.network"))
        }
        for await path in updates {
            try Task.checkCancellation()
            guard path.status == .satisfied else { return "" }
            if path.usesInterfaceType(.wifi) { return "1" }
            guard path.usesInterfaceType(.cellular) else { return "0" }
            // Match the native single active radio source, not another SIM's
            // fastest technology. No carrier/subscriber identifiers are read.
            let info = CTTelephonyNetworkInfo()
            let radio = info.dataServiceIdentifier.flatMap { info.serviceCurrentRadioAccessTechnology?[$0] }
            return radioType(radio)
        }
        throw CancellationError()
    }

    static func radioType(_ radio: String?) -> String {
        switch radio {
        case CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA: "5"
        case CTRadioAccessTechnologyLTE: "4"
        case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD: "3"
        case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x: "2"
        default: "0"
        }
    }
}
