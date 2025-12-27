# Code Signing Configuration

This directory contains templates and instructions for setting up code signing for OSX Cleaner.

## Quick Start

1. Copy the template files to create your local configuration:
   ```bash
   cp .signing/env.template .env.signing.local
   ```

2. Edit `.env.signing.local` with your credentials

3. Source the environment before building:
   ```bash
   source .env.signing.local
   ```

4. Verify configuration:
   ```bash
   ./scripts/appstore/setup-signing.sh --check
   ```

## Configuration Files

| File | Purpose | Committed |
|------|---------|-----------|
| `env.template` | Environment variables template | Yes |
| `exportOptions-appstore.plist` | App Store export options | Yes |
| `exportOptions-developer-id.plist` | Developer ID export options | Yes |
| `.env.signing.local` | Your local credentials | No (gitignored) |

## Required Certificates

### For Development
- **Mac Developer** - For building and testing locally

### For App Store Distribution
- **Apple Distribution** - For App Store submission
- Provisioning profile with App Store distribution capability

### For Direct Distribution (Notarization)
- **Developer ID Application** - For apps distributed outside App Store
- **Developer ID Installer** - For pkg installers (optional)

## Getting Certificates

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/certificates/list)
2. Create certificates for your distribution needs
3. Download and install in Keychain Access

## Provisioning Profiles

For App Store distribution:
1. Go to [Profiles](https://developer.apple.com/account/resources/profiles/list)
2. Create a new Mac App Store profile
3. Select your App ID and certificate
4. Download and install

## CI/CD Setup

See `CI-SIGNING.md` for GitHub Actions setup instructions.

## Troubleshooting

### "No signing certificates found"
```bash
# List available certificates
./scripts/appstore/setup-signing.sh --list-identities

# Check keychain
security find-identity -v -p codesigning
```

### "Provisioning profile doesn't match"
1. Ensure bundle ID matches: `com.kcenon.osxcleaner`
2. Verify certificate is included in profile
3. Check profile is not expired

### "App sandbox conflict"
The GUI app requires sandbox for App Store. Ensure entitlements in `Supporting/OSXCleanerGUI.entitlements` are correct.
