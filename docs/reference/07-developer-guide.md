# macOS Developer Cleanup Guide

> Last Updated: 2025-12-25
> Target Audience: iOS, macOS, Web, Backend Developers

## Overview

A developer's Mac consumes disk space much faster than a typical user's system. Xcode alone can use over 100GB, and when Docker, npm, virtual environments, and other tools are added, the usage increases dramatically. This guide provides methods to efficiently manage space while maintaining development productivity.

## Developer Space Usage Profile

### Typical Developer Mac Space Usage

```
┌─────────────────────────────────────────────────────────────┐
│                    Developer Mac (512GB)                     │
├─────────────────────────────────────────────────────────────┤
│ macOS System          ████░░░░░░░░░░░░░░░░  15GB (3%)       │
│ User Data             ████████░░░░░░░░░░░░  50GB (10%)      │
│ Xcode + Simulators    ██████████████░░░░░░  80GB (16%)      │
│ Development Projects  ████████░░░░░░░░░░░░  50GB (10%)      │
│ Docker                ██████░░░░░░░░░░░░░░  30GB (6%)       │
│ node_modules (total)  ████░░░░░░░░░░░░░░░░  20GB (4%)       │
│ Virtual Envs          ██░░░░░░░░░░░░░░░░░░  10GB (2%)       │
│ Various Caches        ████████░░░░░░░░░░░░  50GB (10%)      │
│ FREE                  ████████████████████  207GB (40%)     │
└─────────────────────────────────────────────────────────────┘
```

### Space Consumption by Development Stack

| Stack | Main Consumption Items | Estimated Size |
|-----|--------------|----------|
| **iOS/macOS** | Xcode, Simulators, Device Support | 50-150GB |
| **Web Frontend** | node_modules, build caches | 10-50GB |
| **Backend** | Docker, virtual environments, DB | 20-100GB |
| **Mobile (Cross)** | Flutter/RN + above items | 30-80GB |
| **ML/Data** | Python environments, datasets, models | 50-200GB |

---

## Quick Cleanup by Developer Type

### iOS/macOS Developer

```bash
#!/bin/bash
# ios_developer_cleanup.sh

echo "🍎 iOS/macOS Developer Cleanup"
echo "=============================="

# 1. Xcode Derived Data (most effective)
echo "[1/6] Cleaning Derived Data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
echo "✓ Derived Data cleared"

# 2. Unavailable Simulators
echo "[2/6] Removing unavailable simulators..."
xcrun simctl delete unavailable 2>/dev/null
echo "✓ Unavailable simulators removed"

# 3. Old Simulator Runtimes
echo "[3/6] Checking simulator runtimes..."
xcrun simctl runtime list 2>/dev/null
echo "Manually delete unnecessary runtimes: xcrun simctl runtime delete [ID]"

# 4. CocoaPods Cache
echo "[4/6] Cleaning CocoaPods..."
pod cache clean --all 2>/dev/null || rm -rf ~/Library/Caches/CocoaPods/*
echo "✓ CocoaPods cache cleared"

# 5. SPM Cache
echo "[5/6] Cleaning Swift Package Manager..."
rm -rf ~/Library/Caches/org.swift.swiftpm/*
echo "✓ SPM cache cleared"

# 6. Module Cache
echo "[6/6] Cleaning Module Cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/*
echo "✓ Module cache cleared"

echo ""
echo "=== Additional Recommendations ==="
echo "• Clean iOS Device Support: ~/Library/Developer/Xcode/iOS DeviceSupport/"
echo "  (Manually delete old iOS version folders, ~4GB each)"
echo "• Clean Archives: Xcode → Window → Organizer → Archives"
echo ""
df -h / | tail -1
```

### Web Developer (Node.js/Frontend)

```bash
#!/bin/bash
# web_developer_cleanup.sh

echo "🌐 Web Developer Cleanup"
echo "========================"

# 1. Global npm cache
echo "[1/5] Cleaning npm cache..."
npm cache clean --force 2>/dev/null
echo "✓ npm cache cleared"

# 2. Yarn cache
echo "[2/5] Cleaning yarn cache..."
yarn cache clean 2>/dev/null
echo "✓ yarn cache cleared"

# 3. pnpm store cleanup
echo "[3/5] Cleaning pnpm store..."
pnpm store prune 2>/dev/null
echo "✓ pnpm store cleaned"

# 4. Find old node_modules
echo "[4/5] Finding old node_modules (not accessed in 30 days)..."
echo "Review the following directories:"
find ~ -name "node_modules" -type d -atime +30 2>/dev/null | head -20

# 5. Webpack/Vite cache
echo "[5/5] Cleaning build caches..."
find ~ -type d -name ".cache" -path "*/node_modules/*" -exec rm -rf {} \; 2>/dev/null
find ~ -type d -name ".parcel-cache" -exec rm -rf {} \; 2>/dev/null
echo "✓ Build caches cleared"

echo ""
echo "=== node_modules cleanup tools ==="
echo "• npkill: npm i -g npkill && npkill"
echo "• Manual deletion: rm -rf /path/to/project/node_modules"
echo ""
df -h / | tail -1
```

