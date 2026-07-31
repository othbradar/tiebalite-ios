SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help doctor bootstrap-tools tool-versions instructions reference-check generate verify-generate lint forbidden static-canaries secret-scan build release-build release-isolation ipad-build test-unit test-ui-smoke test-ui-smoke-ipad test-ui-interaction test-ui-interaction-ipad ui-test-isolation test-all quality-fast quality clean

help:
	@printf '%s\n' \
	  'make doctor        - check macOS/Xcode/Git/simulator/skills environment' \
	  'make bootstrap-tools - install development tools from Brewfile' \
	  'make tool-versions - enforce the accepted build-tool versions' \
	  'make instructions  - validate AGENTS instruction-size chains and repo skills' \
	  'make reference-check - verify the Android reference is clean and locked' \
	  'make generate      - generate the Xcode project with XcodeGen' \
	  'make verify-generate - prove two clean project generations are identical' \
	  'make lint          - run SwiftLint' \
	  'make forbidden     - scan prohibited interaction/state patterns' \
	  'make static-canaries - prove static source-policy rejection/approval paths' \
	  'make build         - build for a generic iOS Simulator' \
	  'make release-build - build Release for a generic iOS Simulator' \
	  'make release-isolation - prove Release excludes test support' \
	  'make ipad-build    - build using an available iPad Simulator' \
	  'make test-unit     - run unit tests on an available iPhone Simulator' \
	  'make test-ui-smoke - run iPhone UI smoke tests' \
	  'make test-ui-smoke-ipad - run the iPad App Shell smoke test' \
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

bootstrap-tools:
	@command -v brew >/dev/null 2>&1 || { echo 'Homebrew is required for this target.' >&2; exit 1; }
	@brew bundle install --no-upgrade

generate: tool-versions
	@command -v xcodegen >/dev/null 2>&1 || { echo 'xcodegen missing; run make bootstrap-tools.' >&2; exit 1; }
	@test -f project.yml || { echo 'project.yml missing; Stage 03 has not created the project.' >&2; exit 1; }
	@xcodegen generate --spec project.yml --no-env

verify-generate: tool-versions
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

test-ui-interaction: generate
	@scripts/run_xcodebuild.sh ui-interaction

test-ui-interaction-ipad: generate
	@scripts/run_xcodebuild.sh ui-interaction-ipad

ui-test-isolation: test-unit test-ui-smoke
	@scripts/verify_ui_test_isolation.sh

test-all: generate
	@scripts/run_xcodebuild.sh tests

quality-fast: instructions reference-check verify-generate forbidden static-canaries secret-scan lint build test-unit
	@git diff --check

quality: quality-fast ui-test-isolation test-ui-interaction ipad-build test-ui-smoke-ipad test-ui-interaction-ipad release-isolation
	@git diff --check
	@echo 'Quality gate completed.'

clean:
	@rm -rf .build/DerivedData Artifacts/TestResults
