# macOS Cleanup Automation Scripts

> Last Updated: 2025-12-25

## Overview

이 문서는 macOS 정리 작업을 자동화하기 위한 스크립트 모음입니다. 일회성 정리부터 정기적인 유지보수까지 다양한 시나리오를 다룹니다.

## Script Collection

### 1. Master Cleanup Script

모든 정리 작업을 통합한 마스터 스크립트

```bash
#!/bin/bash
# master_cleanup.sh
# macOS 통합 정리 스크립트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로깅 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 공간 확인 함수
get_free_space() {
    df -h / | awk 'NR==2 {print $4}'
}

# 시작 배너
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              macOS Master Cleanup Script                      ║"
echo "║                   Version 0.1.0.0                              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "시작 시간: $(date)"
echo "시작 여유 공간: $(get_free_space)"
echo ""

# 정리 레벨 선택
echo "정리 레벨을 선택하세요:"
echo "  1) Light   - 휴지통, 브라우저 캐시만"
echo "  2) Normal  - 위 + 사용자 캐시, 오래된 로그"
echo "  3) Deep    - 위 + 개발자 캐시 (Xcode, npm 등)"
echo "  4) Custom  - 항목별 선택"
read -p "선택 (1-4): " level

case $level in
    1) cleanup_level="light" ;;
    2) cleanup_level="normal" ;;
    3) cleanup_level="deep" ;;
    4) cleanup_level="custom" ;;
    *) log_error "잘못된 선택"; exit 1 ;;
esac

# ========== Light Cleanup ==========
light_cleanup() {
    log_info "Light 정리 시작..."

    # 휴지통
    log_info "휴지통 비우기..."
    rm -rf ~/.Trash/* 2>/dev/null
    log_success "휴지통 비움"

    # 브라우저 캐시
    log_info "브라우저 캐시 정리..."
    rm -rf ~/Library/Caches/com.apple.Safari/WebKitCache/* 2>/dev/null
    rm -rf ~/Library/Caches/Google/Chrome/Default/Cache/* 2>/dev/null
    rm -rf ~/Library/Caches/Firefox/Profiles/*/cache2/* 2>/dev/null
    rm -rf ~/Library/Caches/com.microsoft.Edge/Default/Cache/* 2>/dev/null
    log_success "브라우저 캐시 정리 완료"
}

# ========== Normal Cleanup ==========
normal_cleanup() {
    light_cleanup

    log_info "Normal 정리 추가 작업..."

    # 사용자 캐시 (주요 앱)
    log_info "앱 캐시 정리..."
    rm -rf ~/Library/Caches/com.spotify.client/* 2>/dev/null
    rm -rf ~/Library/Caches/com.tinyspeck.slackmacgap/* 2>/dev/null
    rm -rf ~/Library/Caches/com.hnc.Discord/* 2>/dev/null
    log_success "앱 캐시 정리 완료"

    # 오래된 로그 (30일+)
    log_info "오래된 로그 정리..."
    find ~/Library/Logs -mtime +30 -type f -delete 2>/dev/null
    log_success "오래된 로그 정리 완료"

    # 크래시 리포트 (30일+)
    log_info "오래된 크래시 리포트 정리..."
    find ~/Library/Logs/DiagnosticReports -mtime +30 -type f -delete 2>/dev/null
    log_success "크래시 리포트 정리 완료"

    # 다운로드 폴더 오래된 파일 (90일+)
    log_info "오래된 다운로드 파일 정리..."
    find ~/Downloads -mtime +90 -type f -delete 2>/dev/null
    log_success "다운로드 폴더 정리 완료"
}

# ========== Deep Cleanup ==========
deep_cleanup() {
    normal_cleanup

    log_info "Deep 정리 추가 작업..."

    # Xcode (있는 경우)
    if [ -d ~/Library/Developer/Xcode ]; then
        log_info "Xcode 캐시 정리..."
        rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null
        rm -rf ~/Library/Developer/Xcode/Archives/*/*/dSYMs/* 2>/dev/null
        xcrun simctl delete unavailable 2>/dev/null || true
        log_success "Xcode 정리 완료"
    fi

    # npm
    if command -v npm &> /dev/null; then
        log_info "npm 캐시 정리..."
        npm cache clean --force 2>/dev/null
        log_success "npm 캐시 정리 완료"
    fi

    # yarn
    if command -v yarn &> /dev/null; then
        log_info "yarn 캐시 정리..."
        yarn cache clean 2>/dev/null
        log_success "yarn 캐시 정리 완료"
    fi

    # pip
    if command -v pip3 &> /dev/null; then
        log_info "pip 캐시 정리..."
        pip3 cache purge 2>/dev/null
        log_success "pip 캐시 정리 완료"
    fi

    # Homebrew
    if command -v brew &> /dev/null; then
        log_info "Homebrew 정리..."
        brew cleanup -s 2>/dev/null
        log_success "Homebrew 정리 완료"
    fi

    # Docker
    if command -v docker &> /dev/null; then
        log_info "Docker 정리..."
        docker system prune -f 2>/dev/null || true
        log_success "Docker 정리 완료"
    fi

    # CocoaPods
    if command -v pod &> /dev/null; then
        log_info "CocoaPods 캐시 정리..."
        pod cache clean --all 2>/dev/null
        log_success "CocoaPods 정리 완료"
    fi

    # SPM
    log_info "Swift Package Manager 캐시 정리..."
    rm -rf ~/Library/Caches/org.swift.swiftpm/* 2>/dev/null
    log_success "SPM 정리 완료"

    # Gradle
    if [ -d ~/.gradle ]; then
        log_info "Gradle 캐시 정리..."
        rm -rf ~/.gradle/caches/* 2>/dev/null
        log_success "Gradle 정리 완료"
    fi

    # JetBrains
    if [ -d ~/Library/Caches/JetBrains ]; then
        log_info "JetBrains 캐시 정리..."
        rm -rf ~/Library/Caches/JetBrains/* 2>/dev/null
        log_success "JetBrains 정리 완료"
    fi

    # VS Code
    if [ -d ~/Library/Application\ Support/Code ]; then
        log_info "VS Code 캐시 정리..."
        rm -rf ~/Library/Application\ Support/Code/Cache/* 2>/dev/null
        rm -rf ~/Library/Application\ Support/Code/CachedData/* 2>/dev/null
        log_success "VS Code 정리 완료"
    fi
}

# ========== Custom Cleanup ==========
custom_cleanup() {
    echo ""
    echo "정리할 항목을 선택하세요 (y/n):"

    read -p "  휴지통? " trash
    read -p "  브라우저 캐시? " browser
    read -p "  앱 캐시? " app_cache
    read -p "  오래된 로그? " logs
    read -p "  오래된 다운로드? " downloads
    read -p "  Xcode 캐시? " xcode
    read -p "  npm/yarn 캐시? " npm
    read -p "  Docker? " docker
    read -p "  Homebrew? " brew_clean

    [[ "$trash" == "y" ]] && rm -rf ~/.Trash/* 2>/dev/null && log_success "휴지통 비움"
    [[ "$browser" == "y" ]] && {
        rm -rf ~/Library/Caches/com.apple.Safari/WebKitCache/* 2>/dev/null
        rm -rf ~/Library/Caches/Google/Chrome/Default/Cache/* 2>/dev/null
        log_success "브라우저 캐시 정리"
    }
    [[ "$app_cache" == "y" ]] && rm -rf ~/Library/Caches/* 2>/dev/null && log_success "앱 캐시 정리"
    [[ "$logs" == "y" ]] && find ~/Library/Logs -mtime +30 -delete 2>/dev/null && log_success "로그 정리"
    [[ "$downloads" == "y" ]] && find ~/Downloads -mtime +90 -delete 2>/dev/null && log_success "다운로드 정리"
    [[ "$xcode" == "y" ]] && rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null && log_success "Xcode 정리"
    [[ "$npm" == "y" ]] && {
        npm cache clean --force 2>/dev/null
        yarn cache clean 2>/dev/null
        log_success "npm/yarn 정리"
    }
    [[ "$docker" == "y" ]] && docker system prune -f 2>/dev/null && log_success "Docker 정리"
    [[ "$brew_clean" == "y" ]] && brew cleanup -s 2>/dev/null && log_success "Homebrew 정리"
}

# 선택된 정리 실행
case $cleanup_level in
    "light") light_cleanup ;;
    "normal") normal_cleanup ;;
    "deep") deep_cleanup ;;
    "custom") custom_cleanup ;;
esac

# 결과 출력
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "완료 시간: $(date)"
echo "최종 여유 공간: $(get_free_space)"
echo "═══════════════════════════════════════════════════════════════"
```

