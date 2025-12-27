#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊
#
# Notarize OSX Cleaner app for distribution

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build/appstore"
APP_NAME="OSX Cleaner"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check required environment variables
check_env() {
    if [[ -z "${APPLE_ID}" ]]; then
        error "APPLE_ID environment variable is required"
    fi
    if [[ -z "${APPLE_TEAM_ID}" ]]; then
        error "APPLE_TEAM_ID environment variable is required"
    fi
    if [[ -z "${APPLE_APP_SPECIFIC_PASSWORD}" ]]; then
        error "APPLE_APP_SPECIFIC_PASSWORD environment variable is required"
    fi
}

# Check if app exists
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
    error "App not found at ${APP_PATH}. Run build-app.sh first."
fi

# Check if app is signed
if ! codesign --verify "${APP_PATH}" 2>/dev/null; then
    error "App is not properly signed. Run build-app.sh --sign first."
fi

check_env

info "Notarizing ${APP_NAME}..."

# Create temporary zip for notarization
NOTARIZE_ZIP="${BUILD_DIR}/${APP_NAME}-notarize.zip"
info "Creating zip archive..."
ditto -c -k --keepParent "${APP_PATH}" "${NOTARIZE_ZIP}"

# Submit for notarization
info "Submitting to Apple notarization service..."
SUBMISSION_OUTPUT=$(xcrun notarytool submit "${NOTARIZE_ZIP}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${APPLE_TEAM_ID}" \
    --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
    --output-format json \
    --wait 2>&1)

# Parse submission ID
SUBMISSION_ID=$(echo "${SUBMISSION_OUTPUT}" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
STATUS=$(echo "${SUBMISSION_OUTPUT}" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)

info "Submission ID: ${SUBMISSION_ID}"
info "Status: ${STATUS}"

if [[ "${STATUS}" == "Accepted" ]]; then
    info "Notarization successful!"

    # Staple the ticket
    info "Stapling notarization ticket..."
    xcrun stapler staple "${APP_PATH}"

    # Verify stapling
    if xcrun stapler validate "${APP_PATH}" 2>/dev/null; then
        info "Stapling verified successfully"
    else
        warn "Stapling verification failed"
    fi
else
    # Get detailed log
    info "Getting notarization log..."
    xcrun notarytool log "${SUBMISSION_ID}" \
        --apple-id "${APPLE_ID}" \
        --team-id "${APPLE_TEAM_ID}" \
        --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
        "${BUILD_DIR}/notarization-log.json"

    cat "${BUILD_DIR}/notarization-log.json"
    error "Notarization failed with status: ${STATUS}"
fi

# Clean up
rm -f "${NOTARIZE_ZIP}"

info "Notarization complete!"
