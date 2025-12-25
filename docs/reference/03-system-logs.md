# macOS System Logs and Reports

> Last Updated: 2025-12-25

## Overview

macOS maintains an extensive logging system for system stability analysis, troubleshooting, security auditing, and diagnostics. These log files can occupy significant disk space over time.

## Log File Hierarchy

```
┌────────────────────────────────────────────────────────┐
│                    System Logs                          │
│              /private/var/log/                          │
│              (Root Required)                            │
└────────────────────────┬───────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
┌────────┴────────┐             ┌───────┴────────┐
│   User Logs     │             │  Crash Reports │
│ ~/Library/Logs  │             │ ~/Library/Logs │
│                 │             │ /DiagnosticRep │
└─────────────────┘             └────────────────┘
```

## System Logs (/private/var/log)

### Location and Characteristics

| Property | Value |
|-----|-----|
| Path | `/private/var/log` (symlink: `/var/log`) |
| Permissions | root required |
| Auto-cleanup | Managed by newsyslog, aslmanager |
| Typical Size | 0.5-5GB |

### Major System Log Files

| File/Directory | Description | Safe to Clean |
|--------------|------|------------|
| `system.log` | Main system events | ⚠️ Recommended to keep for diagnostics |
| `wifi.log` | Wi-Fi connection logs | ✅ Safe |
| `install.log` | Installation history | ⚠️ Keep for troubleshooting |
| `asl/` | Apple System Log archives | ✅ Old ones only |
| `DiagnosticMessages/` | Diagnostic messages | ✅ Safe |
| `powermanagement/` | Power management logs | ✅ Safe |
| `CoreDuet/` | Siri/Search related | ✅ Safe |

### Checking Log Size

```bash
# Total system log size
sudo du -sh /private/var/log

# Individual log sizes
sudo du -sh /private/var/log/* | sort -hr

# ASL archive size
sudo du -sh /private/var/log/asl
```

## User Logs (~/Library/Logs)

### Location and Characteristics

| Property | Value |
|-----|-----|
| Path | `~/Library/Logs` |
| Permissions | User accessible |
| Auto-cleanup | Varies by app |
| Typical Size | 0.1-2GB |

### Major User Logs

| Directory | Description | Safe to Delete |
|---------|------|------------|
| `DiagnosticReports/` | Crash reports | ✅ Safe |
| `CoreSimulator/` | iOS Simulator logs | ✅ Safe |
| `JetBrains/` | IntelliJ, PyCharm, etc. | ✅ Safe |
| `Homebrew/` | Homebrew logs | ✅ Safe |
| `com.apple.Commerce/` | App Store logs | ✅ Safe |

### Size Checking and Analysis

```bash
# Total user logs size
du -sh ~/Library/Logs

# Per-app log sizes
du -sh ~/Library/Logs/* 2>/dev/null | sort -hr | head -10

# Crash report size
du -sh ~/Library/Logs/DiagnosticReports
```

## Crash Reports

### Locations

| Type | Path |
|-----|------|
| User crash reports | `~/Library/Logs/DiagnosticReports/` |
| System crash reports | `/Library/Logs/DiagnosticReports/` |
| Kernel panic reports | `/Library/Logs/DiagnosticReports/` |

### Crash Report File Formats

| Extension | Description |
|-------|------|
| `.crash` | General app crashes |
| `.spin` | Unresponsive (spinning) |
| `.hang` | App hang |
| `.panic` | Kernel panic |
| `.diag` | System diagnostics |

### Crash Report Analysis

```bash
# Check recent crash reports
ls -lt ~/Library/Logs/DiagnosticReports/ | head -10

# Find crash history for a specific app
ls ~/Library/Logs/DiagnosticReports/ | grep -i "safari"

# View crash report contents
cat ~/Library/Logs/DiagnosticReports/Safari_*.crash | head -50
```

## Log Management via Console App

Console app is macOS's built-in log viewer.

### How to Use

1. Launch `/Applications/Utilities/Console.app`
2. Select log type from left sidebar:
   - **Log Reports**: System logs
   - **Crash Reports**: Crash reports
   - **Spin Reports**: Unresponsive reports
   - **Diagnostic Reports**: Diagnostic reports

### Cleanup in Console

1. Right-click item → "Reveal in Finder"
2. Delete in Finder
3. Or right-click → "Move to Trash"

## Unified Logging System

### New Logging System in macOS 10.12+

Starting with macOS Sierra, Apple introduced the Unified Logging System.

```bash
# Stream logs in real-time
log stream

# Logs for a specific process
log stream --predicate 'processImagePath CONTAINS "Safari"'

# Search stored logs
log show --last 1h

# Export logs
log collect --last 1h --output ~/Desktop/logs.logarchive
```

