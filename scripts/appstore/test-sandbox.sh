#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊
#
# Test App Sandbox compliance for OSX Cleaner GUI

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_PATH="${PROJECT_DIR}/.build/appstore/OSX Cleaner.app"
ENTITLEMENTS_FILE="${PROJECT_DIR}/Supporting/OSXCleanerGUI.entitlements"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
check() { echo -e "${BLUE}[CHECK]${NC} $1"; }

echo "=============================================="
echo "  OSX Cleaner - Sandbox Compliance Test"
echo "=============================================="
echo ""

# Test 1: Verify entitlements file exists
check "Verifying entitlements file exists..."
if [[ -f "${ENTITLEMENTS_FILE}" ]]; then
    info "Entitlements file found: ${ENTITLEMENTS_FILE}"
else
    error "Entitlements file not found: ${ENTITLEMENTS_FILE}"
    exit 1
fi

# Test 2: Validate entitlements file format
check "Validating entitlements file format..."
if plutil -lint "${ENTITLEMENTS_FILE}" > /dev/null 2>&1; then
    info "Entitlements file is valid plist format"
else
    error "Entitlements file is not valid plist format"
    exit 1
fi

# Test 3: Check required entitlements
check "Checking required entitlements..."

REQUIRED_ENTITLEMENTS=(
    "com.apple.security.app-sandbox"
    "com.apple.security.files.user-selected.read-write"
    "com.apple.security.files.downloads.read-write"
    "com.apple.security.files.bookmarks.app-scope"
    "com.apple.security.network.client"
    "com.apple.security.network.server"
)

ENTITLEMENTS_CONTENT=$(cat "${ENTITLEMENTS_FILE}")
ALL_PRESENT=true

for entitlement in "${REQUIRED_ENTITLEMENTS[@]}"; do
    if echo "${ENTITLEMENTS_CONTENT}" | grep -q "${entitlement}"; then
        info "  [OK] ${entitlement}"
    else
        error "  [MISSING] ${entitlement}"
        ALL_PRESENT=false
    fi
done

if [[ "${ALL_PRESENT}" != "true" ]]; then
    error "Some required entitlements are missing"
    exit 1
fi

# Test 4: Verify app-sandbox is enabled
check "Verifying app-sandbox is enabled..."
if echo "${ENTITLEMENTS_CONTENT}" | grep -A1 "com.apple.security.app-sandbox" | grep -q "<true/>"; then
    info "App Sandbox is enabled"
else
    error "App Sandbox is NOT enabled"
    exit 1
fi

# Test 5: Check project.yml synchronization
check "Checking project.yml entitlements synchronization..."
PROJECT_YML="${PROJECT_DIR}/project.yml"

if [[ -f "${PROJECT_YML}" ]]; then
    PROJECT_YML_CONTENT=$(cat "${PROJECT_YML}")

    for entitlement in "${REQUIRED_ENTITLEMENTS[@]}"; do
        # Convert entitlement key to project.yml format
        if echo "${PROJECT_YML_CONTENT}" | grep -q "${entitlement}"; then
            info "  [OK] ${entitlement} in project.yml"
        else
            warn "  [MISSING] ${entitlement} in project.yml"
        fi
    done
else
    warn "project.yml not found, skipping synchronization check"
fi

# Test 6: If app exists, verify embedded entitlements
if [[ -d "${APP_PATH}" ]]; then
    check "Verifying embedded entitlements in built app..."

    EMBEDDED_ENTITLEMENTS=$(codesign -d --entitlements :- "${APP_PATH}" 2>/dev/null || echo "")

    if [[ -n "${EMBEDDED_ENTITLEMENTS}" ]]; then
        for entitlement in "${REQUIRED_ENTITLEMENTS[@]}"; do
            if echo "${EMBEDDED_ENTITLEMENTS}" | grep -q "${entitlement}"; then
                info "  [OK] ${entitlement} embedded in app"
            else
                warn "  [MISSING] ${entitlement} not embedded in app"
            fi
        done
    else
        warn "Could not extract entitlements from app (may not be signed)"
    fi
else
    warn "Built app not found at ${APP_PATH}, skipping embedded entitlements check"
    info "Run './scripts/appstore/build-app.sh' to build the app first"
fi

# Test 7: Check for hardened runtime
check "Checking hardened runtime configuration..."
if grep -q "ENABLE_HARDENED_RUNTIME: YES" "${PROJECT_YML}"; then
    info "Hardened Runtime is enabled in project.yml"
else
    error "Hardened Runtime is NOT enabled in project.yml"
    exit 1
fi

# Summary
echo ""
echo "=============================================="
echo "  Sandbox Compliance Test Summary"
echo "=============================================="
echo ""
info "All required entitlements are configured correctly"
echo ""
echo "Configured entitlements:"
for entitlement in "${REQUIRED_ENTITLEMENTS[@]}"; do
    echo "  - ${entitlement}"
done
echo ""
info "Note: For full sandbox testing, build and run the app:"
echo "  1. ./scripts/appstore/build-app.sh --sign"
echo "  2. Launch the app and test all features"
echo "  3. Check Console.app for sandbox violations"
echo ""

exit 0
