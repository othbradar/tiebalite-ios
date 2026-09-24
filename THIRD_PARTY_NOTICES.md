# Third-Party Notices and Provenance

This file records the components and reference material actually used by the
current public-source Beta RC. It is an engineering inventory, not a legal
conclusion.

## TiebaLite iOS original source

The original iOS source code for which the project owner holds the necessary
rights is licensed under GNU GPL version 3 only (`GPL-3.0-only`), as recorded in
the repository root `LICENSE`.

This grant applies from repository versions that contain that GPL root license.
The historical `v0.1.0-beta.1` and `v0.1.0-beta.2` snapshots retain the license
text included in those snapshots and are not retroactively relicensed here.

That project-level grant does not relicense third-party dependencies, the
Android reference submodule, generated Protocol Buffer code, schemas, service
content, trademarks, or other material the project owner does not own. Those
materials remain subject to their own licenses, provenance, and service terms.

## Apple SwiftProtobuf

- Project: `apple/swift-protobuf`
- URL: <https://github.com/apple/swift-protobuf>
- Exact version: `1.38.1`
- Exact revision: `55d7a1cc5666b85c13464aea1c4b4a90feccb4c8`
- License: Apache License 2.0 with the SwiftProtobuf Runtime Library Exception
- Use: production dependency of `GeneratedProtobuf` and the protocol mapping
  boundary

The canonical dependency lock is `Config/SwiftPM/Package.resolved`. The
SwiftProtobuf license does not grant rights to any input schema.

## TiebaLite Android reference

- Repository: <https://github.com/zzc10086/TiebaLite.git>
- Pinned branch: `4.0-dev`
- Pinned revision: `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- Local path: `References/TiebaLite-Android`
- Repository license text: GNU GPL version 3

The reference README also contains a non-commercial-use statement. Its exact
relationship to the GPL text, the fork/upstream rights chain, and file-level
ownership are unresolved. The iOS project does not vendor Android Kotlin/Java
or Compose UI files.

R01 adapts the compact avatar/chip/divider/media presentation rules and level
palette transform from UI reference `c5f1125f42498e49db4e4a9cb66313b8c8a285c7`.
Sources under `app/src/main/java/com/huanchengfly/tieba/post/` include
`ui/widgets/compose/{Avatars,Headers,Texts,FeedCard,Dividers}.kt`,
`ui/page/main/home/HomePage.kt`, `ui/page/thread/ThreadPage.kt`, and
`utils/{StringUtil.kt,Util.java,ColorUtils.java}`. The reference is GNU GPL
version 3; these adapted rules retain that provenance under the project GPL
source license. No Android icon or emoticon resource was imported for R01.

R04 also adapts the feed display contracts from the same UI commit's
`FeedCard.kt` and `api/models/protos/Extensions.kt`: compact user header,
five-line text, three-image preview with count, forum chip and read-only
counts. The implementation remains native SwiftUI using the existing image
loader and virtualized table; no additional Android bitmap/icon was imported.
The R04 author-avatar fix also adapts the same commit's
`utils/StringUtil.kt:getAvatarUrl` portrait-prefix rule. Its strictly scoped
legacy HTTP transport exception is recorded in ADR-0024.

Debug Gallery samples in `App/DebugR01ImageSamples.swift` are small extracts
of user-provided Android-target screenshots, solely for component comparison.
Their source rectangles are recorded in `Docs/VisualParity/R01_ACCEPTANCE.md`.
They are not Live account data. The existing `Debug*.swift` Release source
exclusion applies to the Gallery and its embedded samples.

The generated Swift Proto closure currently contains eight roots and 207 locked
inputs read directly from the pinned submodule. Paths, hashes, and import roots
are recorded in `Config/Protobuf/Personalized.inputs.tsv`. The `.proto` files do
not have uniform file-level provenance headers. Publishing this source
repository does not resolve that provenance; App Store and commercial binary
distribution remain uncleared pending an independent rights review.

## protobuf-java fixture tool

- Artifact: `com.google.protobuf:protobuf-java:4.35.1`
- License recorded by its manifest: BSD 3-Clause
- Use: build-time creation of synthetic, sanitized cross-language fixtures only

The jar is downloaded into ignored `.build/FixtureTools`; it is not linked,
copied, or packaged into the Debug or Release application bundle.

## Apple system frameworks

The application uses system frameworks including SwiftUI, UIKit, Foundation,
Security, WebKit, ImageIO, CoreGraphics, UniformTypeIdentifiers, and OSLog. They
are supplied by the Apple SDK and are not vendored in this repository.

### R02 Android root navigation vectors

The `root-home`, `root-dynamic`, `root-messages`, and `root-personal` asset pairs
are static SVG adaptations of TiebaLite Android's generic animated-vector
navigation resources at UI commit `c5f1125f42498e49db4e4a9cb66313b8c8a285c7`.
Original source: `app/src/main/res/drawable/ic_animated_rounded_inventory_2.xml`,
`ic_animated_toy_fans.xml`, `ic_animated_rounded_notifications.xml`, and
`ic_animated_rounded_person.xml`. GPL-3.0 provenance is retained. Only the static
outline/filled endpoints are used; animation is not copied. Details and conversion
rules are recorded in `Resources/ROOT_NAVIGATION_PROVENANCE.md`.

### R05 Forum UI / GeneralTabList

Forum tabs, sort values, good classifications and compact feed presentation are adapted from TiebaLite UI commit c5f1125f42498e49db4e4a9cb66313b8c8a285c7: ForumPage.kt, ForumThreadListPage.kt, ForumThreadListViewModel.kt, GeneralTabListViewModel.kt and FeedCard.kt. GeneralTabList request/response schema and SortOption.proto come from the existing protocol reference 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2 under its existing GPL-3.0 provenance; exact hashes and imports are locked in Config/Protobuf/Personalized.inputs.tsv. No Android assets were copied.

### R07 Official inline Tieba emoticons

51 original WebP resources are copied without modification from UI reference
`c5f1125f42498e49db4e4a9cb66313b8c8a285c7`,
`app/src/main/res/drawable/image_emoticon{1…50,89}.webp`.
Each source/local path, original SHA-256 and size is listed in
`Resources/TIEBA_EMOTICONS_PROVENANCE.md` (143,676 bytes total).

Name/ID and syntax mappings are adapted from the same commit's
`app/src/main/java/com/huanchengfly/tieba/post/utils/EmoticonManager.kt`
(`DEFAULT_EMOTICON_MAPPING`, `registerEmoticon`) and `EmoticonUtil.kt`
(`WEB_EMOTICON_NAME_MAPPING`, canonical/web expressions).
Inline placement follows `ui/common/PbContentRender.kt` and
`ui/widgets/compose/Texts.kt`; `ui/page/reply/ReplyPage.kt` confirms the
`#(name)` insertion syntax. These mapping adaptations retain Android GPL-3.0
provenance. The Android repository's license and non-commercial statement do
not resolve the separate ownership/distribution rights of Tieba artwork.
The existing binary/App Store/commercial distribution limitations remain.
No new remote image source, image library or emoticon download cache is added.

