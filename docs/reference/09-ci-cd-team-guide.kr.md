# macOS CI/CD & Team Environment Guide

> Last Updated: 2025-12-25

## Overview

CI/CD 환경과 팀 개발 환경에서의 macOS 빌드 머신 관리는 개인 환경과 다른 접근이 필요합니다. 이 가이드는 빌드 서버, 공유 Mac, 팀 워크스테이션 관리를 위한 전략을 제공합니다.

## CI/CD Environment Considerations

### 빌드 머신 vs 개발 머신

| 항목 | 개발 머신 | CI/CD 빌드 머신 |
|-----|----------|----------------|
| 캐시 정책 | 유지하여 속도 향상 | 주기적 정리 필요 |
| 디스크 모니터링 | 수동/주기적 | 자동/실시간 |
| 정리 타이밍 | 업무 외 시간 | 빌드 간 또는 스케줄 |
| 중요도 | 개인 편의 | 빌드 안정성 |

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
          # Derived Data 정리 (이전 빌드 잔여물)
          rm -rf ~/Library/Developer/Xcode/DerivedData/${{ github.repository }}* 2>/dev/null || true

          # 디스크 공간 확인
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
          # 빌드 산출물 정리 (아티팩트 저장 후)
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
                    // 디스크 공간 체크
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
            // 빌드 후 정리
            sh '''
                rm -rf build/
                rm -rf ~/Library/Developer/Xcode/DerivedData/${JOB_NAME}* || true
            '''

            // 주간 심층 정리 (일요일에만)
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
    # 빌드 전 공간 확인
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
    # 빌드 후 정리
    cleanup_build_artifacts
  end

  error do |lane, exception|
    # 에러 발생 시에도 정리
    cleanup_build_artifacts
  end

  private_lane :cleanup_build_artifacts do
    sh("rm -rf ../build/")
    sh("rm -rf ~/Library/Developer/Xcode/DerivedData/MyApp-* 2>/dev/null || true")

    # 오래된 아카이브 정리
    sh("find ~/Library/Developer/Xcode/Archives -mtime +30 -type d -name '*.xcarchive' -exec rm -rf {} \\; 2>/dev/null || true")
  end

  lane :deep_cleanup do
    # 심층 정리 (수동 실행 또는 스케줄)
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

### 자동 유지보수 스크립트

```bash
#!/bin/bash
# ci_maintenance.sh
# CI 빌드 머신용 유지보수 스크립트

LOG_FILE="/var/log/ci_maintenance.log"
ALERT_THRESHOLD=85  # 85% 사용 시 알림

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

    # Slack webhook (환경변수 설정 필요)
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        curl -X POST -H 'Content-type: application/json' \
             --data "{\"text\":\"⚠️ CI Machine Alert: ${message}\"}" \
             "$SLACK_WEBHOOK_URL"
    fi

    # Email (mailx 설정 필요)
    # echo "$message" | mailx -s "CI Machine Alert" admin@company.com
}

# 메인 실행
log "=== CI Maintenance Started ==="

# 디스크 체크 및 정리
if ! check_disk_space; then
    send_alert "Low disk space detected. Running cleanup..."
    cleanup_xcode
    cleanup_package_managers
    cleanup_logs
    cleanup_docker
fi

# 정리 후 다시 체크
if ! check_disk_space; then
    send_alert "Disk space still critical after cleanup!"
fi

log "=== CI Maintenance Completed ==="
log "Final disk status: $(df -h / | awk 'NR==2 {print $5}') used"
```

### Cron/launchd 스케줄 설정

```bash
# crontab 설정 (빌드 머신용)
# crontab -e

# 매일 새벽 2시 유지보수
0 2 * * * /path/to/ci_maintenance.sh

# 매 빌드 후 간단 정리 (Jenkins 등에서 호출)
# (파이프라인에서 직접 호출 권장)

# 매주 일요일 심층 정리
0 3 * * 0 /path/to/deep_cleanup.sh
```

---

## Team Development Environment

### 팀 Mac 표준 설정

```bash
#!/bin/bash
# team_mac_setup.sh
# 새 팀원 Mac 표준 설정

echo "=== Team Mac Setup ==="

# 1. 기본 개발 도구
echo "Installing development tools..."
xcode-select --install 2>/dev/null || true

# Homebrew
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 필수 도구
brew install git node python cocoapods

# 2. 정리 스크립트 설치
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

# 3. Git 훅 템플릿
echo "Setting up Git hooks..."
mkdir -p ~/.git-templates/hooks
cat > ~/.git-templates/hooks/post-checkout << 'EOF'
#!/bin/bash
# 브랜치 변경 시 캐시 정리
rm -rf node_modules/.cache 2>/dev/null
rm -rf .next/cache 2>/dev/null
EOF
chmod +x ~/.git-templates/hooks/post-checkout
git config --global init.templateDir ~/.git-templates

# 4. 디스크 모니터링 설정
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
                osascript -e 'display notification "디스크 사용률 '$usage'%" with title "디스크 공간 경고"';
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

### 공유 정리 정책

```markdown
# 팀 macOS 정리 정책

