# macOS Cleanup Automation Scripts

> Last Updated: 2025-12-25

## Overview

This document is a collection of scripts for automating macOS cleanup tasks. It covers various scenarios from one-time cleanup to regular maintenance.

## Script Collection

### 1. Master Cleanup Script

A master script that integrates all cleanup tasks

```bash
#!/bin/bash
# master_cleanup.sh
# macOS Integrated Cleanup Script

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Free space check function
get_free_space() {
    df -h / | awk 'NR==2 {print $4}'
}

# Start banner
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              macOS Master Cleanup Script                      ║"
echo "║                   Version 0.1.0.0                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Start time: $(date)"
echo "Initial free space: $(get_free_space)"
echo ""

# Cleanup level selection
echo "Select cleanup level:"
echo "  1) Light   - Trash and browser cache only"
echo "  2) Normal  - Above + user cache, old logs"
echo "  3) Deep    - Above + developer cache (Xcode, npm, etc.)"
echo "  4) Custom  - Select items individually"
read -p "Choose (1-4): " level

case $level in
    1) cleanup_level="light" ;;
    2) cleanup_level="normal" ;;
    3) cleanup_level="deep" ;;
    4) cleanup_level="custom" ;;
    *) log_error "Invalid selection"; exit 1 ;;
esac

# ========== Light Cleanup ==========
light_cleanup() {
    log_info "Starting light cleanup..."

    # Trash
    log_info "Emptying trash..."
    rm -rf ~/.Trash/* 2>/dev/null
    log_success "Trash emptied"

    # Browser cache
    log_info "Cleaning browser cache..."
    rm -rf ~/Library/Caches/com.apple.Safari/WebKitCache/* 2>/dev/null
    rm -rf ~/Library/Caches/Google/Chrome/Default/Cache/* 2>/dev/null
    rm -rf ~/Library/Caches/Firefox/Profiles/*/cache2/* 2>/dev/null
    rm -rf ~/Library/Caches/com.microsoft.Edge/Default/Cache/* 2>/dev/null
    log_success "Browser cache cleaned"
}

# ========== Normal Cleanup ==========
normal_cleanup() {
    light_cleanup

    log_info "Additional normal cleanup tasks..."

    # User cache (major apps)
    log_info "Cleaning app cache..."
    rm -rf ~/Library/Caches/com.spotify.client/* 2>/dev/null
    rm -rf ~/Library/Caches/com.tinyspeck.slackmacgap/* 2>/dev/null
    rm -rf ~/Library/Caches/com.hnc.Discord/* 2>/dev/null
    log_success "App cache cleaned"

    # Old logs (30+ days)
    log_info "Cleaning old logs..."
    find ~/Library/Logs -mtime +30 -type f -delete 2>/dev/null
    log_success "Old logs cleaned"

    # Crash reports (30+ days)
    log_info "Cleaning old crash reports..."
    find ~/Library/Logs/DiagnosticReports -mtime +30 -type f -delete 2>/dev/null
    log_success "Crash reports cleaned"

    # Old files in Downloads folder (90+ days)
    log_info "Cleaning old download files..."
    find ~/Downloads -mtime +90 -type f -delete 2>/dev/null
    log_success "Downloads folder cleaned"
}

# ========== Deep Cleanup ==========
deep_cleanup() {
    normal_cleanup

    log_info "Additional deep cleanup tasks..."

    # Xcode (if exists)
    if [ -d ~/Library/Developer/Xcode ]; then
        log_info "Cleaning Xcode cache..."
        rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null
        rm -rf ~/Library/Developer/Xcode/Archives/*/*/dSYMs/* 2>/dev/null
        xcrun simctl delete unavailable 2>/dev/null || true
        log_success "Xcode cleaned"
    fi

    # npm
    if command -v npm &> /dev/null; then
        log_info "Cleaning npm cache..."
        npm cache clean --force 2>/dev/null
        log_success "npm cache cleaned"
    fi

    # yarn
    if command -v yarn &> /dev/null; then
        log_info "Cleaning yarn cache..."
        yarn cache clean 2>/dev/null
        log_success "yarn cache cleaned"
    fi

    # pip
    if command -v pip3 &> /dev/null; then
        log_info "Cleaning pip cache..."
        pip3 cache purge 2>/dev/null
        log_success "pip cache cleaned"
    fi

    # Homebrew
    if command -v brew &> /dev/null; then
        log_info "Cleaning Homebrew..."
        brew cleanup -s 2>/dev/null
        log_success "Homebrew cleaned"
    fi

    # Docker
    if command -v docker &> /dev/null; then
        log_info "Cleaning Docker..."
        docker system prune -f 2>/dev/null || true
        log_success "Docker cleaned"
    fi

    # CocoaPods
    if command -v pod &> /dev/null; then
        log_info "Cleaning CocoaPods cache..."
        pod cache clean --all 2>/dev/null
        log_success "CocoaPods cleaned"
    fi

    # SPM
    log_info "Cleaning Swift Package Manager cache..."
    rm -rf ~/Library/Caches/org.swift.swiftpm/* 2>/dev/null
    log_success "SPM cleaned"

    # Gradle
    if [ -d ~/.gradle ]; then
        log_info "Cleaning Gradle cache..."
        rm -rf ~/.gradle/caches/* 2>/dev/null
        log_success "Gradle cleaned"
    fi

    # JetBrains
    if [ -d ~/Library/Caches/JetBrains ]; then
        log_info "Cleaning JetBrains cache..."
        rm -rf ~/Library/Caches/JetBrains/* 2>/dev/null
        log_success "JetBrains cleaned"
    fi

    # VS Code
    if [ -d ~/Library/Application\ Support/Code ]; then
        log_info "Cleaning VS Code cache..."
        rm -rf ~/Library/Application\ Support/Code/Cache/* 2>/dev/null
        rm -rf ~/Library/Application\ Support/Code/CachedData/* 2>/dev/null
        log_success "VS Code cleaned"
    fi
}

# ========== Custom Cleanup ==========
custom_cleanup() {
    echo ""
    echo "Select items to clean (y/n):"

    read -p "  Trash? " trash
    read -p "  Browser cache? " browser
    read -p "  App cache? " app_cache
    read -p "  Old logs? " logs
    read -p "  Old downloads? " downloads
    read -p "  Xcode cache? " xcode
    read -p "  npm/yarn cache? " npm
    read -p "  Docker? " docker
    read -p "  Homebrew? " brew_clean

    [[ "$trash" == "y" ]] && rm -rf ~/.Trash/* 2>/dev/null && log_success "Trash emptied"
    [[ "$browser" == "y" ]] && {
        rm -rf ~/Library/Caches/com.apple.Safari/WebKitCache/* 2>/dev/null
        rm -rf ~/Library/Caches/Google/Chrome/Default/Cache/* 2>/dev/null
        log_success "Browser cache cleaned"
    }
    [[ "$app_cache" == "y" ]] && rm -rf ~/Library/Caches/* 2>/dev/null && log_success "App cache cleaned"
    [[ "$logs" == "y" ]] && find ~/Library/Logs -mtime +30 -delete 2>/dev/null && log_success "Logs cleaned"
    [[ "$downloads" == "y" ]] && find ~/Downloads -mtime +90 -delete 2>/dev/null && log_success "Downloads cleaned"
    [[ "$xcode" == "y" ]] && rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null && log_success "Xcode cleaned"
    [[ "$npm" == "y" ]] && {
        npm cache clean --force 2>/dev/null
        yarn cache clean 2>/dev/null
        log_success "npm/yarn cleaned"
    }
    [[ "$docker" == "y" ]] && docker system prune -f 2>/dev/null && log_success "Docker cleaned"
    [[ "$brew_clean" == "y" ]] && brew cleanup -s 2>/dev/null && log_success "Homebrew cleaned"
}

# Execute selected cleanup
case $cleanup_level in
    "light") light_cleanup ;;
    "normal") normal_cleanup ;;
    "deep") deep_cleanup ;;
    "custom") custom_cleanup ;;
esac

# Output results
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Completion time: $(date)"
echo "Final free space: $(get_free_space)"
echo "═══════════════════════════════════════════════════════════════"
```