### Backend Developer (Python/Go/Java)

```bash
#!/bin/bash
# backend_developer_cleanup.sh

echo "⚙️ Backend Developer Cleanup"
echo "============================"

# 1. Python pip cache
echo "[1/6] Cleaning pip cache..."
pip cache purge 2>/dev/null
pip3 cache purge 2>/dev/null
echo "✓ pip cache cleared"

# 2. Conda cleanup
echo "[2/6] Cleaning conda..."
conda clean --all -y 2>/dev/null
echo "✓ conda cleaned"

# 3. Go module cache
echo "[3/6] Cleaning Go module cache..."
go clean -modcache 2>/dev/null
echo "✓ Go module cache cleared"

# 4. Gradle cache (Java/Kotlin)
echo "[4/6] Cleaning Gradle cache..."
rm -rf ~/.gradle/caches/*
echo "✓ Gradle cache cleared"

# 5. Maven cache (Java)
echo "[5/6] Cleaning Maven cache..."
rm -rf ~/.m2/repository/*
echo "✓ Maven cache cleared"

# 6. Docker
echo "[6/6] Cleaning Docker..."
docker system prune -f 2>/dev/null
echo "✓ Docker cleaned"

echo ""
echo "=== Additional Recommendations ==="
echo "• Clean virtual environments: pyenv versions, conda env list"
echo "• Docker volumes: docker volume prune"
echo "• Docker images: docker image prune -a"
echo ""
df -h / | tail -1
```

### Full-Stack / DevOps Developer

```bash
#!/bin/bash
# fullstack_cleanup.sh

echo "🚀 Full-Stack Developer Cleanup"
echo "================================"

# Clean all development environments
echo "Running comprehensive cleanup..."

# Node.js
npm cache clean --force 2>/dev/null
yarn cache clean 2>/dev/null

# Python
pip cache purge 2>/dev/null

# Go
go clean -modcache 2>/dev/null

# Rust
cargo cache -a 2>/dev/null || rm -rf ~/.cargo/registry/cache/*

# Docker (use with caution)
echo "Docker cleanup..."
docker system prune -f 2>/dev/null

# Homebrew
echo "Homebrew cleanup..."
brew cleanup -s 2>/dev/null

# IDE caches
echo "IDE cache cleanup..."
rm -rf ~/Library/Caches/JetBrains/* 2>/dev/null
rm -rf ~/Library/Application\ Support/Code/Cache/* 2>/dev/null

# General caches
rm -rf ~/Library/Caches/com.apple.dt.Xcode/* 2>/dev/null
rm -rf ~/Library/Caches/org.swift.swiftpm/* 2>/dev/null

echo ""
echo "=== Cleanup Complete ==="
df -h / | tail -1
```

---

## Development Environment Management

### Xcode Version Management

```bash
# Check installed Xcode versions
mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'"

# Or use xcode-select
xcode-select -p

# When using multiple Xcode versions
# /Applications/Xcode.app (current)
# /Applications/Xcode-15.app (previous)

# Reinstall Xcode Command Line Tools
xcode-select --install

# Switch to specific Xcode
sudo xcode-select -s /Applications/Xcode-15.app
```

### Efficient iOS Simulator Management

```bash
# Keep only necessary simulators
# Recommended: Latest 2 iOS versions + main devices

# List all simulators
xcrun simctl list devices

# Shutdown booted simulators
xcrun simctl shutdown all

# Delete specific simulator
xcrun simctl delete [UDID]

# Create simulator (if needed)
xcrun simctl create "iPhone 15 Pro" "iPhone 15 Pro" "iOS17.0"
```

### iOS Device Support Cleanup Strategy

```bash
# Check current Device Support size
du -sh ~/Library/Developer/Xcode/iOS\ DeviceSupport/*

# Recommended: Keep only recent 2 major versions
# Example: Keep only iOS 17.x, 18.x and delete 16.x and below

# Cleanup script
cd ~/Library/Developer/Xcode/iOS\ DeviceSupport/
# Check and manually delete old versions
ls -la | grep "15\." # iOS 15 related
ls -la | grep "16\." # iOS 16 related

# Delete (caution: will need re-download when connecting device with that iOS)
# rm -rf "15.0 (19A5261w)"
```

