#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊
#
# Build OSX Cleaner GUI app bundle for distribution

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build/appstore"
APP_NAME="OSX Cleaner"
BUNDLE_ID="com.kcenon.osxcleaner"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Parse arguments
CONFIGURATION="release"
SIGN_APP=false
NOTARIZE_APP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --debug) CONFIGURATION="debug"; shift ;;
        --sign) SIGN_APP=true; shift ;;
        --notarize) NOTARIZE_APP=true; SIGN_APP=true; shift ;;
        --version) VERSION="$2"; shift 2 ;;
        --build) BUILD_NUMBER="$2"; shift 2 ;;
        *) error "Unknown option: $1" ;;
    esac
done

info "Building OSX Cleaner v${VERSION} (build ${BUILD_NUMBER})"
info "Configuration: ${CONFIGURATION}"

# Build Rust core first
info "Building Rust core library..."
cd "${PROJECT_DIR}/rust-core"
if [[ "${CONFIGURATION}" == "release" ]]; then
    cargo build --release
else
    cargo build
fi

# Build Swift Package
info "Building Swift package..."
cd "${PROJECT_DIR}"
if [[ "${CONFIGURATION}" == "release" ]]; then
    swift build -c release --product OSXCleanerGUI
    SWIFT_BUILD_DIR="${PROJECT_DIR}/.build/release"
else
    swift build --product OSXCleanerGUI
    SWIFT_BUILD_DIR="${PROJECT_DIR}/.build/debug"
fi

# Create app bundle structure
info "Creating app bundle..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/${APP_NAME}.app/Contents/MacOS"
mkdir -p "${BUILD_DIR}/${APP_NAME}.app/Contents/Resources"
mkdir -p "${BUILD_DIR}/${APP_NAME}.app/Contents/Frameworks"

# Copy executable
cp "${SWIFT_BUILD_DIR}/OSXCleanerGUI" "${BUILD_DIR}/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

# Copy Rust library
RUST_LIB_DIR="${PROJECT_DIR}/rust-core/target/${CONFIGURATION}"
if [[ -f "${RUST_LIB_DIR}/libosxcore.dylib" ]]; then
    cp "${RUST_LIB_DIR}/libosxcore.dylib" "${BUILD_DIR}/${APP_NAME}.app/Contents/Frameworks/"
    # Update install name
    install_name_tool -change \
        "${RUST_LIB_DIR}/libosxcore.dylib" \
        "@executable_path/../Frameworks/libosxcore.dylib" \
        "${BUILD_DIR}/${APP_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
fi

# Copy localization resources
RESOURCES_DIR="${PROJECT_DIR}/Sources/OSXCleanerGUI/Resources"
if [[ -d "${RESOURCES_DIR}" ]]; then
    cp -R "${RESOURCES_DIR}"/* "${BUILD_DIR}/${APP_NAME}.app/Contents/Resources/" 2>/dev/null || true
fi

# Generate Info.plist
cat > "${BUILD_DIR}/${APP_NAME}.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2021-2025 kcenon. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
EOF

# Generate PkgInfo
echo -n "APPL????" > "${BUILD_DIR}/${APP_NAME}.app/Contents/PkgInfo"

# Code signing
if [[ "${SIGN_APP}" == true ]]; then
    info "Signing app bundle..."

    if [[ -z "${SIGNING_IDENTITY}" ]]; then
        # Try to find a valid signing identity
        SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')
    fi

    if [[ -z "${SIGNING_IDENTITY}" ]]; then
        warn "No signing identity found. Using ad-hoc signing."
        SIGNING_IDENTITY="-"
    fi

    ENTITLEMENTS_FILE="${PROJECT_DIR}/Supporting/OSXCleanerGUI.entitlements"

    # Sign frameworks first
    if [[ -d "${BUILD_DIR}/${APP_NAME}.app/Contents/Frameworks" ]]; then
        find "${BUILD_DIR}/${APP_NAME}.app/Contents/Frameworks" -type f -name "*.dylib" -exec \
            codesign --force --sign "${SIGNING_IDENTITY}" \
                --options runtime \
                --timestamp \
                {} \;
    fi

    # Sign main executable
    codesign --force --sign "${SIGNING_IDENTITY}" \
        --options runtime \
        --entitlements "${ENTITLEMENTS_FILE}" \
        --timestamp \
        "${BUILD_DIR}/${APP_NAME}.app"

    # Verify signature
    codesign --verify --verbose "${BUILD_DIR}/${APP_NAME}.app"
    info "App signed successfully"
fi

# Notarization
if [[ "${NOTARIZE_APP}" == true ]]; then
    info "Notarizing app..."

    if [[ -z "${APPLE_ID}" ]] || [[ -z "${APPLE_TEAM_ID}" ]]; then
        error "APPLE_ID and APPLE_TEAM_ID environment variables required for notarization"
    fi

    # Create zip for notarization
    NOTARIZE_ZIP="${BUILD_DIR}/${APP_NAME}-notarize.zip"
    ditto -c -k --keepParent "${BUILD_DIR}/${APP_NAME}.app" "${NOTARIZE_ZIP}"

    # Submit for notarization
    xcrun notarytool submit "${NOTARIZE_ZIP}" \
        --apple-id "${APPLE_ID}" \
        --team-id "${APPLE_TEAM_ID}" \
        --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
        --wait

    # Staple the ticket
    xcrun stapler staple "${BUILD_DIR}/${APP_NAME}.app"

    # Clean up
    rm -f "${NOTARIZE_ZIP}"

    info "App notarized successfully"
fi

info "Build complete!"
info "App bundle: ${BUILD_DIR}/${APP_NAME}.app"

# Verify the app can run
if [[ -x "${BUILD_DIR}/${APP_NAME}.app/Contents/MacOS/${APP_NAME}" ]]; then
    info "Executable is ready"
else
    error "Executable not found or not executable"
fi