---

### 2. Quick Cleanup (One-liner)

One-liners for quick cleanup

```bash
# Basic cleanup (trash + browser cache)
rm -rf ~/.Trash/* ~/Library/Caches/com.apple.Safari/WebKitCache/* ~/Library/Caches/Google/Chrome/Default/Cache/* 2>/dev/null && echo "Quick cleanup done: $(df -h / | awk 'NR==2 {print $4}') free"

# Developer quick cleanup
rm -rf ~/Library/Developer/Xcode/DerivedData/* && npm cache clean --force 2>/dev/null && brew cleanup -s 2>/dev/null && echo "Dev cleanup done"

# Emergency space recovery
rm -rf ~/.Trash/* ~/Library/Caches/* ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null && docker system prune -af 2>/dev/null; echo "Emergency cleanup done: $(df -h / | awk 'NR==2 {print $4}') free"
```

---

### 3. Scheduled Cleanup (launchd)

launchd configuration for scheduled execution

#### Daily Cleanup (Light)

```xml
<!-- ~/Library/LaunchAgents/com.user.daily-cleanup.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.daily-cleanup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>
            rm -rf ~/Library/Caches/com.apple.Safari/WebKitCache/* 2>/dev/null;
            find ~/Library/Logs -mtime +7 -type f -delete 2>/dev/null;
            echo "$(date): Daily cleanup completed" >> ~/Library/Logs/cleanup.log
        </string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/daily-cleanup.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/daily-cleanup.error.log</string>
</dict>
</plist>
```

