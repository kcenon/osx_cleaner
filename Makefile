# OSX Cleaner - Unified Build System
# This Makefile provides targets for building the Swift + Rust hybrid project

.PHONY: all build bootstrap swift rust xcframework check-prereqs clean test test-rust test-swift test-cli format format-rust format-swift lint lint-rust lint-swift help install uninstall debug headers check docs ci clean-rust clean-swift clean-xcframework

# Default target
all: build

# Rust build configuration
RUST_DIR := rust-core
RUST_TARGET := release
RUST_LIB := $(RUST_DIR)/target/$(RUST_TARGET)/libosxcore.a
INCLUDE_DIR := include

# Swift build configuration
SWIFT_BUILD_DIR := .build
SWIFT_CONFIG := release

# XCFramework build artifacts
XCFRAMEWORK_DIR := Frameworks/COSXCore.xcframework
XCFRAMEWORK_BUILD_DIR := build/xcframework

# Minimum macOS version forwarded to both Rust (via RUSTFLAGS in
# scripts/build-xcframework.sh) and Swift builds, keeping it aligned with
# Package.swift's .macOS(.v14) platform spec. Override via the environment
# (e.g. `MACOSX_DEPLOYMENT_TARGET=15.0 make xcframework`) to bump the floor
# without editing the Makefile.
export MACOSX_DEPLOYMENT_TARGET ?= 14.0

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# =============================================================================
# Main Targets
# =============================================================================

## Build everything from a clean checkout
build: xcframework swift
	@echo "$(GREEN)Build complete!$(NC)"

## Generate local SwiftPM binary target artifact
bootstrap: xcframework

## Build only Rust core (host architecture, used for tests and dev)
rust:
	@echo "$(YELLOW)Building Rust core...$(NC)"
	@mkdir -p $(INCLUDE_DIR)
	cd $(RUST_DIR) && cargo build --release
	@echo "$(GREEN)Rust build complete$(NC)"

## Validate XCFramework build prerequisites without building anything
check-prereqs:
	@echo "$(YELLOW)Checking XCFramework build prerequisites...$(NC)"
	./scripts/build-xcframework.sh --check
	@echo "$(GREEN)Prerequisites OK$(NC)"

## Build the universal XCFramework consumed by SwiftPM and Xcode
xcframework:
	@echo "$(YELLOW)Building XCFramework...$(NC)"
	./scripts/build-xcframework.sh
	@echo "$(GREEN)XCFramework build complete$(NC)"

## Build only Swift (builds the XCFramework first)
swift: xcframework
	@echo "$(YELLOW)Building Swift...$(NC)"
	swift build -c $(SWIFT_CONFIG)
	@echo "$(GREEN)Swift build complete$(NC)"

## Build for debug
debug: xcframework
	@echo "$(YELLOW)Building debug...$(NC)"
	swift build
	@echo "$(GREEN)Debug build complete$(NC)"

# =============================================================================
# Test Targets
# =============================================================================

## Run all tests
test: test-rust test-swift
	@echo "$(GREEN)All tests passed!$(NC)"

## Run Rust tests
test-rust:
	@echo "$(YELLOW)Running Rust tests...$(NC)"
	cd $(RUST_DIR) && cargo test
	@echo "$(GREEN)Rust tests passed$(NC)"

## Run Swift tests
test-swift: xcframework
	@echo "$(YELLOW)Running Swift tests...$(NC)"
	swift build --product osxcleaner
	OSXCLEANER_CLI_PATH="$$(swift build --show-bin-path)/osxcleaner" swift test
	@echo "$(GREEN)Swift tests passed$(NC)"

## Run CLI integration tests
test-cli: xcframework
	@echo "$(YELLOW)Running CLI integration tests...$(NC)"
	swift build --product osxcleaner
	OSXCLEANER_CLI_PATH="$$(swift build --show-bin-path)/osxcleaner" swift test --filter osxcleanerCLITests
	@echo "$(GREEN)CLI integration tests passed$(NC)"

# =============================================================================
# Quality Targets
# =============================================================================

## Format all code
format: format-rust format-swift
	@echo "$(GREEN)All code formatted$(NC)"

## Format Rust code
format-rust:
	@echo "$(YELLOW)Formatting Rust code...$(NC)"
	cd $(RUST_DIR) && cargo fmt

