#!/usr/bin/env bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2021-2025, kcenon
#
# Build a universal XCFramework wrapping the Rust `osxcore` static library
# so SwiftPM can consume it via `.binaryTarget` instead of `unsafeFlags`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUST_DIR="${REPO_ROOT}/rust-core"
INCLUDE_DIR="${REPO_ROOT}/include"
BUILD_DIR="${REPO_ROOT}/build/xcframework"
FRAMEWORKS_DIR="${REPO_ROOT}/Frameworks"
XCFRAMEWORK_PATH="${FRAMEWORKS_DIR}/COSXCore.xcframework"
HEADERS_STAGING="${BUILD_DIR}/Headers"
LIB_NAME="libosxcore.a"
ARM64_TARGET="aarch64-apple-darwin"
X86_64_TARGET="x86_64-apple-darwin"
DEFAULT_MACOSX_DEPLOYMENT_TARGET="14.0"

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m"

log()  { printf "%b%s%b\n" "${YELLOW}" "$1" "${NC}"; }
ok()   { printf "%b%s%b\n" "${GREEN}"  "$1" "${NC}"; }
fail() { printf "%b%s%b\n" "${RED}"    "$1" "${NC}" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: scripts/build-xcframework.sh [--check|--check-prereqs] [--help]

Build Frameworks/COSXCore.xcframework for SwiftPM from the Rust core.

Options:
  --check, --check-prereqs  Validate required tools and Rust targets, then exit.
  -h, --help                Show this help text.

Prerequisites:
  - cargo and rustc 1.75+
  - lipo and xcodebuild from Xcode 15+ or Xcode Command Line Tools
  - aarch64-apple-darwin and x86_64-apple-darwin Rust standard libraries

rustup is optional when the active Rust toolchain already includes both Apple
targets. When rustup is available, missing targets are installed during a normal
build. In --check mode, missing targets are reported without installing them.

Environment:
  MACOSX_DEPLOYMENT_TARGET  Defaults to 14.0 to match Package.swift.
EOF
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    local command_name="$1"
    local hint="${2:-}"

    if command_exists "${command_name}"; then
        return 0
    fi

    if [[ -n "${hint}" ]]; then
        fail "Required command not found: ${command_name}. ${hint}"
    fi

    fail "Required command not found: ${command_name}"
}

target_std_available() {
    local target="$1"
    local target_libdir

    target_libdir="$(rustc --print target-libdir --target "${target}" 2>/dev/null || true)"
    [[ -n "${target_libdir}" && -d "${target_libdir}" ]]
}

ensure_rust_target() {
    local target="$1"

    if target_std_available "${target}"; then
        log "  Target available: ${target}"
        return 0
    fi

    if command_exists rustup; then
        if [[ "${CHECK_ONLY}" == "1" ]]; then
            fail "Rust target is not installed: ${target}. Install it with: rustup target add ${target}"
        fi

        log "  Installing target: ${target}"
        rustup target add "${target}"
    else
        fail "Rust target is not available: ${target}. Install Rust with rustup and run 'rustup target add ${target}', or use a toolchain that already includes the Apple target standard library."
    fi

    target_std_available "${target}" || fail "Rust target is still unavailable after installation attempt: ${target}"
}

check_prerequisites() {
    require_command cargo "Install Rust 1.75+."
    require_command rustc "Install Rust 1.75+."
    require_command lipo "Install Xcode 15+ or Xcode Command Line Tools."
    require_command xcodebuild "Install Xcode 15+ or Xcode Command Line Tools."

    if command_exists rustup; then
        log "rustup found; missing Rust targets can be installed automatically."
    else
        log "rustup not found; using the active Rust toolchain as-is."
        log "Homebrew Rust can work only if both Apple target standard libraries are already installed."
    fi

    log "Using MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET}"

    log "Checking Rust targets..."
    for target in "${ARM64_TARGET}" "${X86_64_TARGET}"; do
        ensure_rust_target "${target}"
    done
}

CHECK_ONLY=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check|--check-prereqs)
            CHECK_ONLY=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            fail "Unknown argument: $1"
            ;;
    esac
done

export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-${DEFAULT_MACOSX_DEPLOYMENT_TARGET}}"

check_prerequisites

if [[ "${CHECK_ONLY}" == "1" ]]; then
    ok "XCFramework prerequisites OK"
    exit 0
fi

log "Building Rust core for ${ARM64_TARGET}..."
(cd "${RUST_DIR}" && cargo build --release --target "${ARM64_TARGET}")

log "Building Rust core for ${X86_64_TARGET}..."
(cd "${RUST_DIR}" && cargo build --release --target "${X86_64_TARGET}")

ARM64_LIB="${RUST_DIR}/target/${ARM64_TARGET}/release/${LIB_NAME}"
X86_64_LIB="${RUST_DIR}/target/${X86_64_TARGET}/release/${LIB_NAME}"
[[ -f "${ARM64_LIB}"  ]] || fail "Missing arm64 static lib: ${ARM64_LIB}"
[[ -f "${X86_64_LIB}" ]] || fail "Missing x86_64 static lib: ${X86_64_LIB}"

log "Combining into universal static library..."
mkdir -p "${BUILD_DIR}"
UNIVERSAL_LIB="${BUILD_DIR}/${LIB_NAME}"
lipo -create "${ARM64_LIB}" "${X86_64_LIB}" -output "${UNIVERSAL_LIB}"
lipo -info "${UNIVERSAL_LIB}"

log "Staging headers and modulemap..."
rm -rf "${HEADERS_STAGING}"
mkdir -p "${HEADERS_STAGING}"
[[ -f "${INCLUDE_DIR}/osxcore.h" ]] || fail "Missing generated header: ${INCLUDE_DIR}/osxcore.h (Cargo build did not generate cbindgen output)"
cp "${INCLUDE_DIR}/osxcore.h" "${HEADERS_STAGING}/osxcore.h"
cat > "${HEADERS_STAGING}/module.modulemap" <<'EOF'
module COSXCore {
    header "osxcore.h"
    link "osxcore"
    export *
}
EOF

log "Assembling XCFramework at ${XCFRAMEWORK_PATH}..."
rm -rf "${XCFRAMEWORK_PATH}"
mkdir -p "${FRAMEWORKS_DIR}"
xcodebuild -create-xcframework \
    -library "${UNIVERSAL_LIB}" \
    -headers "${HEADERS_STAGING}" \
    -output "${XCFRAMEWORK_PATH}"

ok "XCFramework built: ${XCFRAMEWORK_PATH}"
