# macOS Cleanup Reference Documentation

> Version: 1.1.0
> Last Updated: 2025-12-25

## Overview

This collection of documents provides reference materials for safely cleaning up unnecessary files such as temporary files, caches, and logs on macOS systems.

## Document Index

### Core Reference

| # | Document | Description | Primary Use |
|---|----------|-------------|-------------|
| 01 | [Temporary Files](01-temporary-files.md) | Analysis of temporary file locations and types | System understanding |
| 02 | [Cache System](02-cache-system.md) | Cache hierarchy and management methods | Cache cleanup |
| 03 | [System Logs](03-system-logs.md) | Log file locations and cleanup methods | Log management |
| 04 | [Version Differences](04-version-differences.md) | Differences between macOS versions | Compatibility checking |
| 05 | [Developer Caches](05-developer-caches.md) | Development tool cache locations | For developers |
| 06 | [Safe Cleanup Guide](06-safe-cleanup-guide.md) | Safe cleanup guidelines | Practical application |

### Developer Guide

| # | Document | Description | Primary Use |
|---|----------|-------------|-------------|
| 07 | [Developer Guide](07-developer-guide.md) | Cleanup strategies by developer type | iOS/Web/Backend developers |
| 08 | [Automation Scripts](08-automation-scripts.md) | Collection of automation scripts | Regular maintenance |
| 09 | [CI/CD & Team Guide](09-ci-cd-team-guide.md) | CI/CD and team environment management | DevOps/Team leads |

## Quick Reference

### Safe to Clean (✅)

```bash
# Can be cleaned immediately
~/Library/Caches/*                    # User caches
~/.Trash/*                            # Trash
~/Downloads/* (old files)             # Downloads
~/Library/Logs/DiagnosticReports/*    # Crash reports
```

### Requires Caution (⚠️)

```bash
# Clean after quitting apps
~/Library/Developer/Xcode/DerivedData/  # Xcode build cache
/Library/Caches/*                        # System caches (requires root)
tmutil deletelocalsnapshots [date]       # Time Machine snapshots
```

### Never Delete (❌)

```bash
# Never delete these
/System/*
/private/var/folders/* (do not manually delete)
~/Library/Keychains/*
~/Library/Application Support/*
```

## Typical Space Usage

| Item | Typical Size | Cleanup Safety |
|------|-------------|----------------|
| Trash | 0-50GB | ✅ Safe |
| Browser cache | 0.5-5GB | ✅ Safe |
| User caches | 5-30GB | ✅ Safe |
| System logs | 0.5-5GB | ⚠️ Caution |
| Xcode (developers) | 20-100GB | ⚠️ Caution |
| Time Machine snapshots | 10-100GB | ⚠️ Caution |

## Recommended Cleanup Frequency

| Task | Recommended Frequency | Expected Time |
|------|---------------------|---------------|
| Empty trash | Weekly | Immediate |
| Browser cache | Monthly | 1 minute |
| Downloads folder | Monthly | 5 minutes |
| All user caches | Quarterly | 5 minutes |
| Developer tools | Monthly | 10 minutes |
| Safe Mode boot | As needed | 10 minutes |

## Quick Start Script

```bash
#!/bin/bash
# quick_cleanup.sh - Safe basic cleanup

echo "=== macOS Quick Cleanup ==="

# 1. Trash
rm -rf ~/.Trash/*

# 2. Browser cache
rm -rf ~/Library/Caches/com.apple.Safari/WebKitCache/*
rm -rf ~/Library/Caches/Google/Chrome/Default/Cache/*

# 3. Old downloads (90+ days)
find ~/Downloads -mtime +90 -delete 2>/dev/null

# 4. Old logs (30+ days)
find ~/Library/Logs -mtime +30 -delete 2>/dev/null

echo "Cleanup complete!"
df -h / | tail -1
```

## macOS Version Support

| Version | Codename | Support Status | Notes |
|---------|----------|---------------|-------|
| 15.x | Sequoia | ✅ Full support | mediaanalysisd bug (15.1) |
| 14.x | Sonoma | ✅ Full support | Safari profile separation |
| 13.x | Ventura | ✅ Full support | System Settings UI change |
| 12.x | Monterey | ✅ Full support | System Data introduced |
| 11.x | Big Sur | ✅ Full support | Apple Silicon introduced |
| 10.15 | Catalina | ⚠️ Partial support | Volume separation started |

## Related Resources

### Apple Documentation
- [Mac Storage Management](https://support.apple.com/en-us/HT206996)
- [Time Machine Local Snapshots](https://support.apple.com/en-us/102154)
- [Safe Mode](https://support.apple.com/guide/mac-help/mchl0e7fd83d/mac)

### Third-Party Tools
- [DevCleaner for Xcode](https://github.com/vashpan/xcode-dev-cleaner) - Xcode cache management
- [OnyX](https://titanium-software.fr/en/onyx.html) - System maintenance
- [DaisyDisk](https://daisydiskapp.com/) - Disk usage visualization

### Community Resources
- [MacRumors Forums](https://forums.macrumors.com/)
- [Apple Community](https://discussions.apple.com/)

## Contributing

To contribute to this documentation:
1. Verify on latest macOS version
2. Specify safety level
3. Add after testing actual commands

## Changelog

### v1.1.0 (2025-12-25)
- Added Developer Guide documents (07-09)
- Developer-specific cleanup strategies by role (iOS, Web, Backend)
- Automation scripts with launchd integration
- CI/CD pipeline integration examples (GitHub Actions, Jenkins, Fastlane)
- Team environment management guide

### v0.1.0.0 (2025-12-25)
- Initial documentation release
- 6 reference documents created
- Covers macOS Catalina through Sequoia

---

*This documentation is for reference purposes for system cleanup. Always back up important data before performing cleanup operations.*