#### Weekly Cleanup (Normal)

```xml
<!-- ~/Library/LaunchAgents/com.user.weekly-cleanup.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.weekly-cleanup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>
            # Browser cache
            rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null;
            rm -rf ~/Library/Caches/Google/Chrome/* 2>/dev/null;

            # Developer cache
            rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null;
            npm cache clean --force 2>/dev/null;
            brew cleanup -s 2>/dev/null;

            # Logs
            find ~/Library/Logs -mtime +30 -type f -delete 2>/dev/null;

            echo "$(date): Weekly cleanup completed" >> ~/Library/Logs/cleanup.log
        </string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer> <!-- Sunday -->
        <key>Hour</key>
        <integer>4</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
```

#### launchd Management Commands

```bash
# Load (activate)
launchctl load ~/Library/LaunchAgents/com.user.daily-cleanup.plist
launchctl load ~/Library/LaunchAgents/com.user.weekly-cleanup.plist

# Unload (deactivate)
launchctl unload ~/Library/LaunchAgents/com.user.daily-cleanup.plist

# Check status
launchctl list | grep cleanup

# Test immediate execution
launchctl start com.user.daily-cleanup

# Check all user-defined jobs
launchctl list | grep com.user
```

---

### 4. Disk Space Monitor

Disk space monitoring and alerts

```bash
#!/bin/bash
# disk_monitor.sh
# Alert when disk space is low

THRESHOLD=90  # Alert when usage exceeds 90%
LOG_FILE=~/Library/Logs/disk_monitor.log

# Check current usage
usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
free_space=$(df -h / | awk 'NR==2 {print $4}')

# Log record
echo "$(date): Disk usage: ${usage}%, Free: ${free_space}" >> "$LOG_FILE"

if [ "$usage" -ge "$THRESHOLD" ]; then
    # Display macOS notification
    osascript -e "display notification \"Disk usage: ${usage}% (Free: ${free_space})\" with title \"⚠️ Low Disk Space\" subtitle \"Cleanup required\""

    # Terminal alert (for background execution)
    echo "⚠️  Warning: Disk usage ${usage}% (Free: ${free_space})"

    # Auto basic cleanup (optional)
    # rm -rf ~/.Trash/* 2>/dev/null
    # rm -rf ~/Library/Caches/com.apple.Safari/WebKitCache/* 2>/dev/null
fi
```

```xml
<!-- ~/Library/LaunchAgents/com.user.disk-monitor.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.disk-monitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/disk_monitor.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>3600</integer> <!-- Every hour -->
</dict>
</plist>
```

---

### 5. Interactive Cleanup Menu

Interactive menu-based cleanup tool

