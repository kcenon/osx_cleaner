# Safety Guide

> Understanding OSX Cleaner's safety classification system and how it protects your data.

---

## Table of Contents

- [Safety Philosophy](#safety-philosophy)
- [4-Level Safety Classification](#4-level-safety-classification)
- [Cleanup Levels Explained](#cleanup-levels-explained)
- [Protected Paths](#protected-paths)
- [What to Expect](#what-to-expect)
- [Recovery Options](#recovery-options)
- [FAQ](#faq)

---

## Safety Philosophy

OSX Cleaner is built with a **safety-first** approach. The core principles are:

1. **Never delete what you can't recover** - System files and user documents are always protected
2. **Classify before delete** - Every path is classified before any action is taken
3. **User confirmation for risky operations** - Warning-level items require explicit approval
4. **Dry-run by default** - Encourage previewing before actual cleanup

```
┌─────────────────────────────────────────────────────────────────┐
│                    Safety Decision Flow                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Path Input → Classify → Check Level → Confirm → Delete          │
│      ↓            ↓           ↓           ↓         ↓            │
│   Validate    4-Level     Match with   Require    Execute        │
│   Existence   System      Cleanup      Approval   Safely         │
│                           Level        if Warning                 │
│                                                                   │
│  At any step: DANGER paths → IMMEDIATE BLOCK (never delete)      │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4-Level Safety Classification

OSX Cleaner uses a 4-level safety classification system:

### Level 1: Safe (✅)

**Indicator:** ✅ Green checkmark

| Aspect | Description |
|--------|-------------|
| **Risk** | None |
| **Regeneration** | Automatic - System recreates these files as needed |
| **User Impact** | None |
| **Examples** | Browser cache, Trash, temporary files |

**What happens when deleted:**
- Files are automatically recreated when needed
- No data loss
- No performance impact (may even improve)

### Level 2: Caution (⚠️)

**Indicator:** ⚠️ Warning sign

| Aspect | Description |
|--------|-------------|
| **Risk** | Low |
| **Regeneration** | Automatic but requires rebuild time |
| **User Impact** | Temporary slowdown during rebuild |
| **Examples** | Application caches, old logs, saved application state |

**What happens when deleted:**
- Applications may take longer to start initially
- Caches will be rebuilt on next use
- Login credentials remain safe

### Level 3: Warning (⚠️⚠️)

**Indicator:** ⚠️⚠️ Double warning

| Aspect | Description |
|--------|-------------|
| **Risk** | Moderate |
| **Regeneration** | Manual re-download required |
| **User Impact** | Time and bandwidth to restore |
| **Examples** | iOS Device Support, Docker images, large SDK downloads |

**What happens when deleted:**
- Must re-download from internet (can be 10-50GB)
- Development workflow interrupted until restored
- No permanent data loss

### Level 4: Danger (❌)

**Indicator:** ❌ Red X

| Aspect | Description |
|--------|-------------|
| **Risk** | Critical |
| **Regeneration** | Impossible or requires backup |
| **User Impact** | System damage or data loss |
| **Examples** | System files, keychains, user documents |

**What happens when deleted:**
- **OSX Cleaner will NEVER delete these paths**
- Even with `--force` flag, these are blocked
- Attempting to delete shows an error message

---

## Cleanup Levels Explained

Each cleanup level determines which safety levels are included:

### Level 1: Light

```bash
osxcleaner clean --level light
```

| Safety Level | Included | Examples |
|--------------|----------|----------|
| ✅ Safe | Yes | Browser cache, Trash |
| ⚠️ Caution | No | - |
| ⚠️⚠️ Warning | No | - |
| ❌ Danger | Never | - |

**Best for:** Regular maintenance, low-risk cleanup

### Level 2: Normal

```bash
osxcleaner clean --level normal
```

| Safety Level | Included | Examples |
|--------------|----------|----------|
| ✅ Safe | Yes | Browser cache, Trash |
| ⚠️ Caution | Yes | User caches, old logs |
| ⚠️⚠️ Warning | No | - |
| ❌ Danger | Never | - |

**Best for:** Weekly/monthly maintenance

### Level 3: Deep

```bash
osxcleaner clean --level deep
```

| Safety Level | Included | Examples |
|--------------|----------|----------|
| ✅ Safe | Yes | Browser cache, Trash |
| ⚠️ Caution | Yes | User caches, old logs |
| ⚠️⚠️ Warning | Yes | Developer caches, Docker |
| ❌ Danger | Never | - |

**Best for:** Pre-release cleanup, disk space emergency

### Level 4: System

```bash
sudo osxcleaner clean --level system
```

| Safety Level | Included | Examples |
|--------------|----------|----------|
| ✅ Safe | Yes | All safe items |
| ⚠️ Caution | Yes | All caution items |
| ⚠️⚠️ Warning | Yes | All warning items |
| ❌ Danger | **Never** | Still protected |

**Best for:** Expert users only, system maintenance

> **Note:** Even at System level, Danger paths are NEVER deleted.

---

## Protected Paths

These paths are classified as **Danger** and will never be deleted:

### System Directories

| Path | Reason |
|------|--------|
| `/System` | macOS core system files |
| `/usr/bin` | Essential system binaries |
| `/usr/sbin` | System administration binaries |
| `/usr/lib` | System libraries |
| `/usr/libexec` | System executables |
| `/bin` | Essential binaries |
| `/sbin` | System binaries |
| `/private/var/db` | System databases |
| `/Library/Extensions` | Kernel extensions |
| `/Library/Frameworks` | System frameworks |

### User Critical Data

| Path | Reason |
|------|--------|
| `~/Library/Keychains` | Passwords and certificates |
| `~/Library/Application Support` | App data and settings |
| `~/Library/Mail` | Email database |
| `~/Library/Messages` | iMessage history |
| `~/Library/Preferences` | App preferences |
| `~/Library/Accounts` | Account credentials |
| `~/Library/Calendars` | Calendar data |
| `~/Library/Contacts` | Contact database |

### User Documents

| Path | Reason |
|------|--------|
| `~/Documents` | User documents |
| `~/Desktop` | Desktop files |
| `~/Pictures` | Photos |
| `~/Movies` | Videos |
| `~/Music` | Music library |
| `~/Downloads` | Downloaded files |

### Warning Paths (Require Confirmation)

These paths are Warning level and require confirmation before deletion:

| Path | Reason |
|------|--------|
| `~/Library/Developer/Xcode/iOS DeviceSupport` | Large SDK files (10-50GB) |
| `~/Library/Developer/Xcode/watchOS DeviceSupport` | Watch SDK files |
| `~/Library/Containers` | Sandboxed app data |
| `~/.docker` | Docker configuration |
| `/Library/Caches` | System-wide caches |

---

## What to Expect

### After Light Cleanup

| Change | Duration |
|--------|----------|
| Browser loads slightly slower on first visit | 1-5 seconds per site |
| Trash is emptied | Permanent |
| No other noticeable changes | - |

### After Normal Cleanup

| Change | Duration |
|--------|----------|
| Applications may start slower on first launch | 5-30 seconds |
| Some apps may need to re-login | One-time |
| Old crash reports deleted | Permanent |

### After Deep Cleanup

| Change | Duration |
|--------|----------|
| Xcode needs to rebuild indexes | 5-30 minutes |
| iOS Simulators may need re-download | 1-10GB download |
| Docker images need to be pulled again | Depends on images |
| npm/pip packages need reinstall | project-dependent |

### After System Cleanup

| Change | Duration |
|--------|----------|
| All the above | Same |
| System caches rebuilt on next boot | 1-5 minutes |
| Some system apps may reset preferences | One-time |

---

## Recovery Options

### Before Cleanup

1. **Always use `--dry-run` first**
   ```bash
   osxcleaner clean --level deep --dry-run
   ```

2. **Create a Time Machine backup**
   ```bash
   tmutil startbackup
   ```

3. **Take note of disk usage**
   ```bash
   osxcleaner analyze > pre-cleanup-report.txt
   ```

### After Cleanup

If something went wrong:

#### Recover from Time Machine

```bash
# Open Time Machine
open /System/Applications/Time\ Machine.app

# Or use tmutil
tmutil restore /path/to/backup/file /path/to/destination
```

#### Regenerate Caches

```bash
# Clear and regenerate system caches
sudo rm -rf /Library/Caches/*
sudo reboot
```

#### Reinstall Developer Tools

```bash
# Xcode
xcode-select --install

# iOS Simulators
xcrun simctl list devices

# Docker images
docker pull your-image-name
```

---

## FAQ

### Q: Can OSX Cleaner brick my Mac?

**A: No.** OSX Cleaner has multiple layers of protection:
- System paths are hardcoded as DANGER level
- Even with `--force`, critical paths are blocked
- All deletions are logged for audit

### Q: What if I delete something important by accident?

**A:**
1. OSX Cleaner won't delete Danger paths
2. Warning paths require confirmation
3. Use Time Machine for recovery
4. Most cleaned items regenerate automatically

### Q: Should I run Level 4 (System) cleanup?

**A:** Only if you:
- Understand what system caches do
- Have a recent backup
- Are comfortable with sudo
- Know how to recover if needed

### Q: How often should I clean?

**Recommended schedule:**

| Level | Frequency | Best Time |
|-------|-----------|-----------|
| Light | Weekly | Any time |
| Normal | Monthly | Weekend morning |
| Deep | Quarterly | Before major updates |
| System | Rarely | After major issues |

### Q: Will cleaning break my apps?

**A:**
- Safe level: No impact
- Caution level: Apps may need to rebuild caches
- Warning level: May need to re-download large files
- No permanent damage at any level

### Q: Is my data backed up before deletion?

**A:** OSX Cleaner does not create backups. Please use Time Machine or another backup solution before running cleanup, especially at Deep or System levels.

### Q: Can I exclude specific paths?

**A:** Yes, use the configuration file:

```toml
# ~/.config/osxcleaner/config.toml
[paths]
exclude = [
    "~/Library/Caches/MyImportantApp",
    "~/Library/Developer/Xcode/DerivedData/MyProject-*"
]
```

### Q: What gets logged?

All operations are logged to `~/Library/Logs/osxcleaner/`:
- `cleanup.log` - Deletion history
- `analyze.log` - Scan results
- `error.log` - Any errors

---

## See Also

- [Installation Guide](INSTALLATION.md)
- [Usage Guide](USAGE.md)
- [Contributing Guide](CONTRIBUTING.md)

---

*Last updated: 2025-12-26*
