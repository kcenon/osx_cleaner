# macOS Version-Specific Differences

> Last Updated: 2025-12-25

## Overview

Temporary files, cache management, and storage optimization methods differ across macOS versions. This document explains the major differences between versions and precautions when cleaning up version-specific data.

## Version Timeline

```
macOS 15 Sequoia    (2024)  ─────────────────────────────────┐
macOS 14 Sonoma     (2023)  ────────────────────────────┐    │
macOS 13 Ventura    (2022)  ───────────────────────┐    │    │
macOS 12 Monterey   (2021)  ──────────────────┐    │    │    │
macOS 11 Big Sur    (2020)  ─────────────┐    │    │    │    │
macOS 10.15 Catalina (2019) ────────┐    │    │    │    │    │
                                    │    │    │    │    │    │
                                    ▼    ▼    ▼    �▼    ▼    ▼
                              [Storage Management Evolution]
```

## Key Differences by Version

### macOS 15 Sequoia (2024)

#### New Features

| Feature | Description |
|---------|-------------|
| Apple Intelligence | New cache system for AI features |
| iPhone Mirroring | Cache for connected iPhone data |
| Enhanced Siri | Expanded Siri data cache |

#### Known Issues

> **Warning**: A `mediaanalysisd` cache bug occurred in Sequoia 15.1.
>
> - Generates 64MB cache files every hour
> - Continues to grow without deletion
> - Solution: Upgrade to 15.2

```bash
# Problem cache location
~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches

# Manual cleanup (only on 15.2+)
rm -rf ~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches/*
```

#### Storage Settings Access

```
System Settings → General → Storage
```

---

### macOS 14 Sonoma (2023)

#### New Features

| Feature | Description |
|---------|-------------|
| Desktop Widgets | Increased widget cache |
| Game Mode | Game mode-related cache |
| Safari Profiles | Separate cache per profile |

#### Safari Changes

```bash
# Safari profile-specific cache location
~/Library/Containers/com.apple.Safari/Data/Library/Caches/
└── [Profile_UUID]/

# Developer menu setting change
# "Show Developer Menu" → "Show Features for Web Developers"
```

#### Cache Management

```bash
# Widget cache
~/Library/Caches/com.apple.WidgetKit/

# Game mode-related
~/Library/Caches/com.apple.GameCenter/
```

---

### macOS 13 Ventura (2022)

#### Major Changes

| Feature | Description |
|---------|-------------|
| System Settings | System Preferences → System Settings |
| Stage Manager | New window management system |
| System Data Category | Storage classification system changed |

#### Storage Settings Access Change

```
# Before Ventura
Apple Menu → About This Mac → Storage

# Ventura and later
System Settings → General → Storage
```

#### Stage Manager Cache

```bash
# Stage Manager-related data
~/Library/Application Support/com.apple.WindowServer/

# Dock cache (affected by Stage Manager)
~/Library/Caches/com.apple.dock/
```

---

### macOS 12 Monterey (2021)

#### Key Features

| Feature | Description |
|---------|-------------|
| Universal Control | Cache sharing between devices |
| Focus Modes | Focus mode settings data |
| Shortcuts | Shortcuts app data |

#### System Data Introduction

Starting with Monterey, the "Other" category was changed to "System Data".

```
System Data composition:
├── Time Machine local snapshots
├── System cache
├── Temporary files
├── VM and swap files
└── Other system data
```

#### Cleanup Tools

```bash
# Shortcuts cache
~/Library/Caches/com.apple.shortcuts/

# Focus mode data
~/Library/Preferences/com.apple.ncprefs.plist
```

---

### macOS 11 Big Sur (2020)

#### Architecture Changes

| Feature | Description |
|---------|-------------|
| Apple Silicon | M1 chip introduction |
| Signed System Volume | System volume signing |
| APFS Snapshots | More aggressive snapshot usage |

#### System Volume Separation

```
Big Sur and later volume structure:
├── Macintosh HD (System Volume, read-only)
└── Macintosh HD - Data (Data Volume, read/write)
```

> **Important**: System volume cannot be modified (SIP + Sealed System Volume)

#### ARM vs Intel Cache Differences

```bash
# Rosetta 2 cache (for Intel apps)
/Library/Apple/usr/share/rosetta/

# Native ARM cache
~/Library/Caches/*/
```

---

### macOS 10.15 Catalina (2019)

#### Major Changes

| Feature | Description |
|---------|-------------|
| Read-only system volume | Enhanced system security |
| Zsh default shell | Changed from Bash to Zsh |
| 32-bit app support ended | Legacy app removal |

#### Volume Separation Begins

```
Catalina volume structure:
├── Macintosh HD (System)
└── Macintosh HD - Data
```

#### Legacy App Cleanup

```bash
# Identify 32-bit apps
mdfind "kMDItemExecutableArchitectures == 'i386' && kMDItemContentType == 'com.apple.application-bundle'"

# Clean up related cache and support files
~/Library/Application Support/[32bit_app]/
~/Library/Caches/[32bit_app]/
```

---

## Storage Categories Evolution

### Storage Category Changes