## 개인 책임
- 매주 금요일: 주간 정리 스크립트 실행
- 매월 마지막 주: 오래된 프로젝트 아카이브
- 디스크 85% 이상 시: 즉시 정리

## 금지 사항
- ~/Library/Application Support 임의 삭제
- 시스템 폴더 수정
- 다른 사용자 파일 삭제 (공유 머신)

## 권장 도구
- DevCleaner for Xcode
- npkill (node_modules 정리)
- DaisyDisk (디스크 분석)

## 긴급 상황
디스크 95% 이상 사용 시:
1. Slack #dev-support 알림
2. 즉시 휴지통 비우기
3. Xcode Derived Data 삭제
4. Docker 정리 (해당 시)
```

---

## Monitoring & Alerting

### Prometheus + Grafana 메트릭

```bash
#!/bin/bash
# node_exporter textfile collector
# /var/lib/node_exporter/textfile_collector/disk_cleanup.prom

# 디스크 사용률
disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
echo "macos_disk_usage_percent ${disk_usage}"

# Xcode 캐시 크기 (GB)
xcode_cache=$(du -sg ~/Library/Developer/Xcode 2>/dev/null | cut -f1)
echo "macos_xcode_cache_gb ${xcode_cache:-0}"

# Docker 사용량 (bytes)
if command -v docker &> /dev/null; then
    docker_size=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1 | numfmt --from=iec)
    echo "macos_docker_usage_bytes ${docker_size:-0}"
fi

# 마지막 정리 시간 (Unix timestamp)
if [ -f /var/log/ci_maintenance.log ]; then
    last_cleanup=$(stat -f %m /var/log/ci_maintenance.log)
    echo "macos_last_cleanup_timestamp ${last_cleanup}"
fi
```

### Slack 알림 봇

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
        message = f"⚠️ *{hostname}*: 디스크 사용률 {usage}% (여유: {free})\n정리가 필요합니다!"
        send_slack_alert(message)
        print(f"Alert sent: {usage}%")
    else:
        print(f"Disk usage OK: {usage}%")

if __name__ == "__main__":
    main()
```

---

## Best Practices for Teams

### 빌드 머신 관리

1. **전용 계정 사용**: 빌드 전용 사용자 계정
2. **정기 유지보수 윈도우**: 매주 정해진 시간에 심층 정리
3. **모니터링 필수**: 디스크 사용률 실시간 모니터링
4. **문서화**: 모든 설정과 스크립트 문서화

### 팀 개발 환경

1. **표준화**: 모든 팀원 동일한 정리 도구 사용
2. **자동화**: 수동 작업 최소화
3. **교육**: 신규 팀원 온보딩에 정리 정책 포함
4. **리뷰**: 분기별 정리 정책 검토

### 비용 최적화

| 전략 | 효과 | 구현 복잡도 |
|-----|------|-----------|
| 자동 캐시 정리 | 디스크 비용 절감 | 낮음 |
| 스마트 캐싱 | 빌드 시간 단축 | 중간 |
| 원격 캐시 | 네트워크 활용 | 높음 |
| 빌드 머신 스케일링 | 자원 효율화 | 높음 |

---

## Troubleshooting

### CI 빌드 실패: 디스크 공간 부족

```bash
# 즉시 정리
rm -rf ~/Library/Developer/Xcode/DerivedData/*
xcrun simctl shutdown all
xcrun simctl delete unavailable
docker system prune -af

# 재시도
# (빌드 재실행)
```

### 빌드 시간 증가

캐시 과도한 정리로 인한 문제:
- Derived Data 선택적 정리 (프로젝트별)
- SPM 캐시 유지
- CocoaPods 캐시 유지

```bash
# 프로젝트별 Derived Data만 정리
rm -rf ~/Library/Developer/Xcode/DerivedData/ProjectName-*
```

### 공유 머신 충돌

```bash
# 사용자별 캐시 분리
export TMPDIR="/tmp/$(whoami)"
mkdir -p "$TMPDIR"

# 빌드 전 다른 빌드 확인
pgrep -l xcodebuild
```

---

## References

- [GitHub Actions - Self-hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Jenkins - macOS Agents](https://www.jenkins.io/doc/book/installing/macos/)
- [Fastlane Documentation](https://docs.fastlane.tools/)
- [07-developer-guide.md](07-developer-guide.md)
- [08-automation-scripts.md](08-automation-scripts.md)
