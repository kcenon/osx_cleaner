# macOS Developer Tools Cache Reference

> Last Updated: 2025-12-25

## Overview

Developer tools (Xcode, iOS Simulator, CocoaPods, Homebrew, etc.) generate large amounts of cache to improve build speed. These caches can reach tens of gigabytes and require regular management.

## Xcode Caches

### Space Usage Overview

| Cache Type | Typical Size | Location |
|----------|-----------|------|
| Derived Data | 5-50GB | `~/Library/Developer/Xcode/DerivedData/` |
| Archives | 1-20GB | `~/Library/Developer/Xcode/Archives/` |
| iOS Device Support | 20-100GB | `~/Library/Developer/Xcode/iOS DeviceSupport/` |
| watchOS Device Support | 5-20GB | `~/Library/Developer/Xcode/watchOS DeviceSupport/` |
| Simulator Runtimes | 5-50GB | `/Library/Developer/CoreSimulator/Profiles/Runtimes/` |

### Derived Data

Stores build intermediate files, indexes, and module caches

```bash
# Location
~/Library/Developer/Xcode/DerivedData/

# Check size
du -sh ~/Library/Developer/Xcode/DerivedData

# Full cleanup (most effective)
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Clean specific project only
rm -rf ~/Library/Developer/Xcode/DerivedData/MyProject-*

# Clean from Xcode
# Xcode → Settings → Locations → Derived Data → Click arrow → Delete
```

#### Derived Data Structure

```
DerivedData/
├── MyProject-abcdef123/
│   ├── Build/              # Build outputs
│   │   ├── Intermediates/  # Intermediate files
│   │   └── Products/       # Build products
│   ├── Index/              # Code index
│   └── Logs/               # Build logs
└── ModuleCache.noindex/    # Swift module cache
```

### Module Cache

```bash
# Module cache location
~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/

# Clean
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/*

# Swift module cache (separate location)
rm -rf ~/Library/Caches/org.swift.swiftpm/
```

### Archives

Stores archives for App Store submission

```bash
# Location
~/Library/Developer/Xcode/Archives/

# Check size
du -sh ~/Library/Developer/Xcode/Archives

# Find old archives (older than 90 days)
find ~/Library/Developer/Xcode/Archives -mtime +90 -type d -name "*.xcarchive"

# Manual cleanup: Xcode → Window → Organizer → Archives → Delete
```

### iOS Device Support

Debug symbols for connected iOS devices

```bash
# Location
~/Library/Developer/Xcode/iOS DeviceSupport/

# Check size (can be very large)
du -sh ~/Library/Developer/Xcode/iOS\ DeviceSupport

# Size by version
du -sh ~/Library/Developer/Xcode/iOS\ DeviceSupport/*

# Clean old versions (except currently used devices)
# Example: Delete iOS 15 and below
find ~/Library/Developer/Xcode/iOS\ DeviceSupport -maxdepth 1 -name "15.*" -type d -exec rm -rf {} \;
```

> **Warning**: After deletion, symbols need to be re-downloaded when connecting devices with that iOS version (takes time)

---

## iOS Simulator

### Simulator Devices

```bash
# List devices
xcrun simctl list devices

# Delete unavailable devices
xcrun simctl delete unavailable

# Erase all simulator content
xcrun simctl erase all

# Delete specific simulator
xcrun simctl delete [DEVICE_UDID]
```

### Simulator Runtimes

```bash
# List runtimes
xcrun simctl runtime list

# Delete unavailable runtimes
xcrun simctl runtime delete unavailable

# Delete specific runtime
xcrun simctl runtime delete [RUNTIME_ID]

# Runtime storage location
/Library/Developer/CoreSimulator/Profiles/Runtimes/
```

### Simulator Caches

```bash
# Simulator cache
~/Library/Developer/CoreSimulator/Caches/

# Simulator device data
~/Library/Developer/CoreSimulator/Devices/

# Clean cache
rm -rf ~/Library/Developer/CoreSimulator/Caches/*

# Reset all simulators (use with caution!)
rm -rf ~/Library/Developer/CoreSimulator/Devices/*
```