| Version | Category Composition |
|---------|---------------------|
| Before Catalina | Apps, Documents, Other |
| Monterey+ | Apps, Documents, **System Data**, macOS |

### Typical System Data Size

| Version | Typical Size Range |
|---------|-------------------|
| Sequoia/Sonoma/Ventura | 12-20GB |
| Monterey | 15-25GB |
| Big Sur | 15-30GB |

### When System Data Exceeds Normal

```bash
# Analyze System Data components
# 1. Time Machine snapshots
tmutil listlocalsnapshots /

# 2. VM files
ls -lh /private/var/vm/

# 3. Check cache
sudo du -sh /Library/Caches
du -sh ~/Library/Caches
```

## Version-Specific Cleanup Commands

### Sequoia/Sonoma (15.x/14.x)

```bash
#!/bin/bash
# cleanup_modern.sh

# Clean Safari cache (with profile support)
rm -rf ~/Library/Containers/com.apple.Safari/Data/Library/Caches/*

# Widget cache
rm -rf ~/Library/Caches/com.apple.WidgetKit/*

# Media Analysis cache (15.2+ only)
rm -rf ~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches/*
```

### Ventura/Monterey (13.x/12.x)

```bash
#!/bin/bash
# cleanup_recent.sh

# Clean general cache
rm -rf ~/Library/Caches/*

# Clean logs (30+ days old)
find ~/Library/Logs -mtime +30 -delete

# Shortcuts cache
rm -rf ~/Library/Caches/com.apple.shortcuts/*
```

### Big Sur/Catalina (11.x/10.15)

```bash
#!/bin/bash
# cleanup_legacy.sh

# General cache
rm -rf ~/Library/Caches/*

# Clean Rosetta cache (Big Sur+)
# Warning: Apps may need to be retranslated
sudo rm -rf /Library/Apple/usr/share/rosetta/*
```

## Time Machine Local Snapshots

### Snapshot Management by Version

All recent versions use the same method:

```bash
# List snapshots
tmutil listlocalsnapshots /

# Delete snapshot
sudo tmutil deletelocalsnapshots [date]

# Disable/re-enable all local snapshots
tmutil thinlocalsnapshots / 9999999999999

# Temporarily disable Time Machine (automatic snapshot deletion)
# System Settings → Time Machine → Turn Off → Wait → Turn On
```

### Snapshot Space Management Policy

| Disk Usage | Action |
|-----------|--------|
| < 80% | Keep snapshots normally |
| 80-90% | Start deleting with low priority |
| > 90% | Rapid deletion with high priority |

## APFS Volume Differences

### APFS Features (High Sierra and later)

| Feature | Description |
|---------|-------------|
| Space Sharing | Space sharing between volumes in container |
| Snapshots | Efficient point-in-time copies |
| Clones | Copy-on-Write file duplication |

### Space Calculation Differences

```bash
# Actual used space vs displayed space may differ
diskutil apfs list

# Container information
diskutil apfs listContainers

# Check purgeable space
diskutil info / | grep "Purgeable"
```

## Safe Mode Cleanup by Version

All versions perform additional cleanup in Safe Mode:

```
Safe Mode cleanup items:
├── Rebuild font cache
├── Rebuild kernel cache
├── Clean system cache
└── Verify Startup Items
```

### Entering Safe Mode

| Mac Type | Method |
|----------|--------|
| Apple Silicon | Shut down → Press and hold power button → Options → Shift + "Macintosh HD" |
| Intel | Restart → Press Shift key |

## Compatibility Matrix

### Cleanup Tool Compatibility

| Tool/Feature | Catalina | Big Sur | Monterey | Ventura | Sonoma | Sequoia |
|--------------|:--------:|:-------:|:--------:|:-------:|:------:|:-------:|
| `tmutil` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Storage Management | ✅ | ✅ | ✅ | ✅* | ✅* | ✅* |
| `diskutil apfs` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Safe Mode Cleanup | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

\* UI path changed

## Migration Considerations

### Pre-Upgrade Cleanup

```bash
#!/bin/bash
# pre_upgrade_cleanup.sh

echo "=== Pre-Upgrade Cleanup ==="

# 1. Clean user cache
rm -rf ~/Library/Caches/*

# 2. Clean old logs
find ~/Library/Logs -mtime +30 -delete

# 3. Clean Time Machine snapshots (optional)
# tmutil thinlocalsnapshots / 10000000000

# 4. Empty Trash
rm -rf ~/.Trash/*

# 5. Clean Downloads folder (old files)
find ~/Downloads -mtime +90 -delete

echo "=== Cleanup Complete ==="
echo "Recommendation: Ensure at least 20GB free space before upgrade"
```

## References

- [Apple Support - Time Machine Snapshots](https://support.apple.com/en-us/102154)
- [OSXHub - macOS Storage Cleanup Guide 2025](https://osxhub.com/macos-storage-cleanup-guide-2025/)
- [Dr.Buho - Clear System Storage Mac](https://www.drbuho.com/how-to/clear-system-storage-mac)
- [MacPaw - Optimize macOS Sequoia](https://macpaw.com/how-to/optimize-macos-sequoia)
- [Apple Community - Sequoia System Data](https://discussions.apple.com/thread/255806791)
