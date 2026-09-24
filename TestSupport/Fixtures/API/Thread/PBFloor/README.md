# R08 PbFloor fixtures

Synthetic, no live response bodies or credentials. R08PBFloorFixture constructs the exact locked
Android schema in memory with fixed 8001/9002 thread/parent, 30 synthetic replies over two pages,
a repeated boundary ID, Chinese text, official emoticon, reply mention and image nodes.
PBFloor mapper tests mutate only fixed messages for empty/missing-author/unknown/malformed/identity
and server errors. Store tests use controlled continuations for timeout/retry/cancellation/late
responses. FixtureSubpostsRepository uses the same 30-row contract for isolated UI smoke.
Live evidence is only anonymous aggregate metadata in ignored Artifacts, never an automation dependency.
