# TiebaLite iOS

TiebaLite is an iOS/iPadOS 18+ read-only client under staged development. Stage 03
contains only the deterministic Xcode project scaffold and a static launch
placeholder; no Tieba business flow or live API is present.

## Clean-checkout setup

1. Install the versions accepted by `Config/ToolVersions.env`. Homebrew users can
   run `brew bundle install --no-upgrade`.
2. Copy `scripts/project.env.example` to the ignored `scripts/project.env`.
   Leave simulator UDIDs empty to auto-select available iPhone and iPad devices.
3. Run `make doctor`.
4. Run `make generate`.
5. Run `make quality`.

`project.yml`, the xcconfig files, and
`Config/TestPlans/TiebaLite.xctestplan` are canonical. Generated
`.xcodeproj`/`.xcworkspace` files are intentionally ignored and must not be
edited or committed.
