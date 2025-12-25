# macOS CI/CD & Team Environment Guide

> Last Updated: 2025-12-25

## Overview

Managing macOS build machines in CI/CD and team development environments requires a different approach than personal environments. This guide provides strategies for managing build servers, shared Macs, and team workstations.

## CI/CD Environment Considerations

### Build Machine vs Development Machine

| Item | Development Machine | CI/CD Build Machine |
|-----|----------|----------------|
| Cache Policy | Maintain for speed | Periodic cleanup required |
| Disk Monitoring | Manual/Periodic | Automated/Real-time |
| Cleanup Timing | After work hours | Between builds or scheduled |
| Priority | Personal convenience | Build stability |

---

## CI/CD Pipeline Integration

### GitHub Actions (Self-hosted macOS Runner)

```yaml
# .github/workflows/ios-build.yml
name: iOS Build

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: self-hosted-macos

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Pre-build Cleanup
        run: |
          # Clean Derived Data (previous build artifacts)
          rm -rf ~/Library/Developer/Xcode/DerivedData/${{ github.repository }}* 2>/dev/null || true

          # Check disk space
          FREE_SPACE=$(df -h / | awk 'NR==2 {print $4}' | tr -d 'Gi')
          echo "Available space: ${FREE_SPACE}GB"

          if [ "${FREE_SPACE%.*}" -lt 20 ]; then
            echo "::warning::Low disk space! Running emergency cleanup..."
            rm -rf ~/Library/Developer/Xcode/DerivedData/*
            xcrun simctl delete unavailable
          fi

      - name: Build
        run: |
          xcodebuild -project MyApp.xcodeproj \
                     -scheme MyApp \
                     -destination 'platform=iOS Simulator,name=iPhone 15' \
                     clean build

      - name: Post-build Cleanup
        if: always()
        run: |
          # Clean build artifacts (after saving artifacts)
          rm -rf build/
          rm -rf DerivedData/
```

### Jenkins Pipeline

```groovy
// Jenkinsfile
pipeline {
    agent { label 'macos' }

    environment {
        DEVELOPER_DIR = '/Applications/Xcode.app/Contents/Developer'
    }

    stages {
        stage('Pre-cleanup') {
            steps {
                script {
                    // Check disk space
                    def freeSpace = sh(
                        script: "df -g / | awk 'NR==2 {print \$4}'",
                        returnStdout: true
                    ).trim().toInteger()

                    if (freeSpace < 30) {
                        echo "Warning: Low disk space (${freeSpace}GB). Running cleanup..."
                        sh '''
                            rm -rf ~/Library/Developer/Xcode/DerivedData/*
                            xcrun simctl delete unavailable || true
                            rm -rf ~/.gradle/caches/* || true
                        '''
                    }
                }
            }
        }

        stage('Build') {
            steps {
                sh '''
                    xcodebuild -project MyApp.xcodeproj \
                               -scheme MyApp \
                               -configuration Release \
                               clean build
                '''
            }
        }

        stage('Test') {
            steps {
                sh '''
                    xcodebuild test \
                               -project MyApp.xcodeproj \
                               -scheme MyApp \
                               -destination 'platform=iOS Simulator,name=iPhone 15'
                '''
            }
        }
    }

    post {
        always {
            // Post-build cleanup
            sh '''
                rm -rf build/
                rm -rf ~/Library/Developer/Xcode/DerivedData/${JOB_NAME}* || true
            '''

            // Weekly deep cleanup (Sundays only)
            script {
                def dayOfWeek = new Date().format('u')
                if (dayOfWeek == '7') {
                    sh '''
                        echo "Running weekly deep cleanup..."
                        rm -rf ~/Library/Developer/Xcode/DerivedData/*
                        xcrun simctl delete unavailable
                        brew cleanup -s || true
                    '''
                }
            }
        }
    }
}
```

### Fastlane Integration

