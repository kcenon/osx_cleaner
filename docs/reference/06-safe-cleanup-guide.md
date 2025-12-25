# macOS Safe Cleanup Guidelines

> Last Updated: 2025-12-25

## Overview

This guide explains how to safely free up disk space on macOS. The goal is to clean effectively while maintaining system stability.

## Safety Classification

### Risk Levels

| Level | Description | Examples |
|-----|------|------|
| ✅ **Safe** | Free to delete, automatically regenerated | Browser cache, app cache |
| ⚠️ **Caution** | Can delete but has impact | iOS Device Support, logs |
| ❌ **Dangerous** | Do not delete, can damage system | System files, SIP-protected areas |

---

## Golden Rules

### 1. Reboot Over Manual Deletion

```
Reboot > Manual Deletion
```

Most temporary files are automatically cleaned up during reboot.

### 2. Don't Touch System Folders

```
Never modify:
├── /System/
├── /usr/  (except /usr/local)
├── /bin/
├── /sbin/
└── /private/var/ (most)
```

### 3. Be Careful with com.apple.*

Items starting with `com.apple.*` may be system components.

### 4. Backup Before Deletion

Time Machine backup is recommended before important cleanup.

---

## Safe Cleanup Checklist

### Before Cleanup

- [ ] Important work saved
- [ ] Related apps closed
- [ ] Cloud sync completed
- [ ] (Optional) Time Machine backup

### After Cleanup

- [ ] System boots normally
- [ ] Main apps run properly
- [ ] Important files accessible

---

## Safe Cleanup Targets

### Level 1: Completely Safe (✅)

Can delete immediately, no side effects

```bash
#!/bin/bash
# safe_cleanup_level1.sh

# 1. Empty Trash
rm -rf ~/.Trash/*

# 2. Old files in Downloads (90+ days)
find ~/Downloads -mtime +90 -delete 2>/dev/null

# 3. Browser cache
rm -rf ~/Library/Caches/com.apple.Safari/WebKitCache/* 2>/dev/null
rm -rf ~/Library/Caches/Google/Chrome/Default/Cache/* 2>/dev/null
rm -rf ~/Library/Caches/Firefox/Profiles/*/cache2/* 2>/dev/null

# 4. Screenshots (30+ days)
find ~/Desktop -name "Screenshot*.png" -mtime +30 -delete 2>/dev/null

echo "Level 1 cleanup complete"
```

#### Target List

| Target | Location | Expected Space |
|-----|------|----------|
| Trash | `~/.Trash/` | Varies |
| Browser cache | `~/Library/Caches/[browser]/` | 0.5-5GB |
| Downloads (old) | `~/Downloads/` | Varies |
| Screenshots (old) | `~/Desktop/Screenshot*` | 0.1-1GB |
| Mail downloads | `~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads/` | 0.1-1GB |

---

### Level 2: Safe (⚠️ Slight Caution)

Can delete, requires some rebuild time

```bash
#!/bin/bash
# safe_cleanup_level2.sh

# Confirm related apps are closed
echo "Make sure apps are closed..."
read -p "Press Enter to continue..."

# 1. All user cache
rm -rf ~/Library/Caches/* 2>/dev/null

# 2. Old logs (30+ days)
find ~/Library/Logs -mtime +30 -delete 2>/dev/null

# 3. Old crash reports
find ~/Library/Logs/DiagnosticReports -mtime +30 -delete 2>/dev/null

# 4. Saved Application State
rm -rf ~/Library/Saved\ Application\ State/* 2>/dev/null

echo "Level 2 cleanup complete"
echo "Note: First app launch may be slightly slower"
```

#### Target List

| Target | Location | Expected Space | Impact |
|-----|------|----------|------|
| User cache | `~/Library/Caches/` | 5-30GB | Slower initial app loading |
| Old logs | `~/Library/Logs/` | 0.1-1GB | Cannot track past issues |
| Saved State | `~/Library/Saved Application State/` | 0.1-0.5GB | App state not restored |
| Font Cache | `~/Library/Caches/com.apple.FontRegistry/` | 0.01-0.1GB | Font reloading |

