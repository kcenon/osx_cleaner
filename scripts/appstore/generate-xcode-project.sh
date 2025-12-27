#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2021-2025, kcenon

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if XcodeGen is installed
check_xcodegen() {
    if ! command -v xcodegen &> /dev/null; then
        log_error "XcodeGen is not installed."
        log_info "Install with: brew install xcodegen"
        exit 1
    fi
    log_info "XcodeGen found: $(which xcodegen)"
}

# Check if Rust library exists
check_rust_library() {
    local rust_lib="${PROJECT_ROOT}/rust-core/target/release/libosxcore.a"
    local rust_dylib="${PROJECT_ROOT}/rust-core/target/release/libosxcore.dylib"

    if [[ ! -f "${rust_lib}" ]] && [[ ! -f "${rust_dylib}" ]]; then
        log_warning "Rust library not found. Building..."
        build_rust_library
    else
        log_info "Rust library found"
    fi
}

# Build Rust library
build_rust_library() {
    log_info "Building Rust core library..."
    cd "${PROJECT_ROOT}/rust-core"

    if ! command -v cargo &> /dev/null; then
        log_error "Cargo is not installed. Please install Rust."
        exit 1
    fi

    cargo build --release

    if [[ -f "target/release/libosxcore.a" ]] || [[ -f "target/release/libosxcore.dylib" ]]; then
        log_success "Rust library built successfully"
    else
        log_error "Failed to build Rust library"
        exit 1
    fi

    cd "${PROJECT_ROOT}"
}

# Generate Xcode project using XcodeGen
generate_xcode_project() {
    log_info "Generating Xcode project from project.yml..."

    cd "${PROJECT_ROOT}"

    # Clean existing project if requested
    if [[ "${CLEAN:-false}" == "true" ]]; then
        if [[ -d "OSXCleaner.xcodeproj" ]]; then
            log_info "Removing existing Xcode project..."
            rm -rf OSXCleaner.xcodeproj
        fi
    fi

    # Generate project
    xcodegen generate --spec project.yml

    if [[ -d "OSXCleaner.xcodeproj" ]]; then
        log_success "Xcode project generated: OSXCleaner.xcodeproj"
    else
        log_error "Failed to generate Xcode project"
        exit 1
    fi
}

# Verify generated project
verify_project() {
    log_info "Verifying Xcode project..."

    local project_file="${PROJECT_ROOT}/OSXCleaner.xcodeproj/project.pbxproj"

    if [[ ! -f "${project_file}" ]]; then
        log_error "project.pbxproj not found"
        exit 1
    fi

    # Check targets
    local targets=("OSXCleanerGUI" "osxcleaner" "OSXCleanerKit" "OSXCleanerKitTests")
    for target in "${targets[@]}"; do
        if grep -q "name = ${target}" "${project_file}"; then
            log_info "  Target found: ${target}"
        else
            log_warning "  Target not found: ${target}"
        fi
    done

    # Check schemes
    local scheme_dir="${PROJECT_ROOT}/OSXCleaner.xcodeproj/xcshareddata/xcschemes"
    if [[ -d "${scheme_dir}" ]]; then
        log_info "  Schemes directory found"
        ls -1 "${scheme_dir}"/*.xcscheme 2>/dev/null | while read -r scheme; do
            log_info "    - $(basename "${scheme}" .xcscheme)"
        done
    else
        log_warning "  Schemes directory not found"
    fi

    log_success "Xcode project verification complete"
}

# Open project in Xcode (optional)
open_in_xcode() {
    if [[ "${OPEN_XCODE:-false}" == "true" ]]; then
        log_info "Opening project in Xcode..."
        open "${PROJECT_ROOT}/OSXCleaner.xcodeproj"
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Generate Xcode project from project.yml using XcodeGen"
    echo ""
    echo "Options:"
    echo "  --clean         Remove existing project before generating"
    echo "  --open          Open project in Xcode after generation"
    echo "  --skip-rust     Skip Rust library check/build"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    Generate Xcode project"
    echo "  $0 --clean            Clean and regenerate project"
    echo "  $0 --clean --open     Clean, regenerate, and open in Xcode"
}

# Main
main() {
    local skip_rust=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                CLEAN=true
                shift
                ;;
            --open)
                OPEN_XCODE=true
                shift
                ;;
            --skip-rust)
                skip_rust=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    echo ""
    log_info "=== OSX Cleaner Xcode Project Generator ==="
    echo ""

    check_xcodegen

    if [[ "${skip_rust}" == "false" ]]; then
        check_rust_library
    fi

    generate_xcode_project
    verify_project
    open_in_xcode

    echo ""
    log_success "=== Xcode project generation complete ==="
    echo ""
    log_info "Next steps:"
    log_info "  1. Open OSXCleaner.xcodeproj in Xcode"
    log_info "  2. Configure your development team in project settings"
    log_info "  3. Build and run the app"
    echo ""
}

main "$@"