---

## node_modules Management

### node_modules Size Analysis

```bash
# node_modules size per project
find ~/Projects -name "node_modules" -type d -prune | while read dir; do
    size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    echo "$size    $dir"
done | sort -hr | head -20
```

### Using npkill (Recommended)

```bash
# Install
npm i -g npkill

# Run (interactive UI)
npkill

# Run in specific path
npkill --directory ~/Projects
```

### Automated node_modules Cleanup Script

```bash
#!/bin/bash
# cleanup_old_node_modules.sh

DAYS=30
PROJECTS_DIR=~/Projects

echo "Finding node_modules not accessed in $DAYS days..."

find "$PROJECTS_DIR" -name "node_modules" -type d -atime +$DAYS | while read dir; do
    size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    echo "[$size] $dir"
done

echo ""
read -p "Do you want to delete the above directories? (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
    find "$PROJECTS_DIR" -name "node_modules" -type d -atime +$DAYS -exec rm -rf {} \; 2>/dev/null
    echo "Deletion complete"
fi
```

---

## Docker Space Management

### Check Docker Space Usage

```bash
# Overall Docker usage
docker system df

# Detailed information
docker system df -v
```

### Docker Cleanup Strategy

```bash
#!/bin/bash
# docker_cleanup.sh

echo "🐳 Docker Cleanup"
echo "================="

# 1. Remove stopped containers
echo "[1/5] Removing stopped containers..."
docker container prune -f

# 2. Remove dangling images
echo "[2/5] Removing dangling images..."
docker image prune -f

# 3. Remove unused volumes
echo "[3/5] Removing unused volumes..."
docker volume prune -f

# 4. Remove unused networks
echo "[4/5] Removing unused networks..."
docker network prune -f

# 5. Remove build cache
echo "[5/5] Removing build cache..."
docker builder prune -f

echo ""
echo "=== Docker Status ==="
docker system df
```

### Docker Desktop Virtual Disk Reduction

Docker Desktop's virtual disk does not automatically shrink.

**Method 1: Docker Desktop Settings**
```
Docker Desktop → Settings → Resources → Advanced
→ Adjust Virtual disk limit
→ Apply & Restart
```

**Method 2: Recreate Virtual Disk**
```bash
# After shutting down Docker Desktop
rm ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw

# Restart Docker Desktop (new disk will be created)
```

---

## IDE Cache Management

### VS Code

```bash
# Cache locations
~/Library/Application Support/Code/Cache/
~/Library/Application Support/Code/CachedData/
~/Library/Application Support/Code/CachedExtensionVSIXs/
~/Library/Application Support/Code/CachedExtensions/

# Cleanup
rm -rf ~/Library/Application\ Support/Code/Cache/*
rm -rf ~/Library/Application\ Support/Code/CachedData/*

# Extension cleanup
code --list-extensions
code --uninstall-extension [extension-id]
```

### JetBrains IDEs (IntelliJ, PyCharm, WebStorm, etc.)

```bash
# Cache location
~/Library/Caches/JetBrains/

# Check size by IDE
du -sh ~/Library/Caches/JetBrains/*

# Clean all
rm -rf ~/Library/Caches/JetBrains/*

# Clean within IDE
# File → Invalidate Caches / Restart → Invalidate and Restart
```

### Xcode

```bash
# DerivedData (largest part)
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Previews (SwiftUI)
rm -rf ~/Library/Developer/Xcode/UserData/Previews/*

# Archives (optional)
# Xcode → Window → Organizer → Archives

# Device Logs
rm -rf ~/Library/Developer/Xcode/iOS\ Device\ Logs/*
```

---

## Automated Maintenance

### Auto Cleanup Using launchd

```xml
<!-- ~/Library/LaunchAgents/com.dev.cleanup.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dev.cleanup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>
            rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null;
            npm cache clean --force 2>/dev/null;
            brew cleanup -s 2>/dev/null;
        </string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer> <!-- Sunday -->
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
```

```bash
# Register
launchctl load ~/Library/LaunchAgents/com.dev.cleanup.plist

# Unregister
launchctl unload ~/Library/LaunchAgents/com.dev.cleanup.plist
```

### Project Cleanup Using Git Hooks

