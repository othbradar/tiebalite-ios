# Bug taxonomy

1. Illegal state transition or duplicate state truth.
2. Cancellation, request generation, stale response or actor isolation.
3. SwiftUI identity, list diffing or reusable cell/controller state.
4. Navigation path/route ownership and scene restoration.
5. Layout, safe area, keyboard, overlay, z-order or hit testing.
6. Gesture priority, direction lock, zoom/paging boundary or system back conflict.
7. Implicit animation, transaction propagation or duplicate system/custom transition.
8. UIKit representable coordinator/update/dismantle lifecycle.
9. Image pipeline, decode, prefetch, cancellation, cache or memory.
10. API/protobuf malformed or previously unseen data.

A root cause must connect an exact trigger to an exact erroneous state/object and the visible symptom.
