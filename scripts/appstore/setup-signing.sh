#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2021-2025, kcenon
#
# Setup and verify code signing configuration for OSX Cleaner

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_DIR="${PROJECT_DIR}/.signing"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Setup and verify code signing configuration for OSX Cleaner.

OPTIONS:
    --check             Check current signing configuration
    --list-identities   List available signing identities
    --verify            Verify app signature
    --export-env        Export environment variables template
    --setup-keychain    Setup CI keychain (for GitHub Actions)
    --help              Show this help message

ENVIRONMENT VARIABLES:
    DEVELOPMENT_TEAM            Apple Developer Team ID
    SIGNING_IDENTITY            Full name of signing certificate
    APPLE_ID                    Apple ID email for notarization
    APPLE_TEAM_ID               Team ID for notarization
    APPLE_APP_SPECIFIC_PASSWORD App-specific password for notarization

EXAMPLES:
    # Check current configuration
    $(basename "$0") --check

    # List available signing identities
    $(basename "$0") --list-identities

    # Verify built app signature
    $(basename "$0") --verify .build/appstore/OSX\\ Cleaner.app

    # Export environment template
    $(basename "$0") --export-env > .env.signing
EOF
}

list_identities() {
    section "Available Signing Identities"

    echo -e "\n${BLUE}Developer ID Application (for notarization):${NC}"
    security find-identity -v -p codesigning | grep "Developer ID Application" || \
        warn "No Developer ID Application certificates found"

    echo -e "\n${BLUE}Apple Distribution (for App Store):${NC}"
    security find-identity -v -p codesigning | grep "Apple Distribution" || \
        warn "No Apple Distribution certificates found"

    echo -e "\n${BLUE}Mac Developer (for development):${NC}"
    security find-identity -v -p codesigning | grep "Mac Developer" || \
        warn "No Mac Developer certificates found"

    echo -e "\n${BLUE}3rd Party Mac Developer Application:${NC}"
    security find-identity -v -p codesigning | grep "3rd Party Mac Developer Application" || \
        warn "No 3rd Party Mac Developer Application certificates found"
}

