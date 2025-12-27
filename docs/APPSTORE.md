# App Store Distribution Guide

This document describes how to build, sign, notarize, and distribute OSX Cleaner for the Mac App Store.

## Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- Apple Developer Program membership ($99/year)
- Required certificates (see [Code Signing Setup](#code-signing-setup))
- App-specific password for notarization

## Code Signing Setup

### Quick Start

```bash
# Check current signing configuration
./scripts/appstore/setup-signing.sh --check

# List available signing identities
./scripts/appstore/setup-signing.sh --list-identities

# Export environment template
./scripts/appstore/setup-signing.sh --export-env > .env.signing.local
```

### Required Certificates

| Distribution Type | Certificate | Purpose |
|-------------------|-------------|---------|
| App Store | Apple Distribution | App Store submission |
| Direct Download | Developer ID Application | Notarized distribution outside App Store |
| Development | Mac Developer | Local testing |

### Setting Up Certificates

1. **Create Certificate Signing Request (CSR)**
   - Open Keychain Access > Certificate Assistant > Request a Certificate from a Certificate Authority
   - Save the CSR file

2. **Generate Certificate on Apple Developer Portal**
   - Go to [Certificates](https://developer.apple.com/account/resources/certificates/list)
   - Click "+" and select the appropriate certificate type
   - Upload your CSR and download the certificate

3. **Install Certificate**
   - Double-click the downloaded certificate to install in Keychain

### Environment Configuration

Create `.env.signing.local` from the template:

```bash
cp .signing/env.template .env.signing.local
```

Required variables:

```bash
# Apple Developer Team ID
export DEVELOPMENT_TEAM="YOUR_TEAM_ID"

# Signing identity (full name from keychain)
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"

# For notarization
export APPLE_ID="your@email.com"
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

### Provisioning Profiles (App Store Only)

For App Store distribution:

1. Go to [Profiles](https://developer.apple.com/account/resources/profiles/list)
2. Create new "Mac App Store" profile
3. Select App ID: `com.kcenon.osxcleaner`
4. Select your "Apple Distribution" certificate
5. Download and double-click to install

### Verifying Configuration

```bash
# Verify installed certificates
security find-identity -v -p codesigning

# Check complete configuration
./scripts/appstore/setup-signing.sh --check

# Verify signed app
./scripts/appstore/setup-signing.sh --verify .build/appstore/OSX\ Cleaner.app
```

### CI/CD Integration

For GitHub Actions setup, see [.signing/CI-SIGNING.md](../.signing/CI-SIGNING.md).

Required GitHub Secrets:
- `CERTIFICATE_BASE64` - Base64-encoded .p12 certificate
- `CERTIFICATE_PASSWORD` - .p12 password
- `DEVELOPMENT_TEAM` - Team ID
- `APPLE_ID` - Apple ID email
- `APPLE_TEAM_ID` - Team ID
- `APPLE_APP_SPECIFIC_PASSWORD` - App-specific password

## Build Process

### Quick Build (Development)

```bash
# Build debug version
./scripts/appstore/build-app.sh --debug

# Build release version
./scripts/appstore/build-app.sh
```

### Production Build with Signing

```bash
# Build and sign
./scripts/appstore/build-app.sh --sign

# Build, sign, and notarize
./scripts/appstore/build-app.sh --sign --notarize
```

### Environment Variables for Signing

```bash
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
export APPLE_ID="your@email.com"
export APPLE_TEAM_ID="YOUR_TEAM_ID"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
```

## Build Scripts

### `scripts/appstore/build-app.sh`

Main build script that:
1. Builds Rust core library
2. Builds Swift Package
3. Creates app bundle structure
4. Optionally signs and notarizes

Options:
- `--debug`: Build debug configuration
- `--sign`: Sign the app bundle
- `--notarize`: Submit for Apple notarization
- `--version VERSION`: Set version number
- `--build BUILD_NUMBER`: Set build number

### `scripts/appstore/notarize.sh`

Standalone notarization script for already-built apps.

Requires environment variables:
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

### `scripts/appstore/create-dmg.sh`

Creates DMG installer for distribution outside App Store.

Options:
- `--sign`: Sign the DMG
- `--version VERSION`: Set version in filename

## App Sandbox Entitlements

The GUI app runs with App Sandbox enabled. The following entitlements are configured in `Supporting/OSXCleanerGUI.entitlements`:

| Entitlement | Purpose |
|-------------|---------|
| `com.apple.security.app-sandbox` | Required for App Store distribution |
| `com.apple.security.files.user-selected.read-write` | Access folders selected by user via Open dialog |
| `com.apple.security.files.downloads.read-write` | Access Downloads folder for default operations |
| `com.apple.security.files.bookmarks.app-scope` | Persist folder access across app restarts |
| `com.apple.security.network.client` | Outgoing network connections (updates check) |
| `com.apple.security.network.server` | Local server for Prometheus metrics endpoint |

### Sandbox Compliance Testing

Run the sandbox compliance test before building:

```bash
./scripts/appstore/test-sandbox.sh
```

This verifies:
- All required entitlements are present
- Entitlements file format is valid
- project.yml is synchronized
- Hardened Runtime is enabled

### Sandbox Considerations

Due to App Sandbox restrictions, the GUI app has different capabilities than the CLI tool:

1. **File Access**: The app can only access:
   - Files/folders explicitly selected by the user
   - Downloads folder
   - App's container directory

2. **Cleanup Workflow**: Users must grant access by:
   - Opening folders via NSOpenPanel
   - The app stores security-scoped bookmarks for persistent access

3. **Metrics Server**: Prometheus metrics run on localhost only (127.0.0.1:9090)

4. **Configuration Storage**: Settings are stored in the app's sandboxed container:
   - `~/Library/Containers/com.kcenon.osxcleaner/Data/Library/Application Support/`

## Directory Structure

```
.build/
└── appstore/
    └── OSX Cleaner.app/
        ├── Contents/
        │   ├── Info.plist
        │   ├── MacOS/
        │   │   └── OSX Cleaner
        │   ├── Resources/
        │   │   ├── en.lproj/
        │   │   ├── ko.lproj/
        │   │   └── ja.lproj/
        │   └── Frameworks/
        │       └── libosxcore.dylib
        └── PkgInfo
```

## Notarization Troubleshooting

### Common Issues

1. **"Unable to upload to notarization service"**
   - Verify your Apple ID and app-specific password
   - Check network connectivity

2. **"The signature of the binary is invalid"**
   - Ensure all binaries are signed with hardened runtime
   - Check that entitlements are valid

3. **"The binary uses an SDK older than the 10.9 SDK"**
   - Rebuild with macOS 14.0+ deployment target

### Checking Notarization Status

```bash
xcrun notarytool history \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD"
```

### Getting Detailed Logs

```bash
xcrun notarytool log SUBMISSION_ID \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    notarization-log.json
```

## App Store Submission

### Prepare for Submission

1. Build and notarize the app
2. Create App Store screenshots
3. Prepare app metadata (description, keywords, etc.)
4. Create privacy policy

### Submit via Transporter

1. Export notarized app as `.pkg`
2. Use Transporter app or `xcrun altool` to upload
3. Complete App Store Connect metadata
4. Submit for review

## CLI Tool Distribution

The CLI tool (`osxcleaner`) is distributed separately without App Sandbox:

```bash
# Build CLI
swift build -c release --product osxcleaner

# Sign CLI (if distributing outside App Store)
codesign --force --options runtime --sign "Developer ID Application: ..." \
    .build/release/osxcleaner
```

## Version Management

Version numbers are managed through:
- `--version` flag in build scripts
- `MARKETING_VERSION` in build configuration
- `CFBundleShortVersionString` in Info.plist

Build numbers should be incremented for each submission:
- `--build` flag in build scripts
- `CURRENT_PROJECT_VERSION` in build configuration
- `CFBundleVersion` in Info.plist
