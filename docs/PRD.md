# OSX Cleaner - Product Requirements Document (PRD)

> **Version**: 0.1.0.0 (English)
> **Created**: 2025-12-25
> **Status**: Draft

---

## 1. Executive Summary

### 1.1 Product Vision

**OSX Cleaner** is a tool that **safely** cleans unnecessary files (temporary files, caches, logs, etc.) on macOS systems to free up disk space and optimize system performance.

### 1.2 Key Value Propositions

| Value | Description |
|-----|------|
| **Safety First** | 4-level safety classification system (✅ Safe → ❌ Danger) prevents system damage |
| **Developer-Focused** | Specialized management of development tool caches including Xcode, Docker, npm, Homebrew (can save 50-150GB) |
| **Version Compatibility** | Full support from macOS Catalina (10.15) to Sequoia (15.x) |
| **Automation Support** | launchd-based scheduling and CI/CD pipeline integration |

---

## 2. Problem Statement

### 2.1 Problem Definition

macOS users, especially developers, face the following challenges:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Developer Mac (512GB SSD)                     │
├─────────────────────────────────────────────────────────────────┤
│ Xcode + Simulators          ██████████████░░░░░░  80GB (16%)     │
│ Docker                      ██████░░░░░░░░░░░░░░  30GB (6%)      │
│ Various Caches              ████████░░░░░░░░░░░░  50GB (10%)     │
│ node_modules (scattered)    ████░░░░░░░░░░░░░░░░  20GB (4%)      │
│ System Data (opaque)        ██████░░░░░░░░░░░░░░  35GB (7%)      │
└─────────────────────────────────────────────────────────────────┘
  → Cache/temporary data alone occupies 200GB+ (40%)
```

### 2.2 Limitations of Existing Solutions

| Existing Solution | Limitations |
|------------|--------|
| Manual Cleanup | Complex paths, risk of errors, time-consuming |
| CleanMyMac etc. | Paid, lacks developer tool support, overly aggressive cleanup causing system issues |
| System Auto-Cleanup | Only targets `/private/var/folders`, excludes user caches |
| macOS Storage Management | Limited options, no developer cache support |

---

## 3. Target Users

### 3.1 Primary Personas

#### Persona 1: iOS/macOS Developer
- **Environment**: Xcode, multiple Simulators, CocoaPods/SPM
- **Pain Point**: DerivedData 50GB+, iOS Device Support 100GB+
- **Cleanup Potential**: 50-150GB

#### Persona 2: Full-Stack Developer
- **Environment**: Node.js, Docker, Python, multiple IDEs
- **Pain Point**: Scattered node_modules, accumulated Docker images
- **Cleanup Potential**: 30-80GB

#### Persona 3: DevOps Engineer
- **Environment**: CI/CD build machines, multi-user setups
- **Pain Point**: Build failures (disk full), manual management burden
- **Cleanup Potential**: Real-time monitoring and automated cleanup needed

#### Persona 4: General Power User
- **Environment**: Browsers, office apps, cloud sync
- **Pain Point**: Safari/Chrome caches, accumulated downloads folder
- **Cleanup Potential**: 5-30GB

### 3.2 User Segmentation

```
                    Technical Expertise
                    Low ←───────────→ High
                     │
     Space Savings   │  General User │ Developer
         Low        │───────────────┼──────────────
                     │               │
                     │  Light User   │ DevOps/CI
        High         │               │
                     └───────────────┴──────────────
