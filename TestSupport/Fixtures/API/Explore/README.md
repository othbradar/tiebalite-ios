# U11 iOS synthetic fixtures

`native-ios.json` is generated from the user-supplied iOS 22.11.1 TBClient descriptors by `scripts/fixtures/native_explore/generate.py`. All account/content fields are synthetic. It contains three request bytes and four response samples. No network or app execution is needed.

`verify.py` independently compares the app schema with the original descriptor tags, cardinality and scalar types. Embedded ThreadInfo bytes use the separately verified native display DTO subset; modern feed layout presence is detected without pretending unsupported content is empty.

These are protocol fixtures, not captured Live responses or proof of full native SDK/page behavior. The superseded Android U11 fixtures are retained only in ignored local evidence.