---

### Level 3: Caution Required (⚠️)

Can delete but may cause time/data loss

```bash
#!/bin/bash
# careful_cleanup_level3.sh

echo "=== Warning: This cleanup may require data re-download ==="
read -p "Type 'yes' to continue: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled"
    exit 1
fi

# 1. Xcode Derived Data
rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null

# 2. iOS Device Support (old versions)
# Manual deletion recommended after checking current version
echo "Clean iOS Device Support manually"
echo "Location: ~/Library/Developer/Xcode/iOS DeviceSupport/"

# 3. Delete unavailable simulators
xcrun simctl delete unavailable 2>/dev/null

# 4. CocoaPods cache
rm -rf ~/Library/Caches/CocoaPods/* 2>/dev/null

# 5. Homebrew old versions
brew cleanup -s 2>/dev/null

echo "Level 3 cleanup complete"
```

#### Target List

| Target | Location | Expected Space | Impact |
|-----|------|----------|------|
| Xcode Derived Data | `~/Library/Developer/Xcode/DerivedData/` | 5-50GB | Project rebuild required |
| iOS Device Support | `~/Library/Developer/Xcode/iOS DeviceSupport/` | 10-50GB | Re-download on device connection |
| Simulator Runtimes | System location | 5-30GB | Runtime re-download |
| Docker Images | Docker managed | 5-50GB | Image re-download |

---

### Level 4: System Level (❌ Not Recommended)

Requires root privileges, risk of system instability

> **Warning**: This level of cleanup is generally not recommended.

```bash
#!/bin/bash
# system_cleanup_level4.sh (NOT RECOMMENDED)

echo "=== Warning: System level cleanup ==="
echo "This operation may make the system unstable"
echo "We recommend 'reboot' or 'Safe Mode' instead"
read -p "Type 'I UNDERSTAND' to continue anyway: " confirm

if [ "$confirm" != "I UNDERSTAND" ]; then
    echo "Cancelled"
    exit 1
fi

# System cache (caution!)
# sudo rm -rf /Library/Caches/*  # Not recommended

# Instead run periodic scripts
sudo periodic daily weekly monthly

# Safe Mode boot is a safer alternative
```

---

## Recommended Approach

### Step-by-Step Approach

```
Step 1: Reboot
    ↓
Step 2: Level 1 cleanup (completely safe)
    ↓
Step 3: Check space
    ↓ (if insufficient)
Step 4: Level 2 cleanup (safe)
    ↓
Step 5: Check space
    ↓ (if insufficient)
Step 6: Boot in Safe Mode
    ↓
Step 7: Level 3 cleanup (caution)
```

### Monthly Maintenance Routine

```bash
#!/bin/bash
# monthly_maintenance.sh

echo "=== Monthly macOS Maintenance ==="
echo "Date: $(date)"

# 1. Empty Trash
osascript -e 'tell app "Finder" to empty trash'

# 2. Clean Downloads folder (90+ days)
find ~/Downloads -mtime +90 -delete 2>/dev/null

# 3. Clean browser cache
rm -rf ~/Library/Caches/com.apple.Safari/WebKitCache/* 2>/dev/null

# 4. Clean old logs (60+ days)
find ~/Library/Logs -mtime +60 -delete 2>/dev/null

# 5. Developer: Homebrew cleanup
command -v brew &>/dev/null && brew cleanup -s

# 6. Disk usage report
echo ""
echo "=== Current Disk Usage ==="
df -h / | tail -1

echo ""
echo "=== Largest User Directories ==="
du -sh ~/* 2>/dev/null | sort -hr | head -10

echo ""
echo "Maintenance complete!"
```

---

## Time Machine Snapshots

### Safe Snapshot Management

```bash
# Check snapshots
tmutil listlocalsnapshots /

# Delete specific snapshot
sudo tmutil deletelocalsnapshots 2025-01-15-120000

# Clean all snapshots (safest method)
# System Settings → Time Machine → Turn off → Wait 5 min → Turn back on
```