check_configuration() {
    section "Checking Signing Configuration"

    local errors=0

    # Check for Xcode
    if command -v xcodebuild &> /dev/null; then
        local xcode_version
        xcode_version=$(xcodebuild -version | head -1)
        info "Xcode: ${xcode_version}"
    else
        warn "Xcode not found"
        ((errors++))
    fi

    # Check for signing identities
    echo ""
    local dev_id_count
    dev_id_count=$(security find-identity -v -p codesigning | grep -c "Developer ID Application" || echo "0")
    local apple_dist_count
    apple_dist_count=$(security find-identity -v -p codesigning | grep -c "Apple Distribution" || echo "0")

    if [[ "${dev_id_count}" -gt 0 ]]; then
        info "Developer ID Application certificates: ${dev_id_count}"
    else
        warn "No Developer ID Application certificates found"
        warn "  -> Required for distribution outside App Store"
    fi

    if [[ "${apple_dist_count}" -gt 0 ]]; then
        info "Apple Distribution certificates: ${apple_dist_count}"
    else
        warn "No Apple Distribution certificates found"
        warn "  -> Required for App Store distribution"
    fi

    # Check environment variables
    section "Environment Variables"

    if [[ -n "${DEVELOPMENT_TEAM}" ]]; then
        info "DEVELOPMENT_TEAM: ${DEVELOPMENT_TEAM}"
    else
        warn "DEVELOPMENT_TEAM: not set"
        ((errors++))
    fi

    if [[ -n "${SIGNING_IDENTITY}" ]]; then
        info "SIGNING_IDENTITY: ${SIGNING_IDENTITY}"
        # Verify the identity exists
        if security find-identity -v -p codesigning | grep -q "${SIGNING_IDENTITY}"; then
            info "  -> Certificate found in keychain"
        else
            warn "  -> Certificate NOT found in keychain"
            ((errors++))
        fi
    else
        warn "SIGNING_IDENTITY: not set (will auto-detect)"
    fi

    if [[ -n "${APPLE_ID}" ]]; then
        info "APPLE_ID: ${APPLE_ID}"
    else
        warn "APPLE_ID: not set (required for notarization)"
    fi

    if [[ -n "${APPLE_TEAM_ID}" ]]; then
        info "APPLE_TEAM_ID: ${APPLE_TEAM_ID}"
    else
        warn "APPLE_TEAM_ID: not set (required for notarization)"
    fi

    if [[ -n "${APPLE_APP_SPECIFIC_PASSWORD}" ]]; then
        info "APPLE_APP_SPECIFIC_PASSWORD: [set]"
    else
        warn "APPLE_APP_SPECIFIC_PASSWORD: not set (required for notarization)"
    fi

    # Check project.yml
    section "Project Configuration"

    if [[ -f "${PROJECT_DIR}/project.yml" ]]; then
        info "project.yml found"

        if grep -q "CODE_SIGN_STYLE:" "${PROJECT_DIR}/project.yml"; then
            local sign_style
            sign_style=$(grep "CODE_SIGN_STYLE:" "${PROJECT_DIR}/project.yml" | head -1 | awk '{print $2}')
            info "CODE_SIGN_STYLE: ${sign_style}"
        fi

        if grep -q "ENABLE_HARDENED_RUNTIME:" "${PROJECT_DIR}/project.yml"; then
            info "Hardened Runtime: enabled"
        else
            warn "Hardened Runtime: not configured"
            ((errors++))
        fi
    else
        error "project.yml not found"
    fi

    # Check entitlements
    section "Entitlements"

    local gui_entitlements="${PROJECT_DIR}/Supporting/OSXCleanerGUI.entitlements"
    local cli_entitlements="${PROJECT_DIR}/Supporting/osxcleaner.entitlements"

    if [[ -f "${gui_entitlements}" ]]; then
        info "GUI entitlements: found"
        if plutil -lint "${gui_entitlements}" > /dev/null 2>&1; then
            info "  -> Format valid"
        else
            warn "  -> Format invalid"
            ((errors++))
        fi
    else
        warn "GUI entitlements: not found"
        ((errors++))
    fi

    if [[ -f "${cli_entitlements}" ]]; then
        info "CLI entitlements: found"
    else
        warn "CLI entitlements: not found"
    fi

    # Summary
    section "Summary"

    if [[ ${errors} -eq 0 ]]; then
        info "All checks passed!"
        return 0
    else
        warn "${errors} issue(s) found. See warnings above."
        return 1
    fi
}

verify_app() {
    local app_path="${1:-${PROJECT_DIR}/.build/appstore/OSX Cleaner.app}"

    section "Verifying App Signature"

    if [[ ! -d "${app_path}" ]]; then
        error "App not found: ${app_path}"
    fi

    info "Verifying: ${app_path}"
    echo ""

    # Basic signature verification
    echo -e "${BLUE}Signature Verification:${NC}"
    if codesign --verify --verbose=2 "${app_path}" 2>&1; then
        info "Signature: VALID"
    else
        warn "Signature: INVALID or not signed"
    fi
    echo ""

    # Display signing info
    echo -e "${BLUE}Signing Information:${NC}"
    codesign --display --verbose=2 "${app_path}" 2>&1 || true
    echo ""

    # Check entitlements
    echo -e "${BLUE}Entitlements:${NC}"
    codesign --display --entitlements :- "${app_path}" 2>/dev/null || \
        warn "No entitlements or unable to read"
    echo ""

    # Check hardened runtime
    echo -e "${BLUE}Hardened Runtime:${NC}"
    if codesign --display --verbose "${app_path}" 2>&1 | grep -q "flags=.*runtime"; then
        info "Hardened Runtime: enabled"
    else
        warn "Hardened Runtime: not enabled"
    fi
    echo ""

    # Check notarization status
    echo -e "${BLUE}Notarization Status:${NC}"
    if spctl --assess --verbose=4 --type exec "${app_path}" 2>&1; then
        info "Notarization: accepted by Gatekeeper"
    else
        warn "Notarization: not notarized or not accepted"
    fi
}

