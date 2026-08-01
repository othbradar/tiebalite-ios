# Thread content cross-language fixture provenance

- Classification: `CROSS_LANGUAGE_GENERATED`
- Domain evidence ID: `thread-content.first-post`
- Root message: `tieba.ThreadInfo`
- Content path: `ThreadInfo.firstPostContent` field 142 → repeated
  `PbContent`
- Schema source: read-only Android submodule `app/src/main/protos/`, rooted at
  `ThreadInfo.proto` and its 47-file transitive import closure. That closure is
  a subset of the pinned `Config/Protobuf/Personalized.inputs.tsv`; the payload
  messages exercised here are defined in `PbContent.proto`, `MemeInfo.proto`,
  `PollInfo.proto`, and `PollOption.proto`.
- Android submodule revision:
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- Descriptor compiler: `protoc 35.1`
- Producer: `scripts/fixtures/ThreadContentFixtureGenerator.java`
- JVM: Oracle `javac/java 21.0.10`
- Producer runtime: Maven Central `com.google.protobuf:protobuf-java:4.35.1`
- Published Maven SHA-1: `b933d3f9fc35b0356f28980c2ffc5892d297eebf`
- Locally locked runtime SHA-256:
  `a4345ba2aa009912ff6f90467fea2d104605256b72c50840d75f13256638a472`
- Fixture size: `1535 bytes`
- Fixture SHA-256:
  `d37a7486974718d660a4b43466d914156c66d36f3f83982507915575e68cdf12`

The producer uses Java `DynamicMessage` and the descriptor compiled directly
from the pinned Android submodule. The tracked bytes are independently encoded
from `scripts/fixtures/thread_content_response.textproto` with `protoc` and
must compare byte-for-byte. No Swift-generated type participates in fixture
production.

The fixture is synthetic and deliberately covers all raw values consumed by
Android's `List<PbContent>.renders` branch, raw type `999`, `memeInfo` message
presence, safe and rejected links, valid/malformed/missing image fields, a
read-only poll with zero total, and text following unsupported nodes. It does
not contain account data, Cookies, tokens, device identifiers, captured post
text, or third-party media.

Rebuild and compare with:

```bash
make bootstrap-fixture-tools
make generate-thread-content-fixture
make verify-thread-content-fixture
```

This fixture proves deterministic JVM/protoc/Swift wire compatibility for the
pinned synthetic `ThreadInfo.firstPostContent` shape only. It does not prove
live-server behavior, raw-value frequency, media URL reachability, or
distribution rights.
