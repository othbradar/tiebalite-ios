#if DEBUG
func pagerResolutionText(
    _ reason: PagerCallbackResolutionReason
) -> String {
    pagerBaseResolutionText(reason)
        ?? pagerRendezvousResolutionText(reason)
}

private func pagerBaseResolutionText(
    _ reason: PagerCallbackResolutionReason
) -> String? {
    switch reason {
    case .committed:
        "committed"
    case .systemBailout:
        "system-bailout"
    case .animationInterrupted:
        "animation-interrupted"
    case .panCancelled:
        "pan-cancelled"
    case .panFailed:
        "pan-failed"
    case .missingPanTerminal:
        "missing-pan-terminal"
    case .staleToken:
        "stale-token"
    case .previousSourceMismatch:
        "previous-source-mismatch"
    case .visiblePageMismatch:
        "visible-page-mismatch"
    case .endedWithoutTransition:
        "ended-without-transition"
    default:
        nil
    }
}

private func pagerRendezvousResolutionText(
    _ reason: PagerCallbackResolutionReason
) -> String {
    switch reason {
    case .ownershipCancelled:
        "ownership-cancelled"
    case .ownershipFailed:
        "ownership-failed"
    case .ownershipInvalidated:
        "ownership-invalidated"
    case .ownershipRejected:
        "ownership-rejected"
    case .externalSelectionChanged:
        "external-selection-changed"
    case .transitionInvalidated:
        "transition-invalidated"
    default:
        "unknown"
    }
}
#endif
