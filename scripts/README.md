# Scripts

- `bootstrap_check.sh`: environment and repository checks; safe before Xcode project exists.
- `check_tool_versions.sh`: enforce the accepted Xcode, Swift, XcodeGen and SwiftLint versions; warn only for xcbeautify drift.
- `validate_skills.py`: validate repo skill frontmatter/metadata basics.
- `check_instruction_size.py`: ensure every applicable AGENTS chain remains below Codex's configured/default instruction limit.
- `reference_integrity.sh`: require the Android reference to stay clean and match its audited lock SHA when present.
- `find_simulator.py`: choose an available iPhone/iPad simulator UDID.
- `run_xcodebuild.sh`: shared build/test runner after Stage 03 fills
  `project.env`; UI modes reinstall only TiebaLite and its test runner so a
  Simulator clone cannot reuse a stale bundle.
- `verify_project_generation.sh`: generate twice in a temporary directory and require byte-identical Xcode projects.
- `forbidden_patterns.sh`: fail on known interaction/state anti-patterns and warn on suspicious patterns.
- `swift_source_policy.sh`: enforce logging, concurrency and deterministic-test source boundaries.
- `verify_static_policy_canaries.sh`: prove prohibited samples fail and the approved diagnostics backend passes.
- `secret_scan.sh`: lightweight source/diff secret checks; does not replace a dedicated scanner.
- `verify_release_isolation.sh`: inspect fresh Release source lists, bundle, strings and symbols for test-only code.
- `verify_ui_test_isolation.sh`: prove the UITesting App, unit target and UI target have explicit harness boundaries.
- `generate_thread_content_fixture.sh`: rebuild the synthetic
  `ThreadInfo.firstPostContent` cross-language binary from the pinned Android
  schema with the locked JVM producer.
- `verify_thread_content_fixture.sh`: compare two JVM generations, the tracked
  thread-content fixture and an independent `protoc --encode` result.
- `collect_bug_context.sh`: collect non-sensitive environment/Git context for a bug report.
- `interaction_inventory.sh`: inventory animation, gesture, presentation, scrolling, navigation and identity call sites for audits.

Scripts do not modify unrelated user data. UI modes remove only the configured
TiebaLite app and its UI-test runner from the selected test Simulator before
reinstalling current build products; other apps and containers are untouched.
Project-specific values belong in the ignored `scripts/project.env`, generated
from the committed example. The unit, UI smoke, renderer-lab, interaction-lab
and full-test modes all use the canonical `TiebaLite` test plan and explicit
test-plan configurations.
