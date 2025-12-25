# macOS Temporary Files Reference

> Last Updated: 2025-12-25

## Overview

macOS creates various temporary files to improve system and application performance. This document describes the main temporary file locations and their purposes.

## Primary Temporary File Locations

### 1. /tmp (→ /private/tmp)

| Property | Value |
|-----|-----|
| Path | `/tmp` (symlink to `/private/tmp`) |
| Purpose | System-wide temporary file storage |
| Permissions | Accessible to all users (sticky bit set) |
| Auto Cleanup | On reboot or periodic system tasks |

```bash
# Check current size
du -sh /private/tmp

# View contents (caution: do not delete)
ls -la /private/tmp
```

### 2. /private/var/folders

| Property | Value |
|-----|-----|
| Path | `/private/var/folders` |
| Purpose | Per-user temporary files and caches |
| Structure | Hash-based two-level directory |
| Auto Cleanup | Daily at 3:35am (deletes files not accessed for 3 days) |

#### Internal Structure

```
/private/var/folders/
├── xx/           # First hash level
│   └── xxxxxxx/  # Second hash level (per-user)
│       ├── C/    # Caches - cache files
│       ├── T/    # Temporary - temporary files
│       └── 0/    # Other temporary data
```

> **Important**: Introduced in macOS 10.5, this structure replaces the previous `/tmp` and `/Library/Caches` for enhanced security

### 3. /private/var/tmp

| Property | Value |
|-----|-----|
| Path | `/private/var/tmp` |
| Purpose | Temporary files that persist after reboot |
| Auto Cleanup | Periodic system cleanup scripts |

```bash
# Check size
du -sh /private/var/tmp
```

## User-Level Temporary Locations

### ~/Library/Caches

Stores cache data for each application

```bash
# Check total cache size
du -sh ~/Library/Caches

# Cache size by app (top 10)
du -sh ~/Library/Caches/* 2>/dev/null | sort -hr | head -10
```

#### Major Cache Directories

| Directory | Description |
|---------|------|
| `com.apple.Safari` | Safari browser cache |
| `com.spotify.client` | Spotify offline data |
| `com.google.Chrome` | Chrome browser cache |
| `com.apple.bird` | iCloud sync cache |
| `CloudKit` | iCloud metadata cache |

### ~/Library/Application Support

Application data (persistent but may contain large files)

```bash
# Check size
du -sh ~/Library/Application\ Support

# Find large items
du -sh ~/Library/Application\ Support/* 2>/dev/null | sort -hr | head -10
```

## Temporary File Types

### 1. System Temporary Files

| Type | Location | Description |
|-----|------|------|
| Sleep Image | `/private/var/vm/sleepimage` | Memory dump for sleep mode |
| Swap Files | `/private/var/vm/swapfile*` | Virtual memory swap |
| Kernel Caches | `/System/Library/Caches/` | Kernel cache (SIP protected) |

### 2. Application Temporary Files

| Type | Location | Description |
|-----|------|------|
| Document Autosave | `~/Library/Autosave Information/` | For unsaved document recovery |
| Saved States | `~/Library/Saved Application State/` | For app state restoration |
| Containers | `~/Library/Containers/` | Sandboxed app data |

### 3. Browser Temporary Files

| Browser | Cache Location |
|---------|----------|
| Safari | `~/Library/Caches/com.apple.Safari/` |
| Chrome | `~/Library/Caches/Google/Chrome/` |
| Firefox | `~/Library/Caches/Firefox/` |
| Edge | `~/Library/Caches/Microsoft Edge/` |

## Automatic Cleanup Mechanisms

### 1. dirhelper Daemon

```bash
# Responsible process
/usr/libexec/dirhelper

# Execution schedule: Daily at 3:35am
# Target: Files not accessed for 3+ days in /private/var/folders
```

### 2. Periodic System Scripts

```bash
# Daily tasks
/etc/periodic/daily/

# Weekly tasks
/etc/periodic/weekly/

# Monthly tasks
/etc/periodic/monthly/

# Manual execution
sudo periodic daily weekly monthly
```

### 3. ASL (Apple System Log) Cleanup

```bash
# System log cleanup (logs older than 7 days)
# Automatically cleans /private/var/log/asl/
```

## Safe Cleanup Commands

### Recommended Cleanup Methods

```bash
# 1. Safest: Reboot
# Most temporary files are automatically cleaned on reboot

# 2. Safe Mode boot (more thorough cleanup)
# Hold Shift key during startup

# 3. Manually run periodic scripts
sudo periodic daily weekly monthly
```

### Cautions

> **Warning**: Do not manually delete contents of `/private/var/folders` or `/tmp`.
>
> - May damage running applications
> - Can cause system instability
> - Reboot is the safest cleanup method

## Disk Space Analysis Commands

```bash
# Overall disk usage
df -h /

# Size of major temporary directories
echo "=== Temporary Directories Size ==="
du -sh /private/tmp 2>/dev/null
du -sh /private/var/tmp 2>/dev/null
du -sh /private/var/folders 2>/dev/null
du -sh ~/Library/Caches 2>/dev/null

# Find large files (100MB+)
sudo find /private/var -size +100M -exec ls -lh {} \; 2>/dev/null
```

## References

- [OSXDaily - Delete Temporary Items](https://osxdaily.com/2016/01/13/delete-temporary-items-private-var-folders-mac-os-x/)
- [iBoysoft - private/var Folder](https://iboysoft.com/wiki/private-var-folder-mac.html)
- [Magnusviri - What is /var/folders](https://magnusviri.com/what-is-var-folders)
- [Apple Community Discussions](https://discussions.apple.com/thread/251685409)