```

---

## 4. Core Features

### 4.1 Feature Overview

| Feature ID | Feature Name | Priority | Target Users |
|------------|--------|:--------:|------------|
| F01 | Safety-Based Cleanup System | P0 | All |
| F02 | Developer Tool Cache Management | P0 | Developer |
| F03 | Browser/App Cache Cleanup | P0 | All |
| F04 | Log and Crash Report Management | P1 | All |
| F05 | Time Machine Snapshot Management | P1 | All |
| F06 | Disk Usage Analysis/Visualization | P1 | All |
| F07 | Automation Scheduling | P1 | Developer/DevOps |
| F08 | CI/CD Pipeline Integration | P2 | DevOps |
| F09 | Team Environment Management | P2 | DevOps |
| F10 | macOS Version Optimization | P1 | All |

---

### 4.2 F01: Safety-Based Cleanup System

#### 4.2.1 Safety Classification

4-level safety classification system:

| Level | Indicator | Description | Examples |
|-------|------|------|------|
| **Safe** | ✅ | Can delete immediately, auto-regenerates | Browser cache, Trash |
| **Caution** | ⚠️ | Can delete but requires rebuild time | User caches, old logs |
| **Warning** | ⚠️⚠️ | Can delete but requires data re-download | iOS Device Support, Docker images |
| **Danger** | ❌ | Do not delete, can damage system | `/System/*`, Keychains |

#### 4.2.2 Golden Rules (Built-in)

1. **System Folder Protection**: Never access `/System/`, `/usr/bin/`, `/private/var/db/`
2. **com.apple.* Warning**: Additional confirmation before deleting Apple system components
3. **Running App Detection**: Warning before deleting cache of running apps
4. **Backup Recommendation**: Recommend Time Machine backup before Level 2+ cleanup

#### 4.2.3 Cleanup Levels

```
┌─────────────────────────────────────────────────────────────┐
│ Level 1: Light (✅ Safe)                                    │
│ ├── Empty Trash                                             │
│ ├── Browser caches (Safari, Chrome, Firefox, Edge)          │
│ ├── Old downloads (90+ days)                                │
│ └── Old screenshots (30+ days)                              │
├─────────────────────────────────────────────────────────────┤
│ Level 2: Normal (⚠️ Caution)                                │
│ ├── Level 1 included                                        │
│ ├── All user caches (~/Library/Caches/*)                    │
│ ├── Old logs (30+ days)                                     │
│ ├── Crash reports (30+ days)                                │
│ └── Saved Application State                                │
├─────────────────────────────────────────────────────────────┤
│ Level 3: Deep (⚠️⚠️ Warning)                                │
│ ├── Level 2 included                                        │
│ ├── Xcode DerivedData                                       │
│ ├── iOS Simulator (unavailable)                             │
│ ├── CocoaPods/SPM cache                                     │
│ ├── npm/yarn/pnpm cache                                     │
│ ├── Docker (dangling images, build cache)                   │
│ ├── Homebrew old versions                                   │
│ └── JetBrains/VS Code cache                                 │
├─────────────────────────────────────────────────────────────┤
│ Level 4: System (❌ Not Recommended)                        │
│ ├── /Library/Caches (requires root)                         │
│ └── → Instead, recommend Safe Mode boot or periodic scripts │
└─────────────────────────────────────────────────────────────┘
```

---

### 4.3 F02: Developer Tool Cache Management

#### 4.3.1 Xcode Cache

| Item | Path | Typical Size | Safety |
|-----|------|-----------|--------|
| DerivedData | `~/Library/Developer/Xcode/DerivedData/` | 5-50GB | ✅ |
| Module Cache | `~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/` | 1-5GB | ✅ |
| Archives | `~/Library/Developer/Xcode/Archives/` | 1-20GB | ⚠️ |
| iOS Device Support | `~/Library/Developer/Xcode/iOS DeviceSupport/` | 20-100GB | ⚠️⚠️ |
| watchOS Device Support | `~/Library/Developer/Xcode/watchOS DeviceSupport/` | 5-20GB | ⚠️⚠️ |

#### 4.3.2 iOS Simulator

| Task | Command | Description |
|-----|-------|------|
| List all | `xcrun simctl list devices` | All simulators |
| Delete unavailable | `xcrun simctl delete unavailable` | Safe cleanup |
| Delete runtime | `xcrun simctl runtime delete [ID]` | Old runtimes |
| Erase all | `xcrun simctl erase all` | Reset data |

#### 4.3.3 Package Managers

| Tool | Cache Path | Cleanup Command |
|-----|----------|----------|
| CocoaPods | `~/Library/Caches/CocoaPods/` | `pod cache clean --all` |
| SPM | `~/Library/Caches/org.swift.swiftpm/` | Direct deletion |
| Carthage | `~/Library/Caches/org.carthage.CarthageKit/` | Direct deletion |
| npm | `~/.npm/` | `npm cache clean --force` |
| yarn | `~/Library/Caches/Yarn/` | `yarn cache clean` |
| pnpm | `pnpm store path` | `pnpm store prune` |
| pip | `~/Library/Caches/pip/` | `pip cache purge` |
| Homebrew | `$(brew --cache)` | `brew cleanup -s` |

#### 4.3.4 Docker

| Task | Command | Description |
|-----|-------|------|
| Check usage | `docker system df` | Total usage |
| Basic cleanup | `docker system prune -f` | Stopped containers, dangling images |
| Full cleanup | `docker system prune -a --volumes` | All unused data (caution) |
| Build cache | `docker builder prune` | Build cache only |

---

### 4.4 F03: Browser/App Cache Cleanup

#### 4.4.1 Browser Caches

| Browser | Cache Path | Typical Size |
|---------|----------|-----------|
| Safari | `~/Library/Caches/com.apple.Safari/` | 0.5-5GB |
| Chrome | `~/Library/Caches/Google/Chrome/` | 0.5-10GB |
| Firefox | `~/Library/Caches/Firefox/` | 0.5-3GB |
| Edge | `~/Library/Caches/Microsoft Edge/` | 0.5-3GB |

#### 4.4.2 Cloud Service Caches

| Service | Cache Path | Precautions |
|-------|----------|---------|
| iCloud | `~/Library/Caches/com.apple.bird/` | Verify sync before deletion |
| Dropbox | `~/Library/Caches/com.getdropbox.dropbox/` | Verify sync |
| OneDrive | `~/Library/Caches/com.microsoft.OneDrive/` | Verify sync |
| Google Drive | `~/Library/Caches/com.google.GoogleDrive/` | Caution with streaming files |

---

### 4.5 F04: Log and Crash Report Management

#### 4.5.1 Log Locations

| Log Type | Path | Safety |
|----------|------|--------|
| User logs | `~/Library/Logs/` | ✅ (30+ days) |
| User crashes | `~/Library/Logs/DiagnosticReports/` | ✅ (30+ days) |
| System logs | `/private/var/log/` | ⚠️ (requires root) |
| System crashes | `/Library/Logs/DiagnosticReports/` | ⚠️ |

#### 4.5.2 Cleanup Strategy

- **Crash Reports**: Automatically clean files older than 30 days
- **App Logs**: Clean after user confirmation
- **System Logs**: Trust `newsyslog` auto-management, manual cleanup not recommended

---

### 4.6 F05: Time Machine Snapshot Management

#### 4.6.1 Snapshot Management Functions

| Function | Command | Description |
|-----|------|------|
| List snapshots | `tmutil listlocalsnapshots /` | Current snapshots |
| Delete specific | `tmutil deletelocalsnapshots [date]` | Delete by date |
| Thin all | `tmutil thinlocalsnapshots / 9999999999999` | Free up space |

#### 4.6.2 Automatic Cleanup Policy Display

| Disk Usage | macOS Behavior |
|-------------|-----------|
| < 80% | Keep snapshots normally |
| 80-90% | Start deleting with low priority |
| > 90% | Fast deletion with high priority |

---

### 4.7 F06: Disk Usage Analysis/Visualization

#### 4.7.1 Dashboard Components

```
╔════════════════════════════════════════════════════════════╗
║           OSX Cleaner - Disk Overview                       ║
╠════════════════════════════════════════════════════════════╣
║  Current: 385GB / 512GB (75% used) | 127GB available        ║
╠════════════════════════════════════════════════════════════╣
║                                                              ║
║  📊 Usage by Category                                        ║
║  ─────────────────────────────────────────────────────────  ║
║  Xcode & Simulators     ████████████████░░░░  80GB (16%)    ║
║  User Caches            ██████████░░░░░░░░░░  50GB (10%)    ║
║  Docker                 ██████░░░░░░░░░░░░░░  30GB (6%)     ║
║  node_modules           ████░░░░░░░░░░░░░░░░  20GB (4%)     ║
║  System Data            ██████░░░░░░░░░░░░░░  35GB (7%)     ║
║  User Data              ████████████████████ 100GB (20%)    ║
║                                                              ║
║  🧹 Expected Cleanable Space                                 ║
║  ─────────────────────────────────────────────────────────  ║
║  ✅ Safe (immediate cleanup)        12GB                     ║
║  ⚠️ Caution (careful attention)     35GB                     ║
║  ⚠️⚠️ Warning (re-download needed)  45GB                     ║
║                                        Total estimate: 92GB  ║
╚════════════════════════════════════════════════════════════╝
```

#### 4.7.2 Analysis Items

- User home directory Top 10
- ~/Library/Caches analysis by app
- ~/Library/Developer analysis by component
- Docker usage (images/containers/volumes/build cache)
- node_modules distribution (by project)

---

### 4.8 F07: Automation Scheduling

#### 4.8.1 Schedule Options

| Frequency | Recommended Level | Target |
|-----|--------------|------|
| Daily | Light | Browser cache, 7+ day logs |
| Weekly | Normal | User caches, DerivedData |
| Monthly | Deep | All developer caches |

#### 4.8.2 launchd Integration

```xml
<!-- Example: Weekly cleanup -->
<dict>
    <key>Label</key>
    <string>com.osxcleaner.weekly</string>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer> <!-- Sunday -->
        <key>Hour</key>
        <integer>3</integer>
    </dict>
</dict>
```

#### 4.8.3 Disk Monitoring + Notifications

- macOS notification when usage exceeds 85%
- Automatic Light cleanup execution when usage exceeds 95% (optional)

---

### 4.9 F08: CI/CD Pipeline Integration

#### 4.9.1 Supported Platforms

| Platform | Integration Method | Supported Features |
|-------|----------|----------|
| GitHub Actions | Action / Script | Pre/Post build cleanup |
| Jenkins | Pipeline Step | Disk check + cleanup |
| Fastlane | Lane | Pre/Post build cleanup |
| Xcode Cloud | Script Phase | Limited support |

#### 4.9.2 Pre-Build Disk Check

```bash
FREE_SPACE=$(df -h / | awk 'NR==2 {print $4}' | tr -d 'Gi')
if [ "${FREE_SPACE%.*}" -lt 20 ]; then
    echo "::warning::Low disk space! Running cleanup..."
    osxcleaner --level deep --non-interactive
fi
```

---

### 4.10 F10: macOS Version Optimization

#### 4.10.1 Version-Specific Considerations

| Version | Codename | Special Issues | Special Handling |
|-----|-------|---------|----------|
| 15.x | Sequoia | `mediaanalysisd` bug (15.1) | Special cache cleanup |
| 14.x | Sonoma | Safari profile separation | Cache paths per profile |
| 13.x | Ventura | System Settings UI change | Path guidance updates |
| 12.x | Monterey | System Data introduction | Category analysis |
| 11.x | Big Sur | Apple Silicon introduction | Rosetta cache |
| 10.15 | Catalina | Volume separation start | Legacy app cleanup |

#### 4.10.2 Safe Mode Guide

- **Apple Silicon**: Shutdown → Long press power → Shift + "Macintosh HD"
- **Intel**: Restart → Hold Shift key

---

## 5. Technical Requirements

### 5.1 System Requirements

| Item | Minimum | Recommended |
|-----|------|------|
| macOS | 10.15 Catalina | 14.x Sonoma+ |
| Architecture | Intel x64, Apple Silicon (arm64) | Apple Silicon |
| Disk Space | 50MB (app) | - |
| Permissions | Full Disk Access | + Automation |

### 5.2 Technology Stack

#### 5.2.1 Core Options

| Option | Advantages | Disadvantages |
|--------|------|------|
| **Swift + SwiftUI** | Native performance, system integration | Requires Swift expertise |
| **Rust + Tauri** | Fast execution, small binary | Limited GUI |
| **Electron** | Cross-platform, rapid development | High resource usage |
| **Shell Script** | Simple, immediate use | No GUI, difficult maintenance |

**Recommendation**: Swift + SwiftUI (macOS native app) or Shell Script (CLI tool)

#### 5.2.2 CLI Structure (Shell Script-based)

```
osxcleaner/
├── bin/
│   └── osxcleaner              # Main entry point
├── lib/
│   ├── core/
│   │   ├── safety.sh           # Safety validation
│   │   ├── analyzer.sh         # Disk analysis
│   │   └── cleaner.sh          # Cleanup execution
│   ├── targets/
│   │   ├── browser.sh          # Browser cache
│   │   ├── developer.sh        # Developer tools
│   │   ├── system.sh           # System cache
│   │   └── logs.sh             # Log cleanup
│   └── utils/
│       ├── logger.sh           # Logging
│       ├── notification.sh     # Notifications
│       └── config.sh           # Configuration management
├── config/
│   └── default.conf            # Default configuration
└── launchd/
    ├── com.osxcleaner.daily.plist
    └── com.osxcleaner.weekly.plist
```

### 5.3 Security Considerations

#### 5.3.1 Permission Requirements

| Feature | Required Permission | Request Timing |
|-----|----------|----------|
| User cache cleanup | None | - |
| System cache cleanup | sudo | At execution |
| Automation | Automation | At setup |
| Full access | Full Disk Access | At installation |

#### 5.3.2 Security Principles

1. **Least Privilege**: Request elevated permissions only when necessary
2. **Transparency**: Always display deletion targets in advance
3. **Recoverability**: Provide move-to-trash option (instead of immediate deletion)
4. **Audit Log**: Log all cleanup operations

---

## 6. Safety & Risk Management

### 6.1 Protection Rules

#### 6.1.1 Never Delete List (Hardcoded)

```
PROTECTED_PATHS=(
    "/System/"
    "/usr/bin/"
    "/usr/sbin/"
    "/bin/"
    "/sbin/"
    "/private/var/db/"
    "/private/var/folders/"  # Manual deletion prohibited
    "~/Library/Keychains/"
    "~/Library/Application Support/"  # Full deletion prohibited
    "~/Library/Mail/"
    "~/Library/Messages/"
    "~/Library/Preferences/"  # Full deletion prohibited
)
```

#### 6.1.2 Warning Display Targets

```
WARNING_PATHS=(
    "~/Library/Containers/"           # Sandboxed app data
    "~/Library/Group Containers/"     # Shared app data
    "/Library/Caches/"                # System cache
    "com.apple.*"                     # Apple system components
)
```

### 6.2 Pre-Cleanup Checks

1. **App Running Status Check**: Warning if the app is running
2. **Cloud Sync Check**: Warning during iCloud/Dropbox sync
3. **Disk Space Check**: Display expected space before/after cleanup
4. **Time Machine Status**: Display last backup time

### 6.3 Recovery Options

| Situation | Recovery Method |
|-----|----------|
| Accidentally deleted cache | Auto-regenerate by running app |
| Configuration file damage | Time Machine restore |
| System instability | Safe Mode boot and inspection |
| App data loss | Time Machine or iCloud restore |

---

## 7. Success Metrics (KPIs)

### 7.1 User-Facing Metrics

| Metric | Target | Measurement Method |
|-----|------|----------|
| Average space freed | ≥ 15GB (Light), ≥ 40GB (Deep) | Before/after comparison |
| Cleanup completion time | < 2min (Light), < 5min (Deep) | Execution time measurement |
| System stability | 0 system issues | Error reports |
| User satisfaction | ≥ 4.5/5.0 | App reviews/surveys |

### 7.2 Technical Metrics

| Metric | Target | Measurement Method |
|-----|------|----------|
| False Positive Rate | < 0.1% | Incorrect deletion reports |
| Cleanup success rate | > 99% | Error log analysis |
| Memory usage | < 100MB | Profiling |
| Battery impact | Negligible | Energy Impact measurement |

### 7.3 Business Metrics

| Metric | Target | Measurement Method |
|-----|------|----------|
| Weekly Active Users | 10K+ | Usage statistics |
| Retention (30 days) | > 40% | Reuse rate |
| Automation usage rate | > 30% | Schedule configuration ratio |

---

## 8. Roadmap

### Phase 1: Foundation (MVP)
**Timeline**: 4 weeks

- [ ] Core cleanup engine (Level 1-3)
- [ ] Safety validation system
- [ ] CLI interface
- [ ] Basic disk analysis
- [ ] macOS 11-15 compatibility

**Deliverables**:
- `osxcleaner` CLI tool
- User documentation

### Phase 2: Enhancement
**Timeline**: 6 weeks

- [ ] Interactive menu UI
- [ ] launchd automation integration
- [ ] Disk monitoring + notifications
- [ ] Deep developer tool support
- [ ] Configuration file system

**Deliverables**:
- Enhanced CLI
- Automation scripts

### Phase 3: Professional
**Timeline**: 8 weeks

- [ ] GUI app (SwiftUI)
- [ ] CI/CD integration (GitHub Actions, Jenkins, Fastlane)
- [ ] Team environment support
- [ ] Remote monitoring (Prometheus metrics)
- [ ] Multi-language support (Korean, English, Japanese)

**Deliverables**:
- macOS app (.app)
- CI/CD plugins

### Phase 4: Enterprise
**Timeline**: TBD

- [ ] Central management console
- [ ] Policy-based management
- [ ] Audit logging and reporting
- [ ] MDM integration

---

## 9. Appendix

### A. Glossary

| Term | Description |
|-----|------|
| DerivedData | Xcode build intermediate file storage |
| Device Support | iOS device debugging symbols |
| APFS | Apple File System (High Sierra+) |
| SIP | System Integrity Protection |
| launchd | macOS service management daemon |

### B. Reference Documents

- [01-temporary-files.md](reference/01-temporary-files.md) - Temporary file locations
- [02-cache-system.md](reference/02-cache-system.md) - Cache system
- [03-system-logs.md](reference/03-system-logs.md) - System logs
- [04-version-differences.md](reference/04-version-differences.md) - Version differences
- [05-developer-caches.md](reference/05-developer-caches.md) - Developer caches
- [06-safe-cleanup-guide.md](reference/06-safe-cleanup-guide.md) - Safe cleanup guide
- [07-developer-guide.md](reference/07-developer-guide.md) - Developer guide
- [08-automation-scripts.md](reference/08-automation-scripts.md) - Automation scripts
- [09-ci-cd-team-guide.md](reference/09-ci-cd-team-guide.md) - CI/CD guide

### C. Competitive Analysis

| Competitor | Strengths | Weaknesses | OSX Cleaner Differentiator |
|----------|------|------|-------------------|
| CleanMyMac X | Excellent GUI, multi-functional | Paid ($39/year), overly aggressive | Free, safety-first |
| OnyX | Free, system tools | Complex, no developer tool support | Developer-focused |
| DevCleaner | Xcode specialist | Xcode only | Full development stack support |
| Manual cleanup | Free, complete control | Time-consuming, risky | Automation, safety |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1.0.0 | 2025-12-25 | - | Initial PRD based on reference documents |
| 0.1.0.0 (English) | 2025-12-25 | - | English translation of Korean PRD |

---

*This document was created based on analysis of 9 reference documents in the osx_cleaner/docs/reference/ directory.*