R07 missing-emoticon revision additionally bundles the original 3,250-byte
`image_emoticon67.png` (捂嘴笑) from the exact public asset URL used by Android
`EmoticonManager.fetchEmoticons`. Its name/ID pair is verified from public
PbContent type-2 fields following Android's registration rule. Full source,
SHA-256, acquisition method and rights limitation are recorded in
`Resources/TIEBA_EMOTICONS_PROVENANCE.md`. This is a development-time asset
acquisition; production still loads local images only.

The complete R07 catalog revision adds 75 more original PNGs: the remaining
52 Android-default assets and 23 official registered extensions. The current
127-image catalog totals 379540 bytes. Name metadata comes from the public
Tieba web utility module hybrid-usergrow-base:174 at `https://tb3.bdstatic.com/tb/wise/hybrid-usergrow-base/static/js/util.d8d2afea.js`;
102…124 images use the official web renderer's HTTPS image source above.
Per-file URLs/hashes and name conflict handling are preserved in the provenance
record. No downloaded JavaScript is executed or bundled. Artwork rights remain
with their respective owners; this does not grant distribution permission.

### R08 PbFloor / Subposts

Four PbFloor schemas are generated from the same GPL-3.0 Android protocol reference 5545326b2a8e0d784b2f3dfbcb219c7b121e61c2; exact hashes/imports remain in Config/Protobuf/Personalized.inputs.tsv. Read-only Subposts presentation follows SubPostsPage.kt/SubPostsViewModel.kt and ThreadPage.kt from UI commit c5f1125f42498e49db4e4a9cb66313b8c8a285c7. No new dependencies. Existing distribution limitations still apply.

The R08 emoticon correction adds five original Shoubai PNGs (19,684 bytes),
verified from the reported public PbFloor type-2 text/c pairs and acquired using
Android's exact client asset URL rule. The local catalog now contains 132 images
(399,224 bytes). Per-file source URLs and SHA-256 are recorded in
Resources/TIEBA_EMOTICONS_PROVENANCE.md. All are bundled original artwork;
production adds no remote downloader, cache, credentials or transport exception.

R09 extends the same locked Android Protobuf source closure to AddPost and its verification/response dependencies (18 generated files); original source/license attribution above remains applicable. No additional runtime package is introduced.
