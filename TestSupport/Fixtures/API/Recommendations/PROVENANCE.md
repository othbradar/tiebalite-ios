# Personalized cross-language fixture provenance

- Classification: `CROSS_LANGUAGE_GENERATED`
- Endpoint evidence ID: `recommendations.personalized`
- Schema source: read-only Android submodule
  `app/src/main/protos/Personalized.proto` and its locked 51-file import closure
- Android submodule revision:
  `5545326b2a8e0d784b2f3dfbcb219c7b121e61c2`
- Descriptor compiler: `protoc 35.1`
- Producer: `scripts/fixtures/PersonalizedFixtureGenerator.java`
- JVM: Oracle `javac/java 21.0.10`
- Producer runtime: Maven Central `com.google.protobuf:protobuf-java:4.35.1`
- Published Maven SHA-1: `b933d3f9fc35b0356f28980c2ffc5892d297eebf`
- Locally locked runtime SHA-256:
  `a4345ba2aa009912ff6f90467fea2d104605256b72c50840d75f13256638a472`
- Fixture SHA-256:
  `54a838f8bd05c39e90b84b3bba4d4224dc81fe11b63934e23dd65be937eebb4a`

The producer uses Java `DynamicMessage`; it does not import Swift generated
types. All identifiers and text are synthetic, one raw category is deliberately
`999`, and one empty `VideoInfo` is explicitly present. No account, Cookie,
token, device identifier, captured payload, private text or third-party media is
included.

Rebuild and compare with:

```bash
make bootstrap-fixture-tools
make generate-personalized-fixture
make verify-personalized-fixture
```

The bootstrap target obtains the ignored jar only from the exact Maven Central
URL in `Config/ToolVersions.env`, verifies the published SHA-1 and locked
SHA-256, then installs it atomically. Quality verification is offline and fails
closed if that cache is missing, symlinked or has the wrong hash. This fixture
proves JVM/Swift wire compatibility for the pinned synthetic message only. It
does not prove anonymous live-server acceptance, response MIME behavior,
pagination termination, or distribution rights.