## Format Swift code (requires swift-format)
format-swift:
	@echo "$(YELLOW)Formatting Swift code...$(NC)"
	@if command -v swift-format > /dev/null; then \
		find Sources Tests -name "*.swift" -exec swift-format -i {} \; ; \
	else \
		echo "$(YELLOW)swift-format not installed, skipping...$(NC)"; \
	fi

## Lint all code
lint: lint-rust lint-swift
	@echo "$(GREEN)All linting passed$(NC)"

## Lint Rust code
lint-rust:
	@echo "$(YELLOW)Linting Rust code...$(NC)"
	cd $(RUST_DIR) && cargo clippy -- -D warnings

## Lint Swift code (requires swiftlint)
lint-swift:
	@echo "$(YELLOW)Linting Swift code...$(NC)"
	@if command -v swiftlint > /dev/null; then \
		swiftlint --strict; \
	else \
		echo "$(YELLOW)swiftlint not installed, skipping...$(NC)"; \
	fi

# =============================================================================
# Clean Targets
# =============================================================================

## Clean all build artifacts
clean: clean-rust clean-swift clean-xcframework
	@rm -rf $(INCLUDE_DIR)/osxcore.h
	@echo "$(GREEN)Clean complete$(NC)"

## Clean the XCFramework and its staging directory
clean-xcframework:
	@echo "$(YELLOW)Cleaning XCFramework...$(NC)"
	@rm -rf $(XCFRAMEWORK_DIR) $(XCFRAMEWORK_BUILD_DIR)

## Clean Rust build artifacts
clean-rust:
	@echo "$(YELLOW)Cleaning Rust...$(NC)"
	cd $(RUST_DIR) && cargo clean

## Clean Swift build artifacts
clean-swift:
	@echo "$(YELLOW)Cleaning Swift...$(NC)"
	rm -rf $(SWIFT_BUILD_DIR)
	rm -rf .swiftpm

# =============================================================================
# Install/Uninstall Targets
# =============================================================================

## Install osxcleaner to /usr/local/bin
install: build
	@echo "$(YELLOW)Installing osxcleaner...$(NC)"
	@mkdir -p /usr/local/bin
	cp $(SWIFT_BUILD_DIR)/$(SWIFT_CONFIG)/osxcleaner /usr/local/bin/
	@echo "$(GREEN)Installed to /usr/local/bin/osxcleaner$(NC)"

## Uninstall osxcleaner
uninstall:
	@echo "$(YELLOW)Uninstalling osxcleaner...$(NC)"
	rm -f /usr/local/bin/osxcleaner
	@echo "$(GREEN)Uninstalled$(NC)"

# =============================================================================
# Development Targets
# =============================================================================

## Generate FFI headers only
headers:
	@echo "$(YELLOW)Generating FFI headers...$(NC)"
	@mkdir -p $(INCLUDE_DIR)
	cd $(RUST_DIR) && cargo build --release
	@echo "$(GREEN)Headers generated at $(INCLUDE_DIR)/osxcore.h$(NC)"

## Check all code without building
check: xcframework
	@echo "$(YELLOW)Checking Rust...$(NC)"
	cd $(RUST_DIR) && cargo check
	@echo "$(YELLOW)Checking Swift...$(NC)"
	swift build --build-tests
	@echo "$(GREEN)All checks passed$(NC)"

## Run the CLI in development mode
run: debug
	$(SWIFT_BUILD_DIR)/debug/osxcleaner $(ARGS)

## Generate documentation
docs:
	@echo "$(YELLOW)Generating Rust documentation...$(NC)"
	cd $(RUST_DIR) && cargo doc --no-deps
	@echo "$(GREEN)Documentation generated$(NC)"

# =============================================================================
# CI Targets
# =============================================================================

## Run CI checks (format, lint, test)
ci: check lint test
	@echo "$(GREEN)CI checks passed!$(NC)"

# =============================================================================
# Help
# =============================================================================

## Show this help
help:
	@echo "OSX Cleaner Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN { desc = "" } \
		/^## / { desc = substr($$0, 4); next } \
		/^[a-zA-Z0-9_-]+:/ && desc != "" { split($$0, parts, ":"); printf "  $(GREEN)%-20s$(NC) %s\n", parts[1], desc; desc = ""; next } \
		{ desc = "" }' $(MAKEFILE_LIST)
	@echo ""
	@echo "Examples:"
	@echo "  make build        Build everything from a clean checkout"
	@echo "  make xcframework  Generate the SwiftPM binary target artifact"
	@echo "  make test         Run all tests"
	@echo "  make clean        Clean all build artifacts"
	@echo "  make install      Install to /usr/local/bin"