---

## Package Managers

### CocoaPods

```bash
# CocoaPods cache location
~/Library/Caches/CocoaPods/

# Check size
du -sh ~/Library/Caches/CocoaPods

# Clean cache
rm -rf ~/Library/Caches/CocoaPods/*

# Or use CocoaPods command
pod cache clean --all
```

### Carthage

```bash
# Carthage cache
~/Library/Caches/org.carthage.CarthageKit/

# Per-project build
./Carthage/Build/

# Clean cache
rm -rf ~/Library/Caches/org.carthage.CarthageKit/*

# Clean in project
rm -rf ./Carthage/Build
```

### Swift Package Manager (SPM)

```bash
# SPM cache location
~/Library/Caches/org.swift.swiftpm/

# Check size
du -sh ~/Library/Caches/org.swift.swiftpm

# Clean cache
rm -rf ~/Library/Caches/org.swift.swiftpm/*

# Clean from Xcode
# File → Packages → Reset Package Caches
```

---

## Homebrew

```bash
# Homebrew cache location
$(brew --cache)
# Usually: ~/Library/Caches/Homebrew/

# Check cache size
du -sh $(brew --cache)

# Clean old versions
brew cleanup

# Clean all caches
brew cleanup -s

# Force full cleanup
rm -rf $(brew --cache)/*
```

### Homebrew Logs

```bash
# Homebrew logs
~/Library/Logs/Homebrew/

# Clean
rm -rf ~/Library/Logs/Homebrew/*
```

---

## Node.js / npm / yarn

### npm

```bash
# npm cache location
~/.npm/

# Cache size
du -sh ~/.npm

# Clean cache
npm cache clean --force

# Verify cache
npm cache verify
```

### yarn

```bash
# yarn cache location
yarn cache dir
# Usually: ~/Library/Caches/Yarn/

# Cache size
du -sh $(yarn cache dir)

# Clean cache
yarn cache clean
```

### pnpm

```bash
# pnpm cache/store location
pnpm store path

# Clean cache
pnpm store prune
```

---

## Python

### pip

```bash
# pip cache location
~/Library/Caches/pip/

# Cache size
du -sh ~/Library/Caches/pip

# Clean cache
pip cache purge
```

### Conda / Miniconda

```bash
# Clean conda cache
conda clean --all

# Clean specific items only
conda clean --packages  # Unused packages
conda clean --tarballs  # Downloaded package archives
```

### pyenv

```bash
# pyenv versions location
~/.pyenv/versions/

# Check unused versions
pyenv versions

# Delete version
pyenv uninstall 3.8.0
```

---

## Docker

```bash
# Docker data location
~/Library/Containers/com.docker.docker/Data/

# Check Docker system usage
docker system df

# Clean unused data
docker system prune

# Full cleanup including volumes (use with caution!)
docker system prune -a --volumes

# Clean build cache only
docker builder prune
```

### Docker Desktop Settings

```bash
# Docker Desktop virtual disk
~/Library/Containers/com.docker.docker/Data/vms/

# Disk size limit: Docker Desktop → Settings → Resources
```

---

## JetBrains IDEs

### IntelliJ IDEA / Android Studio / PyCharm etc.

```bash
# Cache location (varies by version)
~/Library/Caches/JetBrains/

# Logs location
~/Library/Logs/JetBrains/

# Settings location
~/Library/Application Support/JetBrains/

# Clean cache
rm -rf ~/Library/Caches/JetBrains/*

# From IDE: File → Invalidate Caches / Restart
```

### Android Studio Additional Items

```bash
# Android SDK
~/Library/Android/sdk/

# AVD (Android Virtual Devices)
~/.android/avd/

# Gradle cache
~/.gradle/caches/

# Clean Gradle cache
rm -rf ~/.gradle/caches/*
```

---

## VS Code