export_env_template() {
    cat << 'EOF'
# OSX Cleaner Code Signing Configuration
# Copy this file to .env.signing.local and fill in your values
# DO NOT commit this file with real values

# Apple Developer Team ID (10-character alphanumeric)
# Find at: https://developer.apple.com/account -> Membership
export DEVELOPMENT_TEAM=""

# Code signing identity (full name)
# Use: security find-identity -v -p codesigning
# Examples:
#   "Developer ID Application: Your Name (TEAM_ID)"     - for notarization
#   "Apple Distribution: Your Name (TEAM_ID)"           - for App Store
#   "Mac Developer: Your Name (TEAM_ID)"                - for development
export SIGNING_IDENTITY=""

# Apple ID email for notarization
export APPLE_ID=""

# Apple Team ID (same as DEVELOPMENT_TEAM)
export APPLE_TEAM_ID=""

# App-specific password for notarization
# Generate at: https://appleid.apple.com/account/manage -> App-Specific Passwords
export APPLE_APP_SPECIFIC_PASSWORD=""

# Optional: Keychain settings for CI
# export KEYCHAIN_PATH="${HOME}/Library/Keychains/build.keychain-db"
# export KEYCHAIN_PASSWORD=""
EOF
}

setup_ci_keychain() {
    section "Setting up CI Keychain"

    local keychain_path="${KEYCHAIN_PATH:-${HOME}/Library/Keychains/build.keychain-db}"
    local keychain_password="${KEYCHAIN_PASSWORD:-$(openssl rand -base64 32)}"

    # Check required variables
    if [[ -z "${CERTIFICATE_BASE64}" ]]; then
        error "CERTIFICATE_BASE64 environment variable required"
    fi

    if [[ -z "${CERTIFICATE_PASSWORD}" ]]; then
        error "CERTIFICATE_PASSWORD environment variable required"
    fi

    info "Creating keychain: ${keychain_path}"

    # Create temporary directory for certificate
    local cert_dir
    cert_dir=$(mktemp -d)
    local cert_path="${cert_dir}/certificate.p12"

    # Decode certificate
    echo "${CERTIFICATE_BASE64}" | base64 --decode > "${cert_path}"

    # Create keychain
    security create-keychain -p "${keychain_password}" "${keychain_path}" || true
    security set-keychain-settings -lut 21600 "${keychain_path}"
    security unlock-keychain -p "${keychain_password}" "${keychain_path}"

    # Import certificate
    security import "${cert_path}" \
        -P "${CERTIFICATE_PASSWORD}" \
        -A \
        -t cert \
        -f pkcs12 \
        -k "${keychain_path}"

    # Set key partition list
    security set-key-partition-list \
        -S apple-tool:,apple: \
        -s \
        -k "${keychain_password}" \
        "${keychain_path}"

    # Add to search list
    security list-keychains -d user -s "${keychain_path}" $(security list-keychains -d user | xargs)

    # Cleanup
    rm -rf "${cert_dir}"

    info "Keychain setup complete"
    info "Remember to run 'security delete-keychain ${keychain_path}' after build"
}

# Main
case "${1:-}" in
    --check)
        check_configuration
        ;;
    --list-identities)
        list_identities
        ;;
    --verify)
        shift
        verify_app "$@"
        ;;
    --export-env)
        export_env_template
        ;;
    --setup-keychain)
        setup_ci_keychain
        ;;
    --help|-h)
        usage
        ;;
    *)
        if [[ -n "${1:-}" ]]; then
            error "Unknown option: $1"
        fi
        usage
        ;;
esac