### Log Archive Location

```bash
# System log database
/var/db/diagnostics/

# Time Machine log archives
/var/db/diagnostics/Persist/
```

## Safe Log Cleanup

### User Log Cleanup

```bash
#!/bin/bash
# cleanup_user_logs.sh

echo "=== User Logs Cleanup ==="

# Delete crash reports older than 30 days
find ~/Library/Logs/DiagnosticReports -mtime +30 -delete

# Delete empty log files
find ~/Library/Logs -type f -empty -delete

# Show total remaining logs size
echo "Remaining logs size:"
du -sh ~/Library/Logs

echo "Cleanup complete"
```

### System Log Cleanup (Use with Caution)

```bash
#!/bin/bash
# cleanup_system_logs.sh (requires root)

echo "=== System Logs Cleanup ==="

# Clean ASL logs (older than 7 days)
sudo find /private/var/log/asl -mtime +7 -delete

# Compress old system logs
sudo gzip /private/var/log/*.log.*[0-9]

# Force log rotation
sudo newsyslog -Fv

echo "Cleanup complete"
```

## Log Rotation Configuration

### newsyslog.conf

```bash
# Configuration file location
/etc/newsyslog.conf
/etc/newsyslog.d/

# Check current configuration
cat /etc/newsyslog.conf
```

### Main Configuration Fields

| Field | Description |
|-----|------|
| logfile | Log file path |
| mode | New file permissions |
| count | Number of archives to keep |
| size | Size trigger for rotation |
| when | Rotation schedule |

## ASL (Apple System Logger)

### ASL Database

```bash
# ASL storage location
/private/var/log/asl/

# Check ASL size
sudo du -sh /private/var/log/asl

# Read ASL logs
syslog -d /private/var/log/asl
```

### aslmanager Configuration

```bash
# Configuration files
/etc/asl/

# Check ASL cleanup policy
cat /etc/asl/com.apple.system
```

## Diagnostics and Usage Data

### System Diagnostics Data

```bash
# Location
/private/var/db/diagnostics/

# Check size
sudo du -sh /private/var/db/diagnostics
```

### Usage Data and Analytics

Managed in System Settings:
- **System Settings → Privacy & Security → Analytics & Improvements**
- Turn off "Share Mac Analytics" → Stops future collection

## Space Recovery Estimates

| Log Type | Expected Recovery Space | Risk Level |
|----------|--------------|--------|
| Crash reports | 100MB - 1GB | ✅ Low |
| User app logs | 200MB - 2GB | ✅ Low |
| System logs (old) | 500MB - 3GB | ⚠️ Medium |
| ASL archives | 100MB - 500MB | ⚠️ Medium |
| Diagnostics data | 100MB - 1GB | ⚠️ Medium |

## Monitoring Script

```bash
#!/bin/bash
# log_monitor.sh

echo "=== macOS Log Status Report ==="
echo "Date: $(date)"
echo ""

echo "User Logs:"
du -sh ~/Library/Logs 2>/dev/null

echo ""
echo "User Crash Reports:"
ls ~/Library/Logs/DiagnosticReports/*.crash 2>/dev/null | wc -l | xargs echo "Count:"
du -sh ~/Library/Logs/DiagnosticReports 2>/dev/null

echo ""
echo "System Logs (requires sudo):"
sudo du -sh /private/var/log 2>/dev/null

echo ""
echo "Top 5 Largest Log Directories:"
du -sh ~/Library/Logs/* 2>/dev/null | sort -hr | head -5
```

## Best Practices

### Regular Cleanup Recommendations

| Log Type | Recommended Cleanup Frequency | Method |
|----------|--------------|------|
| Crash reports | Monthly | Delete items older than 30 days |
| App logs | Quarterly | Delete logs from unused apps |
| System logs | Annually | Trust newsyslog auto-management |

### Precautions Before Troubleshooting

> **Warning**: Before deleting logs, verify there are no current issues.
>
> - Repeated app crashes → Keep logs
> - System instability → Keep logs
> - Normal operation → Safe to clean

## References

- [Apple - Console App](https://support.apple.com/guide/console/)
- [MacKeeper - Delete Mac Log Files](https://mackeeper.com/blog/how-to-delete-mac-log-files/)
- [AppleInsider - Delete macOS Logs](https://appleinsider.com/inside/macos/tips/how-to-delete-macos-logs-and-crash-reports)
- [iBoysoft - Mac System Log Files](https://iboysoft.com/wiki/mac-system-log-files.html)