### Automatic Cleanup Policy

macOS automatically manages snapshots based on disk usage:
- 80%+: Start deleting with low priority
- 90%+: Fast deletion with high priority

---

## Safe Mode Cleanup

The safest and most effective system cleanup method

### How to Enter

**Apple Silicon (M1/M2/M3):**
1. Shut down Mac
2. Press and hold power button (until startup options appear)
3. Select startup disk and click "Continue in Safe Mode" while holding Shift

**Intel Mac:**
1. Start/restart Mac
2. Immediately press Shift key
3. Hold until login window appears

### Items Cleaned in Safe Mode

- System cache
- Font cache
- Kernel cache
- Some temporary files

### Recommended Usage Times

- When system is slow
- When apps crash frequently
- When disk space decreases rapidly

---

## What NOT to Delete

### Absolutely Do Not Delete

```
❌ Do not delete:
├── /System/
├── /usr/bin/, /usr/sbin/
├── /private/var/db/
├── /private/var/folders/  (no manual deletion)
├── ~/Library/Preferences/  (settings loss)
├── ~/Library/Application Support/  (app data loss)
├── ~/Library/Keychains/  (password loss)
├── ~/Library/Mail/  (email loss)
└── ~/Library/Messages/  (message loss)
```

### Handle with Caution

```
⚠️ Caution required:
├── ~/Library/Containers/  (sandboxed app data)
├── ~/Library/Group Containers/  (shared app data)
├── /Library/Caches/  (system cache)
└── /private/var/log/  (for problem diagnosis)
```

---

## Recovery Options

### If Deleted by Mistake

1. **Check Trash**: Restore recently deleted items
2. **Time Machine**: Restore previous version
3. **Reinstall app**: Regenerate app data
4. **Recovery Mode**: For serious problems

### Entering Recovery Mode

**Apple Silicon:**
1. Shut down Mac
2. Press and hold power button
3. Select "Options"

**Intel:**
1. Restart Mac
2. Press Command + R

---

## Monitoring Tools

### Built-in Tools

```bash
# Disk usage
df -h /

# Usage by folder
du -sh ~/*

# System information
system_profiler SPStorageDataType
```

### Storage Management

```
System Settings → General → Storage → Recommendations
```

Options provided in recommendations:
- Store in iCloud
- Optimize storage
- Empty Trash automatically
- Reduce clutter

---

## Emergency Cleanup

When disk is almost full (< 5GB)

```bash
#!/bin/bash
# emergency_cleanup.sh

echo "=== Emergency Disk Cleanup ==="

# 1. Empty Trash immediately
rm -rf ~/.Trash/* 2>/dev/null

# 2. Large files in Downloads
find ~/Downloads -size +100M -delete 2>/dev/null

# 3. Browser cache
rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null
rm -rf ~/Library/Caches/Google/Chrome/* 2>/dev/null

# 4. Xcode (for developers)
rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null

# 5. Check current space
echo ""
echo "Current free space:"
df -h / | awk 'NR==2 {print $4}'
```

---

## Summary

### Cleanup Priority

1. **Reboot** - Safest and most effective
2. **Empty Trash** - Immediate space recovery
3. **Browser cache** - Safe and effective
4. **Downloads folder** - Clean old files
5. **User cache** - Clean after closing apps
6. **Developer cache** - Xcode, npm, etc.

### What to Avoid

1. Manual deletion of `/private/var/folders/`
2. Modifying system folders
3. Deleting cache of running apps
4. Indiscriminate deletion of `com.apple.*`

---

## References

- [Apple Support - Mac Storage](https://support.apple.com/en-us/HT206996)
- [Apple Support - Safe Mode](https://support.apple.com/guide/mac-help/mchl0e7fd83d/mac)
- [OSXDaily - Safe Cleanup](https://osxdaily.com/2016/01/13/delete-temporary-items-private-var-folders-mac-os-x/)
- [MacPaw - Cache Cleanup Safety](https://macpaw.com/how-to/clear-cache-on-mac)