---

### 2. Quick Cleanup (One-liner)

빠른 정리를 위한 원라이너

```bash
# 기본 정리 (휴지통 + 브라우저 캐시)
rm -rf ~/.Trash/* ~/Library/Caches/com.apple.Safari/WebKitCache/* ~/Library/Caches/Google/Chrome/Default/Cache/* 2>/dev/null && echo "Quick cleanup done: $(df -h / | awk 'NR==2 {print $4}') free"

# 개발자 빠른 정리
rm -rf ~/Library/Developer/Xcode/DerivedData/* && npm cache clean --force 2>/dev/null && brew cleanup -s 2>/dev/null && echo "Dev cleanup done"

# 긴급 공간 확보
rm -rf ~/.Trash/* ~/Library/Caches/* ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null && docker system prune -af 2>/dev/null; echo "Emergency cleanup done: $(df -h / | awk 'NR==2 {print $4}') free"
```

---

### 3. Scheduled Cleanup (launchd)

정기 실행을 위한 launchd 설정

#### 일일 정리 (Light)

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

#### 주간 정리 (Normal)

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
            # 브라우저 캐시
            rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null;
            rm -rf ~/Library/Caches/Google/Chrome/* 2>/dev/null;

            # 개발자 캐시
            rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null;
            npm cache clean --force 2>/dev/null;
            brew cleanup -s 2>/dev/null;

            # 로그
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

#### launchd 관리 명령

```bash
# 로드 (활성화)
launchctl load ~/Library/LaunchAgents/com.user.daily-cleanup.plist
launchctl load ~/Library/LaunchAgents/com.user.weekly-cleanup.plist

# 언로드 (비활성화)
launchctl unload ~/Library/LaunchAgents/com.user.daily-cleanup.plist

# 상태 확인
launchctl list | grep cleanup

# 즉시 실행 테스트
launchctl start com.user.daily-cleanup

# 모든 사용자 정의 작업 확인
launchctl list | grep com.user
```

---

### 4. Disk Space Monitor

디스크 공간 모니터링 및 알림

```bash
#!/bin/bash
# disk_monitor.sh
# 디스크 공간이 부족하면 알림

THRESHOLD=90  # 90% 이상 사용 시 알림
LOG_FILE=~/Library/Logs/disk_monitor.log

# 현재 사용률 확인
usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
free_space=$(df -h / | awk 'NR==2 {print $4}')

# 로그 기록
echo "$(date): Disk usage: ${usage}%, Free: ${free_space}" >> "$LOG_FILE"

if [ "$usage" -ge "$THRESHOLD" ]; then
    # macOS 알림 표시
    osascript -e "display notification \"디스크 사용률: ${usage}% (여유: ${free_space})\" with title \"⚠️ 디스크 공간 부족\" subtitle \"정리가 필요합니다\""

    # 터미널 알림 (백그라운드 실행 시)
    echo "⚠️  경고: 디스크 사용률 ${usage}% (여유: ${free_space})"

    # 자동 기본 정리 실행 (선택사항)
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
    <integer>3600</integer> <!-- 매시간 -->
</dict>
</plist>
```

---

### 5. Interactive Cleanup Menu

인터랙티브 메뉴 기반 정리 도구

```bash
#!/bin/bash
# interactive_cleanup.sh

show_menu() {
    clear
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           macOS Interactive Cleanup Tool                   ║"
    echo "╠════════════════════════════════════════════════════════════╣"
    echo "║  현재 디스크 상태: $(df -h / | awk 'NR==2 {printf "%s used (%s free)", $3, $4}')       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  [1] 📊 디스크 사용량 분석"
    echo "  [2] 🗑️  휴지통 비우기"
    echo "  [3] 🌐 브라우저 캐시 정리"
    echo "  [4] 📦 앱 캐시 정리"
    echo "  [5] 📝 로그 파일 정리"
    echo "  [6] 💻 개발자 도구 정리"
    echo "  [7] 🐳 Docker 정리"
    echo "  [8] 🍺 Homebrew 정리"
    echo "  [9] ⚡ 전체 빠른 정리"
    echo "  [0] 🚪 종료"
    echo ""
}

disk_analysis() {
    echo ""
    echo "📊 디스크 사용량 분석"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "주요 디렉토리:"
    du -sh ~/* 2>/dev/null | sort -hr | head -10
    echo ""
    echo "캐시 디렉토리:"
    du -sh ~/Library/Caches 2>/dev/null
    du -sh ~/Library/Developer 2>/dev/null
    echo ""
    read -p "계속하려면 Enter..."
}

empty_trash() {
    size=$(du -sh ~/.Trash 2>/dev/null | cut -f1)
    echo "휴지통 크기: $size"
    read -p "휴지통을 비우시겠습니까? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        rm -rf ~/.Trash/*
        echo "✓ 휴지통이 비워졌습니다."
    fi
    read -p "계속하려면 Enter..."
}

clean_browser_cache() {
    echo ""
    echo "브라우저 캐시:"
    du -sh ~/Library/Caches/com.apple.Safari 2>/dev/null | sed 's/^/  Safari: /'
    du -sh ~/Library/Caches/Google/Chrome 2>/dev/null | sed 's/^/  Chrome: /'
    du -sh ~/Library/Caches/Firefox 2>/dev/null | sed 's/^/  Firefox: /'
    echo ""
    read -p "브라우저 캐시를 정리하시겠습니까? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null
        rm -rf ~/Library/Caches/Google/Chrome/* 2>/dev/null
        rm -rf ~/Library/Caches/Firefox/Profiles/*/cache2/* 2>/dev/null
        echo "✓ 브라우저 캐시가 정리되었습니다."
    fi
    read -p "계속하려면 Enter..."
}

clean_app_cache() {
    size=$(du -sh ~/Library/Caches 2>/dev/null | cut -f1)
    echo "앱 캐시 총 크기: $size"
    echo ""
    echo "상위 10개 캐시:"
    du -sh ~/Library/Caches/* 2>/dev/null | sort -hr | head -10
    echo ""
    read -p "모든 앱 캐시를 정리하시겠습니까? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        rm -rf ~/Library/Caches/*
        echo "✓ 앱 캐시가 정리되었습니다."
    fi
    read -p "계속하려면 Enter..."
}

clean_logs() {
    size=$(du -sh ~/Library/Logs 2>/dev/null | cut -f1)
    echo "로그 파일 총 크기: $size"
    read -p "30일 이상 된 로그를 정리하시겠습니까? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        find ~/Library/Logs -mtime +30 -type f -delete 2>/dev/null
        echo "✓ 오래된 로그가 정리되었습니다."
    fi
    read -p "계속하려면 Enter..."
}

clean_developer() {
    echo ""
    echo "개발자 도구 캐시:"
    du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null | sed 's/^/  Xcode Derived Data: /'
    du -sh ~/Library/Developer/CoreSimulator 2>/dev/null | sed 's/^/  Simulators: /'
    du -sh ~/.npm 2>/dev/null | sed 's/^/  npm: /'
    du -sh $(yarn cache dir 2>/dev/null) 2>/dev/null | sed 's/^/  yarn: /'
    du -sh ~/Library/Caches/org.swift.swiftpm 2>/dev/null | sed 's/^/  SPM: /'
    echo ""

    echo "정리할 항목 선택:"
    echo "  [1] Xcode Derived Data"
    echo "  [2] Unavailable Simulators"
    echo "  [3] npm/yarn cache"
    echo "  [4] SPM cache"
    echo "  [5] 모두"
    echo "  [0] 취소"
    read -p "선택: " choice

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

    echo "✓ 개발자 도구 정리 완료"
    read -p "계속하려면 Enter..."
}

clean_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker가 설치되어 있지 않습니다."
        read -p "계속하려면 Enter..."
        return
    fi

    echo ""
    docker system df
    echo ""
    read -p "Docker 시스템을 정리하시겠습니까? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        docker system prune -f
        echo "✓ Docker 정리 완료"
    fi
    read -p "계속하려면 Enter..."
}

clean_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo "Homebrew가 설치되어 있지 않습니다."
        read -p "계속하려면 Enter..."
        return
    fi

    cache_size=$(du -sh $(brew --cache) 2>/dev/null | cut -f1)
    echo "Homebrew 캐시 크기: $cache_size"
    read -p "Homebrew를 정리하시겠습니까? (y/n): " confirm
    if [ "$confirm" = "y" ]; then
        brew cleanup -s
        echo "✓ Homebrew 정리 완료"
    fi
    read -p "계속하려면 Enter..."
}

quick_cleanup() {
    echo ""
    echo "⚡ 빠른 정리 실행 중..."
    rm -rf ~/.Trash/* 2>/dev/null && echo "✓ 휴지통"
    rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null && echo "✓ Safari 캐시"
    rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null && echo "✓ Xcode Derived Data"
    find ~/Library/Logs -mtime +30 -delete 2>/dev/null && echo "✓ 오래된 로그"
    brew cleanup -s 2>/dev/null && echo "✓ Homebrew"
    echo ""
    echo "최종 여유 공간: $(df -h / | awk 'NR==2 {print $4}')"
    read -p "계속하려면 Enter..."
}

# 메인 루프
while true; do
    show_menu
    read -p "선택: " option

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
        0) echo "종료합니다."; exit 0 ;;
        *) echo "잘못된 선택입니다." ;;
    esac
done
```

---

### 6. Pre-commit Cleanup Hook

Git 커밋 전 자동 정리

```bash
#!/bin/bash
# .git/hooks/pre-commit
# 커밋 전 빌드 캐시 정리

# 프로젝트 루트 찾기
ROOT=$(git rev-parse --show-toplevel)

# Node.js 프로젝트
if [ -f "$ROOT/package.json" ]; then
    # .cache 정리
    find "$ROOT" -type d -name ".cache" -not -path "*/node_modules/*" -exec rm -rf {} + 2>/dev/null

    # .next 캐시 (Next.js)
    rm -rf "$ROOT/.next/cache" 2>/dev/null

    # .parcel-cache
    rm -rf "$ROOT/.parcel-cache" 2>/dev/null
fi

# Swift 프로젝트
if [ -f "$ROOT/Package.swift" ] || [ -d "$ROOT/*.xcodeproj" ]; then
    # .build 정리 (SPM)
    rm -rf "$ROOT/.build" 2>/dev/null
fi

exit 0
```

---

## Installation Guide

### 스크립트 설치

```bash
# 디렉토리 생성
mkdir -p ~/Scripts/cleanup

# 스크립트 다운로드/복사
# (위의 스크립트들을 저장)

# 실행 권한 부여
chmod +x ~/Scripts/cleanup/*.sh

# PATH에 추가 (선택사항)
echo 'export PATH="$HOME/Scripts/cleanup:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### launchd 설정

```bash
# plist 파일 복사
cp *.plist ~/Library/LaunchAgents/

# 로드
launchctl load ~/Library/LaunchAgents/com.user.daily-cleanup.plist
launchctl load ~/Library/LaunchAgents/com.user.weekly-cleanup.plist
launchctl load ~/Library/LaunchAgents/com.user.disk-monitor.plist
```

---

## Best Practices

### 스크립트 작성 시

1. **에러 처리**: `2>/dev/null`로 에러 숨기기
2. **존재 확인**: 명령어/디렉토리 존재 확인 후 실행
3. **로깅**: 작업 기록 남기기
4. **알림**: 중요 작업 완료 시 알림

### 자동화 시

1. **시간 선택**: 사용하지 않는 시간대 (새벽)
2. **점진적 정리**: 한 번에 모든 것 정리 X
3. **백업 확인**: 중요 데이터 백업 후 정리
4. **테스트**: 수동 실행 후 자동화

---

## References

- [07-developer-guide.md](07-developer-guide.md) - 개발자 가이드
- [06-safe-cleanup-guide.md](06-safe-cleanup-guide.md) - 안전한 정리 가이드
- [Apple - launchd Documentation](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html)