```ruby
# Fastfile
default_platform(:ios)

platform :ios do
  before_all do
    # Check space before build
    free_space = `df -g / | awk 'NR==2 {print $4}'`.strip.to_i
    if free_space < 20
      UI.important("Low disk space: #{free_space}GB. Running cleanup...")
      cleanup_build_artifacts
    end
  end

  lane :build do
    gym(
      scheme: "MyApp",
      clean: true,
      output_directory: "./build"
    )
  end

  lane :test do
    scan(
      scheme: "MyApp",
      clean: true,
      result_bundle: true
    )
  end

  after_all do |lane|
    # Post-build cleanup
    cleanup_build_artifacts
  end

  error do |lane, exception|
    # Cleanup even on error
    cleanup_build_artifacts
  end

  private_lane :cleanup_build_artifacts do
    sh("rm -rf ../build/")
    sh("rm -rf ~/Library/Developer/Xcode/DerivedData/MyApp-* 2>/dev/null || true")

    # Clean old archives
    sh("find ~/Library/Developer/Xcode/Archives -mtime +30 -type d -name '*.xcarchive' -exec rm -rf {} \\; 2>/dev/null || true")
  end

  lane :deep_cleanup do
    # Deep cleanup (manual or scheduled)
    sh("rm -rf ~/Library/Developer/Xcode/DerivedData/*")
    sh("xcrun simctl delete unavailable")
    sh("pod cache clean --all")
    sh("rm -rf ~/Library/Caches/org.swift.swiftpm/*")

    UI.success("Deep cleanup completed!")
    sh("df -h /")
  end
end
```

---

## Build Machine Maintenance

### Automated Maintenance Script

```bash
#!/bin/bash
# ci_maintenance.sh
# Maintenance script for CI build machines

LOG_FILE="/var/log/ci_maintenance.log"
ALERT_THRESHOLD=85  # Alert at 85% usage

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_disk_space() {
    usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    free=$(df -h / | awk 'NR==2 {print $4}')
    log "Disk usage: ${usage}% (Free: ${free})"

    if [ "$usage" -ge "$ALERT_THRESHOLD" ]; then
        log "WARNING: Disk usage above ${ALERT_THRESHOLD}%!"
        return 1
    fi
    return 0
}

cleanup_xcode() {
    log "Cleaning Xcode caches..."

    # Derived Data
    before=$(du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null | cut -f1)
    rm -rf ~/Library/Developer/Xcode/DerivedData/*
    log "Derived Data cleaned (was: $before)"

    # Module Cache
    rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/*

    # Unavailable Simulators
    xcrun simctl delete unavailable 2>/dev/null
    log "Unavailable simulators deleted"

    # Old Archives (30 days+)
    find ~/Library/Developer/Xcode/Archives -mtime +30 -type d -name "*.xcarchive" -exec rm -rf {} \; 2>/dev/null
    log "Old archives cleaned"

    # Device Logs
    rm -rf ~/Library/Developer/Xcode/iOS\ Device\ Logs/* 2>/dev/null
}

cleanup_package_managers() {
    log "Cleaning package manager caches..."

    # CocoaPods
    if command -v pod &> /dev/null; then
        pod cache clean --all 2>/dev/null
        log "CocoaPods cache cleaned"
    fi

    # SPM
    rm -rf ~/Library/Caches/org.swift.swiftpm/*
    log "SPM cache cleaned"

    # Carthage (if used)
    rm -rf ~/Library/Caches/org.carthage.CarthageKit/* 2>/dev/null

    # npm
    if command -v npm &> /dev/null; then
        npm cache clean --force 2>/dev/null
        log "npm cache cleaned"
    fi

    # Homebrew
    if command -v brew &> /dev/null; then
        brew cleanup -s 2>/dev/null
        log "Homebrew cleaned"
    fi
}

cleanup_logs() {
    log "Cleaning old logs..."

    # System logs (30 days+)
    find ~/Library/Logs -mtime +30 -type f -delete 2>/dev/null

    # Crash reports (30 days+)
    find ~/Library/Logs/DiagnosticReports -mtime +30 -type f -delete 2>/dev/null

    # Build logs
    find ~/Library/Developer/Xcode/DerivedData -name "*.log" -mtime +7 -delete 2>/dev/null
}

cleanup_docker() {
    if command -v docker &> /dev/null; then
        log "Cleaning Docker..."
        docker system prune -f 2>/dev/null
        log "Docker cleaned"
    fi
}

send_alert() {
    local message="$1"

    # Slack webhook (environment variable required)
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
             --data "{\"text\":\"⚠️ CI Machine Alert: ${message}\"}" \
             "$SLACK_WEBHOOK_URL"
    fi

    # Email (mailx configuration required)
    # echo "$message" | mailx -s "CI Machine Alert" admin@company.com
}

# Main execution
log "=== CI Maintenance Started ==="

# Check disk and clean
if ! check_disk_space; then
    send_alert "Low disk space detected. Running cleanup..."
    cleanup_xcode
    cleanup_package_managers
    cleanup_logs
    cleanup_docker
fi

# Check again after cleanup
if ! check_disk_space; then
    send_alert "Disk space still critical after cleanup!"
fi

log "=== CI Maintenance Completed ==="
log "Final disk status: $(df -h / | awk 'NR==2 {print $5}') used"
```

