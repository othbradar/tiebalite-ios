# Scripts

- `bootstrap_check.sh`: environment and repository checks; safe before Xcode project exists.
- `validate_skills.py`: validate repo skill frontmatter/metadata basics.
- `check_instruction_size.py`: ensure every applicable AGENTS chain remains below Codex's configured/default instruction limit.
- `reference_integrity.sh`: require the Android reference to stay clean and match its audited lock SHA when present.
- `find_simulator.py`: choose an available iPhone/iPad simulator UDID.
- `run_xcodebuild.sh`: shared build/test runner after Stage 03 fills `project.env`.
- `forbidden_patterns.sh`: fail on known interaction/state anti-patterns and warn on suspicious patterns.
- `secret_scan.sh`: lightweight source/diff secret checks; does not replace a dedicated scanner.
- `collect_bug_context.sh`: collect non-sensitive environment/Git context for a bug report.
- `interaction_inventory.sh`: inventory animation, gesture, presentation, scrolling, navigation and identity call sites for audits.

All scripts avoid modifying user data. Project-specific values belong in the ignored `scripts/project.env`, generated from the committed example.
