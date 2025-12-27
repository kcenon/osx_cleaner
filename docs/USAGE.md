# Usage Guide

> Complete guide for using OSX Cleaner effectively.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Commands Overview](#commands-overview)
- [Interactive Command](#interactive-command)
- [Analyze Command](#analyze-command)
- [Clean Command](#clean-command)
- [Logs Command](#logs-command)
- [Snapshot Command](#snapshot-command)
- [Config Command](#config-command)
- [Schedule Command](#schedule-command)
- [Monitor Command](#monitor-command)
- [Metrics Command](#metrics-command)
- [Audit Command](#audit-command)
- [Cleanup Logging](#cleanup-logging)
- [Cleanup Levels](#cleanup-levels)
- [Cleanup Targets](#cleanup-targets)
- [Examples and Recipes](#examples-and-recipes)
- [CI/CD Integration](#cicd-integration)

---

## Getting Started

After [installation](INSTALLATION.md), you can start using OSX Cleaner immediately:

```bash
# See what can be cleaned
osxcleaner analyze

# Preview cleanup (dry run)
osxcleaner clean --dry-run

# Perform actual cleanup
osxcleaner clean --level light
```

---

## Commands Overview

| Command | Description | Common Use |
|---------|-------------|------------|
| `interactive` | Launch interactive TUI | Easy navigation |
| `analyze` | Analyze disk usage | Before cleanup |
| `clean` | Clean specified targets | Regular maintenance |
| `logs` | Analyze and clean crash reports | Pre-cleanup analysis |
| `snapshot` | Manage Time Machine snapshots | Free snapshot space |
| `config` | Manage configuration | Initial setup |
| `schedule` | Manage schedules | Automation |
| `monitor` | Monitor disk usage | Disk alerts |
| `metrics` | Prometheus metrics endpoint | Remote monitoring |
| `audit` | View and export audit logs | Compliance reporting |

### Global Options

| Option | Description |
|--------|-------------|
| `--version` | Show version |
| `--help` | Show help |
| `--verbose` | Detailed output |
| `--quiet` | Minimal output |

---

## Interactive Command

The `interactive` command launches a terminal-based user interface for easy navigation.

### Basic Usage

```bash
# Launch interactive mode
osxcleaner interactive
```

### Features

- **Visual disk usage display** with colored progress bar
- **Menu-driven navigation** using number keys
- **Quick access** to all cleanup operations
- **Real-time status** messages and feedback

### Main Menu Options

| Key | Option | Description |
|-----|--------|-------------|
| 1 | Analyze Disk Usage | View disk space analysis |
| 2 | Quick Clean (Light) | Safe cleanup of caches |
| 3 | Normal Clean | Standard cleanup |
| 4 | Deep Clean | Thorough cleanup |
| 5 | Manage Schedules | Setup automated cleanup |
| 6 | Time Machine Snapshots | Manage local snapshots |
| 7 | Configuration | App settings |
| 8 | Monitoring Status | Disk monitoring |
| h | Help | Show help information |
| q | Quit | Exit the application |

### Navigation

- Press **number keys (1-9)** to select menu items
- Press **b** to go back to previous menu
- Press **q** to quit the application
- Press **h** for help at any time

### Sample Interface

```
┌──────────────────────────────────────────────────────────┐
│              OSX Cleaner v0.1.0                          │
├──────────────────────────────────────────────────────────┤
│                                                          │
│   Disk Usage: 385GB / 512GB (75.2%)                     │
│   ████████████████████░░░░░░░░                          │
│                                                          │
│   Main Menu:                                             │
│                                                          │
│   [1] 📊 Analyze Disk Usage                             │
│   [2] 🧹 Quick Clean (Light)                            │
│   [3] 🔧 Normal Clean                                   │
│   [4] 💪 Deep Clean                                     │
│   [5] ⏰ Manage Schedules                               │
│   [6] 📸 Time Machine Snapshots                         │
│   [7] ⚙️  Configuration                                 │
│   [8] 📈 Monitoring Status                              │
│   [h] ❓ Help                                           │
│                                                          │
│          Press [q] to quit, [h] for help                │
└──────────────────────────────────────────────────────────┘
```

### Requirements

- Must be run in a terminal (TTY)
- Not supported in non-interactive environments (CI/CD)

---

## Analyze Command

The `analyze` command scans your system and reports cleanup opportunities.

### Basic Usage

```bash
# Full analysis
osxcleaner analyze

# Verbose analysis with details
osxcleaner analyze --verbose

# Quick summary only
osxcleaner analyze --quiet
```

### Category Filtering

```bash
# Analyze specific category
osxcleaner analyze --category xcode
osxcleaner analyze --category docker
osxcleaner analyze --category browser
osxcleaner analyze --category caches
osxcleaner analyze --category logs
```

### Output Options

```bash
# Show top N largest items
osxcleaner analyze --top 10

# JSON output (for scripting)
osxcleaner analyze --format json

# Table output (default)
osxcleaner analyze --format text
```

### Sample Output

```
OSX Cleaner - Disk Usage Analysis
==================================

System: macOS 14.2 (Sonoma) on Apple Silicon
Scan Time: 2025-12-26 10:30:45

Category Analysis:
------------------
Category              Size        Items    Safety Level
---------------------------------------------------------
Xcode DerivedData     15.2 GB     234      Safe
iOS Simulators        45.0 GB     12       Warning
Docker Images         8.5 GB      45       Warning
Browser Cache         2.1 GB      1,234    Safe
User Caches           3.4 GB      5,678    Caution
System Logs           1.2 GB      890      Caution
---------------------------------------------------------
Total Cleanable:      75.4 GB

Top 5 Largest Items:
1. ~/Library/Developer/CoreSimulator/Devices  - 45.0 GB
2. ~/Library/Developer/Xcode/DerivedData      - 15.2 GB
3. ~/Library/Caches/com.docker.docker         - 8.5 GB
4. ~/Library/Caches/Google/Chrome             - 1.8 GB
5. ~/Library/Logs                             - 1.2 GB
```

---

## Clean Command

The `clean` command performs the actual cleanup operation.

### Basic Usage

```bash
# Clean with default level (normal)
osxcleaner clean

# Always preview first with dry-run
osxcleaner clean --dry-run

# Specify cleanup level
osxcleaner clean --level light
osxcleaner clean --level normal
osxcleaner clean --level deep
```

### Cleanup Levels

| Level | Safety | What Gets Cleaned |
|-------|--------|-------------------|
| `light` | Safest | Browser cache, Trash, old downloads |
| `normal` | Moderate | + User caches, old logs |
| `deep` | Aggressive | + Developer caches, Docker, Simulators |
| `system` | Expert | + System caches (requires sudo) |

### Target Selection

```bash
# Clean specific target only
osxcleaner clean --target browser
osxcleaner clean --target developer
osxcleaner clean --target logs

# Clean all targets
osxcleaner clean --target all
```

### Safety Options

```bash
# Preview only (no actual deletion)
osxcleaner clean --dry-run

# Skip confirmation prompts
osxcleaner clean --non-interactive

# Force cleanup (skip some safety checks)
osxcleaner clean --force
```

### Output Options

```bash
# Verbose output
osxcleaner clean --verbose

# JSON output (for CI/CD)
osxcleaner clean --format json

# Quiet mode (errors only)
osxcleaner clean --quiet
```

### Sample Output

```
OSX Cleaner - Cleanup Preview (Dry Run)
========================================

Cleanup Level: Normal
Targets: All

Items to be cleaned:
--------------------
[Safe]    ~/Library/Caches/Google/Chrome/Default/Cache - 1.2 GB
[Safe]    ~/.Trash - 0.5 GB
[Caution] ~/Library/Caches/com.apple.dt.Xcode - 2.1 GB
[Caution] ~/Library/Logs/DiagnosticReports - 0.3 GB

Summary:
--------
Files to delete: 4,567
Space to free: 4.1 GB
Safety breakdown:
  - Safe items: 1.7 GB (41%)
  - Caution items: 2.4 GB (59%)

Use 'osxcleaner clean --level normal' to proceed.
```

---

## Snapshot Command

The `snapshot` command manages Time Machine local APFS snapshots.

### Why Manage Snapshots?

Time Machine creates local snapshots hourly, which can consume 10-50GB or more:
- Snapshots persist until disk pressure triggers cleanup
- macOS only auto-deletes when disk usage exceeds 80-90%
- Manual management gives you control over disk space

### Basic Usage

```bash
# List all local snapshots
osxcleaner snapshot list

# Show Time Machine status
osxcleaner snapshot status

# Preview thinning (dry run)
osxcleaner snapshot thin --dry-run

# Actually thin all snapshots
osxcleaner snapshot thin --force
```

### List Snapshots

```bash
# List snapshots with basic info
osxcleaner snapshot list

# Verbose output with IDs
osxcleaner snapshot list --verbose

# JSON output
osxcleaner snapshot list --format json
```

**Sample Output:**

```
Found 5 local snapshot(s):

  1. Dec 26, 2025 at 11:00 AM
  2. Dec 26, 2025 at 10:00 AM
  3. Dec 26, 2025 at 9:00 AM
  4. Dec 25, 2025 at 8:00 PM
  5. Dec 25, 2025 at 7:00 PM

Use 'osxcleaner snapshot delete <date>' to remove snapshots.
```

### Check Status

```bash
osxcleaner snapshot status
```

**Sample Output:**

```
Time Machine Status
─────────────────────────────────────────
  Enabled:              Yes ✓
  Currently Backing Up: No
  Last Backup:          Dec 26, 2025 at 10:30 AM
  Destination:          /Volumes/Backup
  Local Snapshots:      5
─────────────────────────────────────────
```

### Delete Specific Snapshot

```bash
# Delete by date (format: YYYY-MM-DD-HHMMSS)
osxcleaner snapshot delete 2025-12-26-110000

# Skip confirmation
osxcleaner snapshot delete 2025-12-26-110000 --force

# Preview without deleting
osxcleaner snapshot delete 2025-12-26-110000 --dry-run
```

### Thin All Snapshots

```bash
# Preview thinning
osxcleaner snapshot thin --dry-run

# Thin with confirmation
osxcleaner snapshot thin

# Thin without confirmation (CI/CD)
osxcleaner snapshot thin --force
```

### Safety Notes

- ⚠️ **Snapshot deletion is irreversible** - once deleted, data cannot be recovered
- ✅ **Safe for disk space** - snapshots are copies, not original files
- 💡 **Recommendation** - always use `--dry-run` first to preview

---

## Config Command

Manage OSX Cleaner configuration.

### View Configuration

```bash
# Show current configuration
osxcleaner config show

# Show specific setting
osxcleaner config get default_level
```

### Modify Configuration

```bash
# Set default cleanup level
osxcleaner config set default_level deep

# Set default format
osxcleaner config set format json

# Enable/disable confirmations
osxcleaner config set confirm_delete true
```

### Configuration File

Configuration is stored in `~/.config/osxcleaner/config.toml`:

```toml
# OSX Cleaner Configuration

[defaults]
level = "normal"
format = "text"
confirm_delete = true
dry_run = false

[paths]
# Additional paths to include in cleanup
include = [
    "~/Downloads/*.dmg",
    "~/Downloads/*.zip"
]

# Paths to exclude from cleanup
exclude = [
    "~/Library/Caches/MyImportantApp"
]

[schedule]
enabled = false
frequency = "weekly"
level = "light"
```

---

## Schedule Command

Automate cleanup with launchd scheduling.

### Create Schedules

```bash
# Daily cleanup at 3 AM
osxcleaner schedule add --frequency daily --level light --hour 3

# Weekly cleanup on Sundays at 2 AM
osxcleaner schedule add --frequency weekly --level normal --day sunday --hour 2

# Monthly cleanup on 1st at 4 AM
osxcleaner schedule add --frequency monthly --level deep --day 1 --hour 4
```

### Manage Schedules

```bash
# List all schedules
osxcleaner schedule list

# Enable a schedule
osxcleaner schedule enable daily

# Disable a schedule
osxcleaner schedule disable daily

# Remove a schedule
osxcleaner schedule remove daily
```

### Sample Schedule List

```
OSX Cleaner - Scheduled Tasks
==============================

Name       Frequency  Level   Time        Status
-------------------------------------------------
daily      Daily      Light   03:00       Enabled
weekly     Weekly     Normal  Sun 02:00   Enabled
monthly    Monthly    Deep    1st 04:00   Disabled

Next scheduled run: daily at 2025-12-27 03:00:00
```

---

## Logs Command

Analyze and clean crash reports and logs. View crash report analysis before cleanup to identify problematic apps.

### Analyze Crash Reports

```bash
# Show crash report analysis
osxcleaner logs analyze

# Detailed output
osxcleaner logs analyze --verbose

# JSON output for scripting
osxcleaner logs analyze --format json
```

**Example Output:**
```
Crash Report Analysis
─────────────────────────────────────────
  Safari: 3 reports (latest: 2 days ago)
  Xcode: 12 reports (latest: today)  ⚠️ Repeated crashes
  Finder: 1 report (latest: 45 days ago)

─────────────────────────────────────────
  Total: 16 reports (2.3MB)
  Reports older than 30 days: 8 reports (1.1MB)

💡 Recommendation:
   The following apps have repeated crashes. Consider:
   - Updating to the latest version
   - Reinstalling the app
   - Checking for known issues

   • Xcode (12 crashes)
```

### Clean Crash Reports

```bash
# Clean reports older than 30 days (default)
osxcleaner logs clean

# Clean reports older than 7 days
osxcleaner logs clean --age 7

# Clean all crash reports
osxcleaner logs clean --all

# Preview cleanup (dry run)
osxcleaner logs clean --dry-run

# Skip confirmation
osxcleaner logs clean --force
```

### Supported Report Types

| Extension | Description | macOS Version |
|-----------|-------------|---------------|
| `.crash` | Traditional crash report | All |
| `.ips` | Modern crash format (JSON-based) | 12+ |
| `.spin` | Spin report (unresponsive app) | All |
| `.hang` | Hang report | All |
| `.diag` | Diagnostic report | All |

---

## Monitor Command

Monitor disk usage and receive alerts when disk space is running low.

### Check Status

```bash
# Show current disk usage and monitoring status
osxcleaner monitor status

# JSON output for scripting
osxcleaner monitor status --format json
```

### Enable Monitoring

```bash
# Enable with default settings (1 hour interval)
osxcleaner monitor enable

# Custom interval (30 minutes)
osxcleaner monitor enable --interval 1800

# Enable with auto-cleanup at emergency threshold
osxcleaner monitor enable --auto-cleanup --level light

# Custom thresholds
osxcleaner monitor enable --warning 80 --critical 88 --emergency 93
```

### Disable Monitoring

```bash
# Disable background monitoring
osxcleaner monitor disable
```

### Manual Check

```bash
# Perform immediate disk usage check
osxcleaner monitor check

# Check with auto-cleanup if threshold exceeded
osxcleaner monitor check --auto-cleanup --level light

# Quiet mode (no notifications)
osxcleaner monitor check --quiet
```

### Disk Thresholds

| Threshold | Default | Notification |
|-----------|---------|--------------|
| Warning   | 85%     | Yellow alert |
| Critical  | 90%     | Orange alert with recommendation |
| Emergency | 95%     | Red alert, auto-cleanup if enabled |

---

## Metrics Command

Expose Prometheus metrics for remote monitoring with tools like Prometheus and Grafana.

### Start Metrics Server

```bash
# Start with default settings (port 9090)
osxcleaner metrics start

# Start with custom port
osxcleaner metrics start --port 8080

# Run in foreground (useful for debugging)
osxcleaner metrics start --foreground
```

### View Metrics

```bash
# Display current metrics in Prometheus format
osxcleaner metrics show

# Check server status
osxcleaner metrics status

# JSON output
osxcleaner metrics status --format json

# Via curl
curl http://localhost:9090/metrics
```

### Stop Server

```bash
osxcleaner metrics stop
```

### Available Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `osxcleaner_disk_total_bytes` | Gauge | Total disk space in bytes |
| `osxcleaner_disk_available_bytes` | Gauge | Available disk space in bytes |
| `osxcleaner_disk_used_bytes` | Gauge | Used disk space in bytes |
| `osxcleaner_disk_usage_percent` | Gauge | Disk usage percentage |
| `osxcleaner_cleanup_operations_total` | Counter | Total cleanup operations |
| `osxcleaner_bytes_cleaned_total` | Counter | Total bytes cleaned |
| `osxcleaner_files_removed_total` | Counter | Total files removed |
| `osxcleaner_cleanup_errors_total` | Counter | Total cleanup errors |

### Prometheus Configuration

Add to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'osxcleaner'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 30s
```

### Grafana Dashboard

A pre-built dashboard is available at [`docs/monitoring/grafana-dashboard.json`](monitoring/grafana-dashboard.json).

For detailed documentation, see [Monitoring Guide](monitoring/MONITORING.md).

---

## Audit Command

The `audit` command provides enterprise-grade audit logging for compliance and reporting.

### View Recent Events

```bash
# List last 20 events
osxcleaner audit list

# List last 50 events
osxcleaner audit list --count 50

# Filter by category
osxcleaner audit list --category cleanup

# Filter by result
osxcleaner audit list --result failure

# JSON output
osxcleaner audit list --json
```

### Show Event Details

```bash
# Show details of a specific event
osxcleaner audit show <event-id>

# Show the last event
osxcleaner audit show last

# JSON output
osxcleaner audit show last --json
```

### View Statistics

```bash
# Show all-time statistics
osxcleaner audit stats

# Statistics for last 30 days
osxcleaner audit stats --days 30

# JSON format
osxcleaner audit stats --json
```

### Export Events

```bash
# Export to JSON (default)
osxcleaner audit export

# Export to CSV
osxcleaner audit export --format csv

# Export to JSON Lines
osxcleaner audit export --format jsonl

# Export with custom output path
osxcleaner audit export --output /path/to/export.json

# Export last 7 days only
osxcleaner audit export --days 7

# Export specific category
osxcleaner audit export --category security
```

### Clear Old Events

```bash
# Apply retention policy (delete events older than N days)
osxcleaner audit clear --older-than 90 --force

# Clear ALL events (use with caution)
osxcleaner audit clear --all --force
```

### Audit System Info

```bash
# Show audit system information
osxcleaner audit info
```

### Event Categories

| Category | Description |
|----------|-------------|
| `cleanup` | File deletion, cache cleanup operations |
| `policy` | Policy application, compliance checks |
| `security` | Access control, authentication events |
| `system` | Startup, shutdown, configuration changes |
| `user` | Manual user actions |

### Event Results

| Result | Description |
|--------|-------------|
| `success` | Operation completed successfully |
| `failure` | Operation failed |
| `warning` | Operation completed with warnings |
| `skipped` | Operation was skipped |

---

## Cleanup Logging

All automated cleanup operations are logged for audit and debugging purposes.

### Log Location

Logs are stored in `~/.config/osxcleaner/logs/cleanup.log`.

### Log Format

Each log entry is a JSON object:

```json
{
  "timestamp": "2025-12-26T15:30:00.000+0900",
  "level": "INFO",
  "event": "SESSION_START",
  "session_id": "abc123-def456",
  "message": "Cleanup session started",
  "details": {
    "trigger_type": "scheduled",
    "cleanup_level": "light"
  }
}
```

### Trigger Types

| Type | Description |
|------|-------------|
| `manual` | User-initiated cleanup |
| `scheduled` | Scheduled cleanup via launchd |
| `auto_cleanup` | Triggered by schedule with `--non-interactive` |
| `disk_monitor` | Triggered by disk usage threshold |

### Log Rotation

- Maximum log file size: 10 MB
- Rotated files kept: 5
- Rotation creates: `cleanup.log.1`, `cleanup.log.2`, etc.

### Reading Logs

```bash
# View recent log entries
tail -20 ~/.config/osxcleaner/logs/cleanup.log | jq .

# Filter by event type
grep "SESSION_END" ~/.config/osxcleaner/logs/cleanup.log | jq .

# Get total freed space from recent sessions
grep "SESSION_END" ~/.config/osxcleaner/logs/cleanup.log | jq -r '.details.freed_formatted'
```

---

## Cleanup Levels

### Level 1: Light (Safest)

```bash
osxcleaner clean --level light
```

**What gets cleaned:**
- Empty Trash
- Browser caches (Safari, Chrome, Firefox, Edge)
- Old downloads (90+ days)
- Old screenshots (30+ days)

**Safety:** ✅ Cannot damage system, all items auto-regenerate

### Level 2: Normal (Moderate)

```bash
osxcleaner clean --level normal
```

**What gets cleaned:**
- Everything in Level 1
- User caches (`~/Library/Caches/*`)
- Old logs (30+ days)
- Crash reports (30+ days)

**Safety:** ⚠️ May require rebuilding some caches

### Level 3: Deep (Aggressive)

```bash
osxcleaner clean --level deep
```

**What gets cleaned:**
- Everything in Level 2
- Xcode DerivedData
- iOS Simulators (outdated versions)
- CocoaPods/SPM cache
- npm/yarn/pnpm cache
- Docker unused images and build cache
- Homebrew old versions

**Safety:** ⚠️⚠️ May require re-downloading large files

### Level 4: System (Expert)

```bash
sudo osxcleaner clean --level system
```

**What gets cleaned:**
- Everything in Level 3
- System caches (`/Library/Caches`)
- Shared caches

**Safety:** ❌ Requires root privileges, use with caution

---

## Cleanup Targets

### Browser

```bash
osxcleaner clean --target browser
```

Cleans:
- Safari cache and history
- Chrome cache
- Firefox cache
- Edge cache
- Brave cache
- Opera cache
- Arc cache

### Developer

```bash
osxcleaner clean --target developer
```

Cleans:
- Xcode DerivedData and Archives
- iOS/watchOS Device Support
- iOS Simulators
- Package managers (npm, yarn, pip, brew, cargo, etc.)
- Docker images, containers, volumes

### Logs

```bash
osxcleaner clean --target logs
```

Cleans user-level logs and diagnostic data:
- User application logs (`~/Library/Logs/`)
- Crash reports (`~/Library/Logs/DiagnosticReports/*.crash`)
- Spin reports (unresponsive apps, `*.spin`)
- Hang reports (frozen apps, `*.hang`)
- Diagnostic reports (`*.diag`)

**Note:** System logs (`/var/log/`) are read-only and managed by macOS `newsyslog`.
Refer to `SRS-FR-F04-001` and `SRS-FR-F04-002` for detailed requirements.

---

## Examples and Recipes

### Weekly Maintenance Routine

```bash
# Analyze first
osxcleaner analyze

# Preview cleanup
osxcleaner clean --level normal --dry-run

# If satisfied, proceed
osxcleaner clean --level normal
```

### Developer Pre-Release Cleanup

```bash
# Deep clean developer caches before release
osxcleaner clean --level deep --target developer --dry-run

# Proceed if safe
osxcleaner clean --level deep --target developer
```

### Disk Space Emergency

```bash
# Quickly find largest items
osxcleaner analyze --top 20 --verbose

# Clean aggressively
osxcleaner clean --level deep
```

### Automated Daily Maintenance

```bash
# Set up daily cleanup
osxcleaner schedule add --frequency daily --level light --hour 3

# Verify schedule
osxcleaner schedule list
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Clean CI Disk

on:
  workflow_dispatch:
  schedule:
    - cron: '0 3 * * *'

jobs:
  cleanup:
    runs-on: macos-latest
    steps:
      - name: Install OSX Cleaner
        run: |
          git clone https://github.com/kcenon/osx_cleaner.git
          cd osx_cleaner && make all && make install

      - name: Run Cleanup
        run: |
          osxcleaner clean --level deep --non-interactive --format json
```

### Jenkins Pipeline Example

```groovy
pipeline {
    agent { label 'macos' }

    stages {
        stage('Cleanup') {
            steps {
                sh 'osxcleaner clean --level normal --non-interactive --format json'
            }
        }
    }

    post {
        always {
            sh 'osxcleaner analyze --format json > cleanup-report.json'
            archiveArtifacts 'cleanup-report.json'
        }
    }
}
```

### JSON Output for Scripting

```bash
# Get cleanup results as JSON
osxcleaner clean --level light --format json | jq '.freed_space'

# Parse analysis results
osxcleaner analyze --format json | jq '.categories[] | select(.size_gb > 1)'
```

---

## GUI Application

OSX Cleaner also provides a native macOS GUI application.

### Launching the GUI

```bash
# Build and run the GUI
swift run OSXCleanerGUI

# Or build and launch separately
swift build --product OSXCleanerGUI
open .build/debug/OSXCleanerGUI.app
```

### GUI Features

- **Dashboard** - View disk usage overview and quick actions
- **Clean** - Select cleanup targets and levels with scan preview
- **Schedule** - Manage automated cleanup schedules
- **Settings** - Configure preferences and monitoring

### Localization Support

The GUI application supports multiple languages:

| Language | Code | Status |
|----------|------|--------|
| English | `en` | Default |
| Korean | `ko` | Complete |
| Japanese | `ja` | Complete |

#### Changing Language

1. Open the GUI application
2. Navigate to **Settings**
3. Select your preferred language from the **Language** picker
4. The interface will update immediately

#### System Language Detection

By default, the application uses your macOS system language. If your system language is Korean or Japanese, the app will automatically display in that language.

To override this behavior, select a specific language in Settings instead of "System Default".

### Adding New Translations

To contribute a new language translation:

1. Create a new `.lproj` folder in `Sources/OSXCleanerGUI/Resources/`
2. Copy `en.lproj/Localizable.strings` as a template
3. Translate all string values
4. Update `AppLanguage` enum in `Localization/Localization.swift`
5. Submit a pull request

---

## See Also

- [Installation Guide](INSTALLATION.md)
- [Safety Information](SAFETY.md)
- [Contributing Guide](CONTRIBUTING.md)

---

*Last updated: 2025-12-26*