### Cron/launchd Schedule Configuration

```bash
# crontab configuration (for build machine)
# crontab -e

# Daily maintenance at 2 AM
0 2 * * * /path/to/ci_maintenance.sh

# Simple cleanup after each build (called from Jenkins etc.)
# (Recommended to call directly from pipeline)

# Weekly deep cleanup on Sundays
0 3 * * 0 /path/to/deep_cleanup.sh
```

---

## Team Development Environment

### Team Mac Standard Setup

```bash
#!/bin/bash
# team_mac_setup.sh
# Standard setup for new team member Mac

echo "=== Team Mac Setup ==="

# 1. Basic development tools
echo "Installing development tools..."
xcode-select --install 2>/dev/null || true

# Homebrew
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Essential tools
brew install git node python cocoapods

# 2. Install cleanup scripts
echo "Installing cleanup scripts..."
mkdir -p ~/Scripts
cat > ~/Scripts/weekly_cleanup.sh << 'EOF'
#!/bin/bash
rm -rf ~/Library/Developer/Xcode/DerivedData/*
npm cache clean --force 2>/dev/null
yarn cache clean 2>/dev/null
brew cleanup -s 2>/dev/null
echo "Weekly cleanup done: $(df -h / | awk 'NR==2 {print $4}') free"
EOF
chmod +x ~/Scripts/weekly_cleanup.sh

# 3. Git hook template
echo "Setting up Git hooks..."
mkdir -p ~/.git-templates/hooks
cat > ~/.git-templates/hooks/post-checkout << 'EOF'
#!/bin/bash
# Clean cache on branch change
rm -rf node_modules/.cache 2>/dev/null
rm -rf .next/cache 2>/dev/null
EOF
chmod +x ~/.git-templates/hooks/post-checkout
git config --global init.templateDir ~/.git-templates

# 4. Disk monitoring setup
echo "Setting up disk monitoring..."
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.team.disk-monitor.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.team.disk-monitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>
            usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%');
            if [ "$usage" -ge 85 ]; then
                osascript -e 'display notification "Disk usage '$usage'%" with title "Disk Space Warning"';
            fi
        </string>
    </array>
    <key>StartInterval</key>
    <integer>3600</integer>
</dict>
</plist>
EOF
launchctl load ~/Library/LaunchAgents/com.team.disk-monitor.plist

echo "=== Setup Complete ==="
```

### Shared Cleanup Policy

```markdown
# Team macOS Cleanup Policy

## Individual Responsibilities
- Every Friday: Run weekly cleanup script
- Last week of month: Archive old projects
- When disk exceeds 85%: Clean immediately

## Prohibited Actions
- Arbitrary deletion of ~/Library/Application Support
- System folder modifications
- Deleting other users' files (on shared machines)

## Recommended Tools
- DevCleaner for Xcode
- npkill (node_modules cleanup)
- DaisyDisk (disk analysis)

## Emergency Situations
When disk usage exceeds 95%:
1. Alert on Slack #dev-support
2. Empty trash immediately
3. Delete Xcode Derived Data
4. Clean Docker (if applicable)
```

---

## Monitoring & Alerting

### Prometheus + Grafana Metrics

