# Third-Party Notices and Provenance

This file records the components and reference material actually used by the
current local Beta RC. It is an engineering inventory, not a legal conclusion.

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
ownership are unresolved. The iOS project does not copy Android Kotlin, Java,
Compose UI, icons, or image resources.

The generated Swift Proto closure currently contains eight roots and 207 locked
inputs read directly from the pinned submodule. Paths, hashes, and import roots
are recorded in `Config/Protobuf/Personalized.inputs.tsv`. The `.proto` files do
not have uniform file-level provenance headers, so public/App Store/commercial
distribution remains blocked pending an independent rights review.

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
