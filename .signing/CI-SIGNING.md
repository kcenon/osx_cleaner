# CI/CD Code Signing Setup

This guide explains how to set up code signing for GitHub Actions CI/CD.

## Overview

Signing in CI/CD requires:
1. Exporting certificates as base64-encoded strings
2. Storing credentials as GitHub Secrets
3. Setting up a temporary keychain in the workflow

## Prerequisites

- A valid Developer ID Application or Apple Distribution certificate
- Access to your GitHub repository settings
- The certificate exported as a `.p12` file

## Step 1: Export Certificate

1. Open Keychain Access on your Mac
2. Find your signing certificate (e.g., "Developer ID Application: ...")
3. Right-click and select "Export..."
4. Save as `.p12` with a strong password
5. Convert to base64:
   ```bash
   base64 -i certificate.p12 | pbcopy
   ```

## Step 2: Configure GitHub Secrets

Go to your repository Settings > Secrets and variables > Actions, and add:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `CERTIFICATE_BASE64` | Base64-encoded .p12 certificate | (from step 1) |
| `CERTIFICATE_PASSWORD` | Password for the .p12 file | your-p12-password |
| `DEVELOPMENT_TEAM` | Apple Developer Team ID | ABC123DEF4 |
| `APPLE_ID` | Apple ID for notarization | your@email.com |
| `APPLE_TEAM_ID` | Team ID for notarization | ABC123DEF4 |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password | xxxx-xxxx-xxxx-xxxx |

## Step 3: GitHub Actions Workflow

Create `.github/workflows/build-signed.yml`:

```yaml
name: Build Signed App

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4

      - name: Setup signing
        env:
          CERTIFICATE_BASE64: ${{ secrets.CERTIFICATE_BASE64 }}
          CERTIFICATE_PASSWORD: ${{ secrets.CERTIFICATE_PASSWORD }}
        run: |
          # Create variables
          CERTIFICATE_PATH=$RUNNER_TEMP/certificate.p12
          KEYCHAIN_PATH=$RUNNER_TEMP/build.keychain-db
          KEYCHAIN_PASSWORD=$(openssl rand -base64 32)

          # Import certificate
          echo "$CERTIFICATE_BASE64" | base64 --decode > "$CERTIFICATE_PATH"

          # Create keychain
          security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

          # Import to keychain
          security import "$CERTIFICATE_PATH" \
            -P "$CERTIFICATE_PASSWORD" \
            -A \
            -t cert \
            -f pkcs12 \
            -k "$KEYCHAIN_PATH"

          # Set partition list
          security set-key-partition-list \
            -S apple-tool:,apple: \
            -s \
            -k "$KEYCHAIN_PASSWORD" \
            "$KEYCHAIN_PATH"

          # Add to search list
          security list-keychains -d user -s "$KEYCHAIN_PATH"

          # Export for later steps
          echo "KEYCHAIN_PATH=$KEYCHAIN_PATH" >> $GITHUB_ENV
          echo "KEYCHAIN_PASSWORD=$KEYCHAIN_PASSWORD" >> $GITHUB_ENV

      - name: Install Rust
        uses: dtolnay/rust-action@stable

      - name: Build Rust core
        run: |
          cd rust-core
          cargo build --release

      - name: Build and sign app
        env:
          DEVELOPMENT_TEAM: ${{ secrets.DEVELOPMENT_TEAM }}
        run: |
          ./scripts/appstore/build-app.sh --sign

      - name: Notarize app
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
          APPLE_APP_SPECIFIC_PASSWORD: ${{ secrets.APPLE_APP_SPECIFIC_PASSWORD }}
        run: |
          ./scripts/appstore/notarize.sh ".build/appstore/OSX Cleaner.app"

      - name: Create DMG
        run: |
          ./scripts/appstore/create-dmg.sh --sign

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: OSXCleaner-signed
          path: .build/appstore/*.dmg

      - name: Cleanup keychain
        if: always()
        run: |
          security delete-keychain "$KEYCHAIN_PATH" || true
```

## Step 4: Using App Store Connect API (Alternative)

For App Store submissions, you can use the App Store Connect API instead of password authentication:

1. Generate an API Key at [App Store Connect](https://appstoreconnect.apple.com/access/api)
2. Download the `.p8` key file
3. Add secrets:
   - `APP_STORE_CONNECT_API_KEY_ID`
   - `APP_STORE_CONNECT_API_ISSUER_ID`
   - `APP_STORE_CONNECT_API_KEY` (contents of .p8 file)

```yaml
- name: Notarize with API Key
  run: |
    echo "${{ secrets.APP_STORE_CONNECT_API_KEY }}" > /tmp/AuthKey.p8

    xcrun notarytool submit ".build/appstore/OSX Cleaner.app" \
      --key /tmp/AuthKey.p8 \
      --key-id "${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}" \
      --issuer "${{ secrets.APP_STORE_CONNECT_API_ISSUER_ID }}" \
      --wait

    rm /tmp/AuthKey.p8
```

## Security Best Practices

1. **Rotate credentials regularly** - Update app-specific passwords periodically
2. **Use environments** - Create separate production/staging environments with different secrets
3. **Limit access** - Only grant repository access to trusted team members
4. **Audit logs** - Monitor GitHub Actions logs for unauthorized access
5. **Never log secrets** - Ensure workflows don't echo sensitive values

## Troubleshooting

### "The specified item could not be found in the keychain"
- Ensure certificate is imported correctly
- Check keychain is unlocked
- Verify partition list is set

### "No signing certificate found"
```bash
security find-identity -v -p codesigning
```
- Certificate may have expired
- Team ID may not match

### "Unable to upload to notarization service"
- Verify APPLE_ID and password
- Check for network restrictions
- Ensure hardened runtime is enabled

### "The binary uses an SDK older than 10.9"
- Rebuild with current Xcode version
- Check MACOSX_DEPLOYMENT_TARGET

## References

- [Apple: Creating Distribution-Signed Code for macOS](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [GitHub: Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Apple: App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