```bash
#!/bin/bash
# node_exporter textfile collector
# /var/lib/node_exporter/textfile_collector/disk_cleanup.prom

# Disk usage
disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
echo "macos_disk_usage_percent ${disk_usage}"

# Xcode cache size (GB)
xcode_cache=$(du -sg ~/Library/Developer/Xcode 2>/dev/null | cut -f1)
echo "macos_xcode_cache_gb ${xcode_cache:-0}"

# Docker usage (bytes)
if command -v docker &> /dev/null; then
    docker_size=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1 | numfmt --from=iec)
    echo "macos_docker_usage_bytes ${docker_size:-0}"
fi

# Last cleanup time (Unix timestamp)
if [ -f /var/log/ci_maintenance.log ]; then
    last_cleanup=$(stat -f %m /var/log/ci_maintenance.log)
    echo "macos_last_cleanup_timestamp ${last_cleanup}"
fi
```

### Slack Alert Bot

```python
#!/usr/bin/env python3
# disk_alert_bot.py

import subprocess
import requests
import os

SLACK_WEBHOOK = os.environ.get('SLACK_WEBHOOK_URL')
THRESHOLD = 85

def get_disk_usage():
    result = subprocess.run(
        ["df", "-h", "/"],
        capture_output=True,
        text=True
    )
    lines = result.stdout.strip().split('\n')
    if len(lines) >= 2:
        parts = lines[1].split()
        usage = int(parts[4].rstrip('%'))
        free = parts[3]
        return usage, free
    return 0, "unknown"

def send_slack_alert(message):
    if SLACK_WEBHOOK:
        requests.post(SLACK_WEBHOOK, json={
            "text": message,
            "icon_emoji": ":warning:",
            "username": "Disk Monitor"
        })

def main():
    usage, free = get_disk_usage()
    hostname = subprocess.run(["hostname"], capture_output=True, text=True).stdout.strip()

    if usage >= THRESHOLD:
        message = f"⚠️ *{hostname}*: Disk usage {usage}% (Free: {free})\nCleanup required!"
        send_slack_alert(message)
        print(f"Alert sent: {usage}%")
    else:
        print(f"Disk usage OK: {usage}%")

if __name__ == "__main__":
    main()
```

---

## Best Practices for Teams

### Build Machine Management

1. **Use Dedicated Account**: Build-specific user account
2. **Regular Maintenance Window**: Deep cleanup at scheduled time weekly
3. **Monitoring Required**: Real-time disk usage monitoring
4. **Documentation**: Document all configurations and scripts

### Team Development Environment

1. **Standardization**: All team members use same cleanup tools
2. **Automation**: Minimize manual tasks
3. **Training**: Include cleanup policy in new member onboarding
4. **Review**: Quarterly review of cleanup policies

### Cost Optimization

| Strategy | Effect | Implementation Complexity |
|-----|------|-----------|
| Automatic cache cleanup | Disk cost savings | Low |
| Smart caching | Reduced build time | Medium |
| Remote cache | Network utilization | High |
| Build machine scaling | Resource efficiency | High |

---

## Troubleshooting

### CI Build Failure: Out of Disk Space

```bash
# Immediate cleanup
rm -rf ~/Library/Developer/Xcode/DerivedData/*
xcrun simctl shutdown all
xcrun simctl delete unavailable
docker system prune -af

# Retry
# (Re-run build)
```

### Increased Build Time

Issues from excessive cache cleanup:
- Selective Derived Data cleanup (per project)
- Maintain SPM cache
- Maintain CocoaPods cache

```bash
# Clean only project-specific Derived Data
rm -rf ~/Library/Developer/Xcode/DerivedData/ProjectName-*
```

### Shared Machine Conflicts

```bash
# Separate cache per user
export TMPDIR="/tmp/$(whoami)"
mkdir -p "$TMPDIR"

# Check for other builds before building
pgrep -l xcodebuild
```

---

## References

- [GitHub Actions - Self-hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Jenkins - macOS Agents](https://www.jenkins.io/doc/book/installing/macos/)
- [Fastlane Documentation](https://docs.fastlane.tools/)
- [07-developer-guide.md](07-developer-guide.md)
- [08-automation-scripts.md](08-automation-scripts.md)