```bash
#!/bin/bash
# interactive_cleanup.sh

show_menu() {
    clear
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           macOS Interactive Cleanup Tool                   ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║  Current disk status: $(df -h / | awk 'NR==2 {printf "%s used (%s free)", $3, $4}')       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  [1] 📊 Analyze disk usage"
    echo "  [2] 🗑️  Empty trash"
    echo "  [3] 🌐 Clean browser cache"
    echo "  [4] 📦 Clean app cache"
    echo "  [5] 📝 Clean log files"
    echo "  [6] 💻 Clean developer tools"
    echo "  [7] 🐳 Clean Docker"
    echo "  [8] 🍺 Clean Homebrew"
    echo "  [9] ⚡ Full quick cleanup"
    echo "  [0] 🚪 Exit"
    echo ""
}

disk_analysis() {
    echo ""
    echo "📊 Disk Usage Analysis"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "Main directories:"
    du -sh ~/* 2>/dev/null | sort -hr | head -10
    echo ""
    echo "Cache directories:"
    du -sh ~/Library/Caches 2>/dev/null
    du -sh ~/Library/Developer 2>/dev/null
    echo ""
    read -p "Press Enter to continue..."
}

empty_trash() {
    size=$(du -sh ~/.Trash 2>/dev/null | cut -f1)
    echo "Trash size: $size"
    read -p "Empty trash? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        rm -rf ~/.Trash/*
        echo "✓ Trash emptied."
    fi
    read -p "Press Enter to continue..."
}

clean_browser_cache() {
    echo ""
    echo "Browser cache:"
    du -sh ~/Library/Caches/com.apple.Safari 2>/dev/null | sed 's/^/  Safari: /'
    du -sh ~/Library/Caches/Google/Chrome 2>/dev/null | sed 's/^/  Chrome: /'
    du -sh ~/Library/Caches/Firefox 2>/dev/null | sed 's/^/  Firefox: /'
    echo ""
    read -p "Clean browser cache? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null
        rm -rf ~/Library/Caches/Google/Chrome/* 2>/dev/null
        rm -rf ~/Library/Caches/Firefox/Profiles/*/cache2/* 2>/dev/null
        echo "✓ Browser cache cleaned."
    fi
    read -p "Press Enter to continue..."
}

clean_app_cache() {
    size=$(du -sh ~/Library/Caches 2>/dev/null | cut -f1)
    echo "Total app cache size: $size"
    echo ""
    echo "Top 10 caches:"
    du -sh ~/Library/Caches/* 2>/dev/null | sort -hr | head -10
    echo ""
    read -p "Clean all app cache? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        rm -rf ~/Library/Caches/*
        echo "✓ App cache cleaned."
    fi
    read -p "Press Enter to continue..."
}

clean_logs() {
    size=$(du -sh ~/Library/Logs 2>/dev/null | cut -f1)
    echo "Total log file size: $size"
    read -p "Clean logs older than 30 days? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        find ~/Library/Logs -mtime +30 -type f -delete 2>/dev/null
        echo "✓ Old logs cleaned."
    fi
    read -p "Press Enter to continue..."
}

clean_developer() {
    echo ""
    echo "Developer tool cache:"
    du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null | sed 's/^/  Xcode Derived Data: /'
    du -sh ~/Library/Developer/CoreSimulator 2>/dev/null | sed 's/^/  Simulators: /'
    du -sh ~/.npm 2>/dev/null | sed 's/^/  npm: /'
    du -sh $(yarn cache dir 2>/dev/null) 2>/dev/null | sed 's/^/  yarn: /'
    du -sh ~/Library/Caches/org.swift.swiftpm 2>/dev/null | sed 's/^/  SPM: /'
    echo ""

    echo "Select items to clean:"
    echo "  [1] Xcode Derived Data"
    echo "  [2] Unavailable Simulators"
    echo "  [3] npm/yarn cache"
    echo "  [4] SPM cache"
    echo "  [5] All"
    echo "  [0] Cancel"
    read -p "Select: " choice

    case $choice in
        1) rm -rf ~/Library/Developer/Xcode/DerivedData/* ;;
        2) xcrun simctl delete unavailable 2>/dev/null ;;
        3) npm cache clean --force 2>/dev/null; yarn cache clean 2>/dev/null ;;
        4) rm -rf ~/Library/Caches/org.swift.swiftpm/* ;;
        5)
            rm -rf ~/Library/Developer/Xcode/DerivedData/*
            xcrun simctl delete unavailable 2>/dev/null
            npm cache clean --force 2>/dev/null
            yarn cache clean 2>/dev/null
            rm -rf ~/Library/Caches/org.swift.swiftpm/*
            ;;
    esac

    echo "✓ Developer tools cleanup completed"
    read -p "Press Enter to continue..."
}

clean_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed."
        read -p "Press Enter to continue..."
        return
    fi

    echo ""
    docker system df
    echo ""
    read -p "Clean Docker system? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        docker system prune -f
        echo "✓ Docker cleanup completed"
    fi
    read -p "Press Enter to continue..."
}

clean_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo "Homebrew is not installed."
        read -p "Press Enter to continue..."
        return
    fi

    cache_size=$(du -sh $(brew --cache) 2>/dev/null | cut -f1)
    echo "Homebrew cache size: $cache_size"
    read -p "Clean Homebrew? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        brew cleanup -s
        echo "✓ Homebrew cleanup completed"
    fi
    read -p "Press Enter to continue..."
}

quick_cleanup() {
    echo ""
    echo "⚡ Running quick cleanup..."
    rm -rf ~/.Trash/* 2>/dev/null && echo "✓ Trash"
    rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null && echo "✓ Safari cache"
    rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null && echo "✓ Xcode Derived Data"
    find ~/Library/Logs -mtime +30 -delete 2>/dev/null && echo "✓ Old logs"
    brew cleanup -s 2>/dev/null && echo "✓ Homebrew"
    echo ""
    echo "Final free space: $(df -h / | awk 'NR==2 {print $4}')"
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    show_menu
    read -p "Select: " option

    case $option in
        1) disk_analysis ;;
        2) empty_trash ;;
        3) clean_browser_cache ;;
        4) clean_app_cache ;;
        5) clean_logs ;;
        6) clean_developer ;;
        7) clean_docker ;;
        8) clean_homebrew ;;
        9) quick_cleanup ;;
        0) echo "Exiting."; exit 0 ;;
        *) echo "Invalid selection." ;;
    esac
done
```

