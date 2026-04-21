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

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m"

log()  { printf "%b%s%b\n" "${YELLOW}" "$1" "${NC}"; }
ok()   { printf "%b%s%b\n" "${GREEN}"  "$1" "${NC}"; }
fail() { printf "%b%s%b\n" "${RED}"    "$1" "${NC}" >&2; exit 1; }

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

require_command cargo
require_command rustup
require_command lipo
require_command xcodebuild

log "Ensuring Rust targets are installed..."
for target in "${ARM64_TARGET}" "${X86_64_TARGET}"; do
    if ! rustup target list --installed | grep -q "^${target}$"; then
        log "  Installing target: ${target}"
        rustup target add "${target}"
    fi
done

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
[[ -f "${INCLUDE_DIR}/osxcore.h" ]] || fail "Missing generated header: ${INCLUDE_DIR}/osxcore.h (run cargo build first)"
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
