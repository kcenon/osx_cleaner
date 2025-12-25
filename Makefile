# OSX Cleaner - Unified Build System
# This Makefile provides targets for building the Swift + Rust hybrid project

.PHONY: all swift rust clean test format lint help install uninstall

# Default target
all: rust swift

# Rust build configuration
RUST_DIR := rust-core
RUST_TARGET := release
RUST_LIB := $(RUST_DIR)/target/$(RUST_TARGET)/libosxcore.a
INCLUDE_DIR := include

# Swift build configuration
SWIFT_BUILD_DIR := .build
SWIFT_CONFIG := release

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# =============================================================================
# Main Targets
# =============================================================================

## Build everything
all: rust swift
	@echo "$(GREEN)Build complete!$(NC)"

## Build only Rust core
rust:
	@echo "$(YELLOW)Building Rust core...$(NC)"
	@mkdir -p $(INCLUDE_DIR)
	cd $(RUST_DIR) && cargo build --release
	@echo "$(GREEN)Rust build complete$(NC)"

## Build only Swift (requires Rust to be built first)
swift: rust
	@echo "$(YELLOW)Building Swift...$(NC)"
	swift build -c $(SWIFT_CONFIG)
	@echo "$(GREEN)Swift build complete$(NC)"

## Build for debug
debug:
	@echo "$(YELLOW)Building debug...$(NC)"
	cd $(RUST_DIR) && cargo build
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
test-swift:
	@echo "$(YELLOW)Running Swift tests...$(NC)"
	swift test
	@echo "$(GREEN)Swift tests passed$(NC)"

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
clean: clean-rust clean-swift
	@rm -rf $(INCLUDE_DIR)/osxcore.h
	@echo "$(GREEN)Clean complete$(NC)"

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
install: all
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
check:
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
	@grep -E '^## ' $(MAKEFILE_LIST) | \
		sed -e 's/^## //' | \
		awk 'BEGIN {FS = ":"} /^[a-zA-Z_-]+:/ { printf "  $(GREEN)%-15s$(NC) %s\n", $$1, prev } { prev = $$0 }'
	@echo ""
	@echo "Examples:"
	@echo "  make              Build everything (Rust + Swift)"
	@echo "  make test         Run all tests"
	@echo "  make clean        Clean all build artifacts"
	@echo "  make install      Install to /usr/local/bin"
