SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help doctor bootstrap-tools instructions reference-check generate lint forbidden secret-scan build ipad-build test-unit test-ui-smoke test-all quality-fast quality clean

help:
	@printf '%s\n' \
	  'make doctor        - check macOS/Xcode/Git/simulator/skills environment' \
	  'make bootstrap-tools - install development tools from Brewfile' \
	  'make instructions  - validate AGENTS instruction-size chains and repo skills' \
	  'make reference-check - verify the Android reference is clean and locked' \
	  'make generate      - generate the Xcode project with XcodeGen' \
	  'make lint          - run SwiftLint' \
	  'make forbidden     - scan prohibited interaction/state patterns' \
	  'make build         - build for a generic iOS Simulator' \
	  'make ipad-build    - build using an available iPad Simulator' \
	  'make test-unit     - run unit tests on an available iPhone Simulator' \
	  'make test-ui-smoke - run UI smoke tests' \
	  'make quality-fast  - lint/static/build/unit' \
	  'make quality       - fast gate + UI smoke + iPad build + diff checks'

doctor:
	@scripts/bootstrap_check.sh

instructions:
	@python3 scripts/check_instruction_size.py
	@python3 scripts/validate_skills.py

reference-check:
	@scripts/reference_integrity.sh

bootstrap-tools:
	@command -v brew >/dev/null 2>&1 || { echo 'Homebrew is required for this target.' >&2; exit 1; }
	@brew bundle

generate:
	@command -v xcodegen >/dev/null 2>&1 || { echo 'xcodegen missing; run make bootstrap-tools.' >&2; exit 1; }
	@test -f project.yml || { echo 'project.yml missing; Stage 03 has not created the project.' >&2; exit 1; }
	@xcodegen generate

lint:
	@command -v swiftlint >/dev/null 2>&1 || { echo 'swiftlint missing; run make bootstrap-tools.' >&2; exit 1; }
	@swiftlint lint --strict

forbidden:
	@scripts/forbidden_patterns.sh

secret-scan:
	@scripts/secret_scan.sh

build: generate
	@scripts/run_xcodebuild.sh build

ipad-build: generate
	@scripts/run_xcodebuild.sh ipad-build

test-unit: generate
	@scripts/run_xcodebuild.sh unit

test-ui-smoke: generate
	@scripts/run_xcodebuild.sh ui-smoke

test-all: generate
	@scripts/run_xcodebuild.sh tests

quality-fast: instructions reference-check forbidden secret-scan lint build test-unit
	@git diff --check

quality: quality-fast test-ui-smoke ipad-build
	@git diff --check
	@echo 'Quality gate completed.'

clean:
	@rm -rf .build/DerivedData Artifacts/TestResults