---

### 6. Pre-commit Cleanup Hook

Automatic cleanup before Git commit

```bash
#!/bin/bash
# .git/hooks/pre-commit
# Clean build cache before commit

# Find project root
ROOT=$(git rev-parse --show-toplevel)

# Node.js projects
if [ -f "$ROOT/package.json" ]; then
    # Clean .cache
    find "$ROOT" -type d -name ".cache" -not -path "*/node_modules/*" -exec rm -rf {} + 2>/dev/null

    # .next cache (Next.js)
    rm -rf "$ROOT/.next/cache" 2>/dev/null

    # .parcel-cache
    rm -rf "$ROOT/.parcel-cache" 2>/dev/null
fi

# Swift projects
if [ -f "$ROOT/Package.swift" ] || [ -d "$ROOT/*.xcodeproj" ]; then
    # Clean .build (SPM)
    rm -rf "$ROOT/.build" 2>/dev/null
fi

exit 0
```

---

## Installation Guide

### Script Installation

```bash
# Create directory
mkdir -p ~/Scripts/cleanup

# Download/copy scripts
# (Save the scripts above)

# Grant execution permissions
chmod +x ~/Scripts/cleanup/*.sh

# Add to PATH (optional)
echo 'export PATH="$HOME/Scripts/cleanup:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### launchd Setup

```bash
# Copy plist files
cp *.plist ~/Library/LaunchAgents/

# Load
launchctl load ~/Library/LaunchAgents/com.user.daily-cleanup.plist
launchctl load ~/Library/LaunchAgents/com.user.weekly-cleanup.plist
launchctl load ~/Library/LaunchAgents/com.user.disk-monitor.plist
```

---

## Best Practices

### When Writing Scripts

1. **Error Handling**: Hide errors with `2>/dev/null`
2. **Existence Check**: Verify commands/directories exist before execution
3. **Logging**: Keep records of operations
4. **Notifications**: Alert on important task completion

### When Automating

1. **Time Selection**: Choose non-usage hours (early morning)
2. **Gradual Cleanup**: Don't clean everything at once
3. **Backup Verification**: Clean after backing up important data
4. **Testing**: Test manual execution before automation

---

## References

- [07-developer-guide.md](07-developer-guide.md) - Developer Guide
- [06-safe-cleanup-guide.md](06-safe-cleanup-guide.md) - Safe Cleanup Guide
- [Apple - launchd Documentation](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
