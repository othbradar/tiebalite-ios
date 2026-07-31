# Feature slice completion checklist

- Scope and non-goals are explicit.
- Stable IDs and route parameters are defined.
- Old response, cancellation, refresh and pagination behavior are tested where applicable.
- Existing content is retained during refresh/next-page failure.
- View uses no direct network/protobuf/persistence.
- No arbitrary animation durations, new DragGesture, duplicate Pager/MediaViewer, root overlay, UUID refresh or async delay.
- iPhone smoke passes; iPad smoke passes when shared layout/navigation/interaction changed.
- Dark mode, Dynamic Type and Reduce Motion are considered.
- Actual commands and results are reported.