```bash
# .git/hooks/post-checkout
#!/bin/bash

# Clean build cache from previous branch
if [ -d "node_modules/.cache" ]; then
    rm -rf node_modules/.cache
fi

if [ -d ".next" ]; then
    rm -rf .next
fi

if [ -d "build" ]; then
    rm -rf build
fi
```

---

## Best Practices

### Daily Habits

- [ ] Shut down simulators after work
- [ ] Stop unused Docker containers
- [ ] Delete unnecessary branches after successful builds

### Weekly Routine

- [ ] Clean Derived Data (Xcode developers)
- [ ] `npm cache clean --force` or `yarn cache clean`
- [ ] `brew cleanup`
- [ ] Clean unused Docker images

### Monthly Maintenance

- [ ] Clean old node_modules folders
- [ ] Clean iOS Device Support (old versions)
- [ ] Clean virtual environments (pyenv, conda)
- [ ] Archive or delete old projects
- [ ] Check Time Machine local snapshots

### Quarterly Review

- [ ] Analyze overall disk usage
- [ ] Remove unused applications
- [ ] Clean development tool versions (Xcode, simulator runtimes)
- [ ] Verify backups

---

## Space Monitoring Dashboard

```bash
#!/bin/bash
# dev_space_dashboard.sh

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           Developer Space Usage Dashboard                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Overall disk
echo "📊 Disk Overview"
df -h / | tail -1 | awk '{print "   Used: "$3" / "$2" ("$5" full) | Free: "$4}'
echo ""

# Development-related directories
echo "💻 Development Directories"
echo "─────────────────────────────────────────────────────────────"

# Xcode
xcode_derived=$(du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null | cut -f1)
xcode_support=$(du -sh ~/Library/Developer/Xcode/iOS\ DeviceSupport 2>/dev/null | cut -f1)
xcode_archives=$(du -sh ~/Library/Developer/Xcode/Archives 2>/dev/null | cut -f1)
echo "   Xcode Derived Data:     ${xcode_derived:-0B}"
echo "   iOS Device Support:     ${xcode_support:-0B}"
echo "   Xcode Archives:         ${xcode_archives:-0B}"

# Simulators
simulators=$(du -sh ~/Library/Developer/CoreSimulator 2>/dev/null | cut -f1)
echo "   Simulators:             ${simulators:-0B}"

# Caches
user_caches=$(du -sh ~/Library/Caches 2>/dev/null | cut -f1)
echo "   User Caches:            ${user_caches:-0B}"

# Docker
if command -v docker &> /dev/null; then
    docker_size=$(docker system df --format "{{.Size}}" 2>/dev/null | head -1)
    echo "   Docker:                 ${docker_size:-N/A}"
fi

# Homebrew
homebrew_cache=$(du -sh $(brew --cache) 2>/dev/null | cut -f1)
echo "   Homebrew Cache:         ${homebrew_cache:-0B}"

echo ""
echo "📦 Package Manager Caches"
echo "─────────────────────────────────────────────────────────────"
npm_cache=$(du -sh ~/.npm 2>/dev/null | cut -f1)
yarn_cache=$(du -sh $(yarn cache dir 2>/dev/null) 2>/dev/null | cut -f1)
pip_cache=$(du -sh ~/Library/Caches/pip 2>/dev/null | cut -f1)
echo "   npm:                    ${npm_cache:-0B}"
echo "   yarn:                   ${yarn_cache:-0B}"
echo "   pip:                    ${pip_cache:-0B}"

echo ""
echo "═══════════════════════════════════════════════════════════════"
```

---

## Troubleshooting

### "Disk Full" Emergency Situations

```bash
# 1. Clean most impactful items first
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/.Trash/*

# 2. Docker cleanup (Docker users)
docker system prune -a -f

# 3. Simulator cleanup
xcrun simctl delete unavailable

# 4. Cache cleanup
rm -rf ~/Library/Caches/*
```

### Cleanup After Xcode Build Errors

```bash
# Clean for clean build
rm -rf ~/Library/Developer/Xcode/DerivedData/[ProjectName]*

# Full clean (when problem persists)
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Caches/com.apple.dt.Xcode/*
```

### npm/yarn Installation Errors

```bash
# If cache issue
npm cache clean --force
# or
yarn cache clean

# Reinstall node_modules
rm -rf node_modules package-lock.json
npm install
```

---

## References

- [05-developer-caches.md](05-developer-caches.md) - Detailed cache location information
- [06-safe-cleanup-guide.md](06-safe-cleanup-guide.md) - Safe cleanup guide
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Docker Documentation](https://docs.docker.com/config/pruning/)