```bash
# VS Code cache
~/Library/Application Support/Code/Cache/
~/Library/Application Support/Code/CachedData/
~/Library/Application Support/Code/CachedExtensions/

# Extensions
~/.vscode/extensions/

# Clean cache
rm -rf ~/Library/Application\ Support/Code/Cache/*
rm -rf ~/Library/Application\ Support/Code/CachedData/*
```

---

## Comprehensive Cleanup Script

```bash
#!/bin/bash
# developer_cache_cleanup.sh

echo "=== Developer Cache Cleanup ==="
echo "Date: $(date)"
echo ""

# Check space before cleanup
echo "Before cleanup:"
df -h / | tail -1

# 1. Xcode Derived Data
echo -e "\n[1/10] Cleaning Xcode Derived Data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null
echo "Done"

# 2. iOS Simulator (unavailable only)
echo -e "\n[2/10] Cleaning unavailable simulators..."
xcrun simctl delete unavailable 2>/dev/null
echo "Done"

# 3. CocoaPods cache
echo -e "\n[3/10] Cleaning CocoaPods cache..."
rm -rf ~/Library/Caches/CocoaPods/* 2>/dev/null
echo "Done"

# 4. SPM cache
echo -e "\n[4/10] Cleaning Swift Package Manager cache..."
rm -rf ~/Library/Caches/org.swift.swiftpm/* 2>/dev/null
echo "Done"

# 5. Homebrew cleanup
echo -e "\n[5/10] Cleaning Homebrew..."
brew cleanup -s 2>/dev/null
echo "Done"

# 6. npm cache
echo -e "\n[6/10] Cleaning npm cache..."
npm cache clean --force 2>/dev/null
echo "Done"

# 7. pip cache
echo -e "\n[7/10] Cleaning pip cache..."
pip cache purge 2>/dev/null
echo "Done"

# 8. Gradle cache
echo -e "\n[8/10] Cleaning Gradle cache..."
rm -rf ~/.gradle/caches/* 2>/dev/null
echo "Done"

# 9. Docker (if available)
echo -e "\n[9/10] Cleaning Docker..."
docker system prune -f 2>/dev/null || echo "Docker not available"
echo "Done"

# 10. JetBrains cache
echo -e "\n[10/10] Cleaning JetBrains cache..."
rm -rf ~/Library/Caches/JetBrains/* 2>/dev/null
echo "Done"

# Check space after cleanup
echo -e "\n=== Cleanup Complete ==="
echo "After cleanup:"
df -h / | tail -1
```

---

## Space Usage Summary

| Tool | Expected Space Recovered | Risk Level |
|-----|--------------|--------|
| Xcode Derived Data | 5-50GB | ✅ Safe |
| iOS Device Support (old) | 10-50GB | ⚠️ Re-download required |
| Simulator Runtimes (old) | 5-30GB | ⚠️ Re-download required |
| CocoaPods/SPM | 1-5GB | ✅ Safe |
| Homebrew | 1-10GB | ✅ Safe |
| npm/yarn | 1-5GB | ✅ Safe |
| Docker | 5-50GB | ⚠️ Image re-download |
| Gradle | 2-10GB | ✅ Safe |

---

## Recommended Tools

### DevCleaner for Xcode

- Open source (GPL-3.0)
- Specialized in Xcode-related caches
- Easy management with GUI

[GitHub - DevCleaner](https://github.com/vashpan/xcode-dev-cleaner)

### xcleaner

- Menu bar app
- Auto-cleanup of Derived Data
- Project connection check

---

## References

- [MacPaw - Clear Xcode Cache](https://macpaw.com/how-to/clear-xcode-cache)
- [SwiftyPlace - Clean Xcode Junk](https://www.swiftyplace.com/blog/how-to-clean-xcode-on-your-mac)
- [Dr.Buho - Delete Xcode Cache](https://www.drbuho.com/how-to/delete-xcode-cache-mac)
- [Medium - Clearing Xcode Cache](https://vikramios.medium.com/clearing-xcode-cache-a-guide-to-boosting-development-efficiency-e83fbf6c480b)
