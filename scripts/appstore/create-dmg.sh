#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊
#
# Create DMG installer for OSX Cleaner

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build/appstore"
APP_NAME="OSX Cleaner"
DMG_NAME="OSXCleaner"
VERSION="${VERSION:-1.0.0}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check if app exists
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
    error "App not found at ${APP_PATH}. Run build-app.sh first."
fi

# Parse arguments
SIGN_DMG=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --sign) SIGN_DMG=true; shift ;;
        --version) VERSION="$2"; shift 2 ;;
        *) error "Unknown option: $1" ;;
    esac
done

DMG_OUTPUT="${BUILD_DIR}/${DMG_NAME}-${VERSION}.dmg"
DMG_TEMP="${BUILD_DIR}/dmg-temp"

info "Creating DMG for ${APP_NAME} v${VERSION}..."

# Clean up any existing temp directory
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"

# Copy app to temp directory
cp -R "${APP_PATH}" "${DMG_TEMP}/"

# Create Applications symlink
ln -s /Applications "${DMG_TEMP}/Applications"

# Remove any existing DMG
rm -f "${DMG_OUTPUT}"

# Create DMG
info "Building DMG image..."
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov \
    -format UDBZ \
    "${DMG_OUTPUT}"

# Sign DMG if requested
if [[ "${SIGN_DMG}" == true ]]; then
    info "Signing DMG..."

    if [[ -z "${SIGNING_IDENTITY}" ]]; then
        SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')
    fi

    if [[ -n "${SIGNING_IDENTITY}" ]]; then
        codesign --force --sign "${SIGNING_IDENTITY}" \
            --timestamp \
            "${DMG_OUTPUT}"
        info "DMG signed successfully"
    else
        warn "No signing identity found. DMG is not signed."
    fi
fi

# Clean up
rm -rf "${DMG_TEMP}"

info "DMG created: ${DMG_OUTPUT}"

# Show file info
ls -lh "${DMG_OUTPUT}"
