SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help doctor bootstrap-tools bootstrap-fixture-tools tool-versions instructions reference-check generate-protos verify-protos generate-personalized-fixture verify-personalized-fixture generate-thread-content-fixture verify-thread-content-fixture generate resolve-packages verify-swiftpm-lock verify-generate lint forbidden static-canaries secret-scan networking-isolation build release-build release-isolation ipad-build test-unit test-ui-smoke test-ui-smoke-ipad test-ui-renderer test-ui-renderer-ipad test-ui-interaction test-ui-interaction-ipad ui-test-isolation test-all quality-fast quality clean

help:
	@printf '%s\n' \
	  'make doctor        - check macOS/Xcode/Git/simulator/skills environment' \
	  'make bootstrap-tools - install development tools from Brewfile' \
	  'make bootstrap-fixture-tools - install exact ignored JVM fixture runtime' \
	  'make tool-versions - enforce the accepted build-tool versions' \
	  'make instructions  - validate AGENTS instruction-size chains and repo skills' \
	  'make reference-check - verify the Android reference is clean and locked' \
	  'make generate-protos - regenerate the locked read-endpoint Proto closure' \
	  'make verify-protos - verify deterministic Proto generation and drift' \
	  'make generate-personalized-fixture - rebuild the JVM cross-language fixture' \
	  'make verify-personalized-fixture - verify JVM fixture determinism (tool cache required)' \
	  'make generate-thread-content-fixture - rebuild the ThreadInfo content fixture' \
	  'make verify-thread-content-fixture - verify thread fixture cross-language bytes' \
	  'make generate      - generate the Xcode project with XcodeGen' \
	  'make resolve-packages - resolve only the canonical SwiftPM lock' \
	  'make verify-swiftpm-lock - verify exact SwiftProtobuf package identity and revision' \
	  'make verify-generate - prove two clean project generations are identical' \
	  'make lint          - run SwiftLint' \
	  'make forbidden     - scan prohibited interaction/state patterns' \
	  'make static-canaries - prove static source-policy rejection/approval paths' \
	  'make networking-isolation - enforce fixture/Proto/renderer isolation' \
	  'make build         - build for a generic iOS Simulator' \
	  'make release-build - build Release for a generic iOS Simulator' \
	  'make release-isolation - prove Release excludes test support' \
	  'make ipad-build    - build using an available iPad Simulator' \
	  'make test-unit     - run unit tests on an available iPhone Simulator' \
	  'make test-ui-smoke - run iPhone UI smoke tests' \
	  'make test-ui-smoke-ipad - run the iPad App Shell smoke test' \
	  'make test-ui-renderer - run the iPhone ThreadContent Renderer Lab smoke' \
	  'make test-ui-renderer-ipad - run the iPad ThreadContent Renderer Lab smoke' \
	  'make test-ui-interaction - run the iPhone interaction lab matrix' \
	  'make test-ui-interaction-ipad - run the iPad interaction lab matrix' \
	  'make ui-test-isolation - prove test-support target boundaries' \
	  'make quality-fast  - lint/static/build/unit' \
	  'make quality       - fast gate + UI/iPad + test-support isolation'

doctor:
	@scripts/bootstrap_check.sh
	@scripts/check_tool_versions.sh

tool-versions:
	@scripts/check_tool_versions.sh

instructions:
	@python3 scripts/check_instruction_size.py
	@python3 scripts/validate_skills.py

reference-check:
	@scripts/reference_integrity.sh

generate-protos: tool-versions reference-check
	@scripts/generate_protos.sh

verify-protos: tool-versions reference-check
	@scripts/verify_protos.sh

generate-personalized-fixture: tool-versions reference-check
	@scripts/generate_personalized_fixture.sh

verify-personalized-fixture: tool-versions reference-check
	@scripts/verify_personalized_fixture.sh

generate-thread-content-fixture: tool-versions reference-check
	@scripts/generate_thread_content_fixture.sh

verify-thread-content-fixture: tool-versions reference-check
	@scripts/verify_thread_content_fixture.sh

bootstrap-tools:
	@command -v brew >/dev/null 2>&1 || { echo 'Homebrew is required for this target.' >&2; exit 1; }
	@brew bundle install --no-upgrade
	@scripts/bootstrap_fixture_tools.sh

bootstrap-fixture-tools:
	@scripts/bootstrap_fixture_tools.sh

generate: tool-versions verify-protos
	@command -v xcodegen >/dev/null 2>&1 || { echo 'xcodegen missing; run make bootstrap-tools.' >&2; exit 1; }
	@test -f project.yml || { echo 'project.yml missing; Stage 03 has not created the project.' >&2; exit 1; }
	@xcodegen generate --spec project.yml --no-env
	@scripts/materialize_swiftpm_lock.sh TiebaLite.xcodeproj

resolve-packages: generate
	@xcodebuild -resolvePackageDependencies -project TiebaLite.xcodeproj -scheme TiebaLite \
	  -clonedSourcePackagesDirPath .build/SourcePackages \
	  -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates
	@scripts/verify_swiftpm_lock.sh

verify-swiftpm-lock: generate
	@scripts/verify_swiftpm_lock.sh

verify-generate: tool-versions verify-protos
	@scripts/verify_project_generation.sh

lint: tool-versions
	@command -v swiftlint >/dev/null 2>&1 || { echo 'swiftlint missing; run make bootstrap-tools.' >&2; exit 1; }
	@swiftlint lint --strict --no-cache

forbidden:
	@scripts/forbidden_patterns.sh

static-canaries:
	@scripts/verify_static_policy_canaries.sh

secret-scan:
	@scripts/secret_scan.sh

networking-isolation: generate
	@bash scripts/verify_networking_isolation.sh

build: generate
	@scripts/run_xcodebuild.sh build

release-build: generate
	@scripts/run_xcodebuild.sh release-build

release-isolation: release-build
	@scripts/verify_release_isolation.sh

ipad-build: generate
	@scripts/run_xcodebuild.sh ipad-build

test-unit: generate
	@scripts/run_xcodebuild.sh unit

test-ui-smoke: generate
	@scripts/run_xcodebuild.sh ui-smoke

test-ui-smoke-ipad: generate
	@scripts/run_xcodebuild.sh ui-smoke-ipad

test-ui-renderer: generate
	@scripts/run_xcodebuild.sh ui-renderer

test-ui-renderer-ipad: generate
	@scripts/run_xcodebuild.sh ui-renderer-ipad

test-ui-interaction: generate
	@scripts/run_xcodebuild.sh ui-interaction

test-ui-interaction-ipad: generate
	@scripts/run_xcodebuild.sh ui-interaction-ipad

ui-test-isolation: test-unit test-ui-smoke
	@scripts/verify_ui_test_isolation.sh

test-all: generate
	@scripts/run_xcodebuild.sh tests

quality-fast: instructions reference-check verify-protos verify-personalized-fixture verify-thread-content-fixture verify-swiftpm-lock verify-generate forbidden static-canaries secret-scan networking-isolation lint build test-unit
	@git diff --check

quality: quality-fast ui-test-isolation test-ui-interaction ipad-build test-ui-smoke-ipad test-ui-interaction-ipad release-isolation
	@git diff --check
	@echo 'Quality gate completed.'

clean:
	@rm -rf .build/DerivedData Artifacts/TestResults
