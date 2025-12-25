# macOS Developer Cleanup Guide

> Last Updated: 2025-12-25
> Target Audience: iOS, macOS, Web, Backend Developers

## Overview

개발자의 Mac은 일반 사용자보다 훨씬 빠르게 디스크 공간이 소모됩니다. Xcode만으로 100GB 이상을 사용할 수 있으며, Docker, npm, 가상 환경 등이 추가되면 그 양은 더욱 증가합니다. 이 가이드는 개발 생산성을 유지하면서 효율적으로 공간을 관리하는 방법을 제공합니다.

## Developer Space Usage Profile

### 일반적인 개발자 Mac 공간 사용

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

### 개발 스택별 공간 소비

| 스택 | 주요 소비 항목 | 예상 크기 |
|-----|--------------|----------|
| **iOS/macOS** | Xcode, Simulators, Device Support | 50-150GB |
| **Web Frontend** | node_modules, 빌드 캐시 | 10-50GB |
| **Backend** | Docker, 가상 환경, DB | 20-100GB |
| **Mobile (Cross)** | Flutter/RN + 위 항목들 | 30-80GB |
| **ML/Data** | Python 환경, 데이터셋, 모델 | 50-200GB |

---

## Quick Cleanup by Developer Type

### iOS/macOS 개발자

```bash
#!/bin/bash
# ios_developer_cleanup.sh

echo "🍎 iOS/macOS Developer Cleanup"
echo "=============================="

# 1. Xcode Derived Data (가장 효과적)
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
echo "수동으로 필요없는 런타임 삭제: xcrun simctl runtime delete [ID]"

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
echo "=== 추가 권장 사항 ==="
echo "• iOS Device Support 정리: ~/Library/Developer/Xcode/iOS DeviceSupport/"
echo "  (오래된 iOS 버전 폴더 수동 삭제, 각 ~4GB)"
echo "• Archives 정리: Xcode → Window → Organizer → Archives"
echo ""
df -h / | tail -1
```

### Web 개발자 (Node.js/Frontend)

```bash
#!/bin/bash
# web_developer_cleanup.sh

echo "🌐 Web Developer Cleanup"
echo "========================"

# 1. 글로벌 npm 캐시
echo "[1/5] Cleaning npm cache..."
npm cache clean --force 2>/dev/null
echo "✓ npm cache cleared"

# 2. Yarn 캐시
echo "[2/5] Cleaning yarn cache..."
yarn cache clean 2>/dev/null
echo "✓ yarn cache cleared"

# 3. pnpm 스토어 정리
echo "[3/5] Cleaning pnpm store..."
pnpm store prune 2>/dev/null
echo "✓ pnpm store cleaned"

# 4. 오래된 node_modules 찾기
echo "[4/5] Finding old node_modules (not accessed in 30 days)..."
echo "다음 디렉토리들을 검토하세요:"
find ~ -name "node_modules" -type d -atime +30 2>/dev/null | head -20

# 5. Webpack/Vite 캐시
echo "[5/5] Cleaning build caches..."
find ~ -type d -name ".cache" -path "*/node_modules/*" -exec rm -rf {} \; 2>/dev/null
find ~ -type d -name ".parcel-cache" -exec rm -rf {} \; 2>/dev/null
echo "✓ Build caches cleared"

echo ""
echo "=== node_modules 정리 도구 ==="
echo "• npkill: npm i -g npkill && npkill"
echo "• 수동 삭제: rm -rf /path/to/project/node_modules"
echo ""
df -h / | tail -1
```

### Backend 개발자 (Python/Go/Java)

```bash
#!/bin/bash
# backend_developer_cleanup.sh

echo "⚙️ Backend Developer Cleanup"
echo "============================"

# 1. Python pip 캐시
echo "[1/6] Cleaning pip cache..."
pip cache purge 2>/dev/null
pip3 cache purge 2>/dev/null
echo "✓ pip cache cleared"

# 2. Conda 정리
echo "[2/6] Cleaning conda..."
conda clean --all -y 2>/dev/null
echo "✓ conda cleaned"

# 3. Go 모듈 캐시
echo "[3/6] Cleaning Go module cache..."
go clean -modcache 2>/dev/null
echo "✓ Go module cache cleared"

# 4. Gradle 캐시 (Java/Kotlin)
echo "[4/6] Cleaning Gradle cache..."
rm -rf ~/.gradle/caches/*
echo "✓ Gradle cache cleared"

# 5. Maven 캐시 (Java)
echo "[5/6] Cleaning Maven cache..."
rm -rf ~/.m2/repository/*
echo "✓ Maven cache cleared"

# 6. Docker
echo "[6/6] Cleaning Docker..."
docker system prune -f 2>/dev/null
echo "✓ Docker cleaned"

echo ""
echo "=== 추가 권장 사항 ==="
echo "• 가상 환경 정리: pyenv versions, conda env list"
echo "• Docker 볼륨: docker volume prune"
echo "• Docker 이미지: docker image prune -a"
echo ""
df -h / | tail -1
```

### Full-Stack / DevOps 개발자

```bash
#!/bin/bash
# fullstack_cleanup.sh

echo "🚀 Full-Stack Developer Cleanup"
echo "================================"

# 모든 개발 환경 정리
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

# Docker (주의해서 실행)
echo "Docker cleanup..."
docker system prune -f 2>/dev/null

# Homebrew
echo "Homebrew cleanup..."
brew cleanup -s 2>/dev/null

# IDE 캐시
echo "IDE cache cleanup..."
rm -rf ~/Library/Caches/JetBrains/* 2>/dev/null
rm -rf ~/Library/Application\ Support/Code/Cache/* 2>/dev/null

# 일반 캐시
rm -rf ~/Library/Caches/com.apple.dt.Xcode/* 2>/dev/null
rm -rf ~/Library/Caches/org.swift.swiftpm/* 2>/dev/null

echo ""
echo "=== Cleanup Complete ==="
df -h / | tail -1
```

---

## Development Environment Management

### Xcode 버전 관리

```bash
# 설치된 Xcode 버전 확인
mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'"

# 또는 xcode-select 사용
xcode-select -p

# 여러 Xcode 버전 사용 시
# /Applications/Xcode.app (현재)
# /Applications/Xcode-15.app (이전)

# Xcode Command Line Tools 재설치
xcode-select --install

# 특정 Xcode로 전환
sudo xcode-select -s /Applications/Xcode-15.app
```

### iOS Simulator 효율적 관리

```bash
# 필요한 시뮬레이터만 유지
# 권장: 최신 2개 iOS 버전 + 주요 디바이스

# 모든 시뮬레이터 목록
xcrun simctl list devices

# 부팅된 시뮬레이터 종료
xcrun simctl shutdown all

# 특정 시뮬레이터 삭제
xcrun simctl delete [UDID]

# 시뮬레이터 생성 (필요시)
xcrun simctl create "iPhone 15 Pro" "iPhone 15 Pro" "iOS17.0"
```

### iOS Device Support 정리 전략

```bash
# 현재 Device Support 크기 확인
du -sh ~/Library/Developer/Xcode/iOS\ DeviceSupport/*

# 권장: 최근 2개 major 버전만 유지
# 예: iOS 17.x, 18.x만 유지하고 16.x 이하 삭제

# 정리 스크립트
cd ~/Library/Developer/Xcode/iOS\ DeviceSupport/
# 오래된 버전 확인 후 수동 삭제
ls -la | grep "15\." # iOS 15 관련
ls -la | grep "16\." # iOS 16 관련

# 삭제 (주의: 해당 iOS 기기 연결 시 재다운로드 필요)
# rm -rf "15.0 (19A5261w)"
```

---

## node_modules Management

### node_modules 크기 분석

```bash
# 프로젝트별 node_modules 크기
find ~/Projects -name "node_modules" -type d -prune | while read dir; do
    size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    echo "$size    $dir"
done | sort -hr | head -20
```

### npkill 사용 (권장)

```bash
# 설치
npm i -g npkill

# 실행 (인터랙티브 UI)
npkill

# 특정 경로에서 실행
npkill --directory ~/Projects
```

### node_modules 자동 정리 스크립트

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
read -p "위 디렉토리들을 삭제하시겠습니까? (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
    find "$PROJECTS_DIR" -name "node_modules" -type d -atime +$DAYS -exec rm -rf {} \; 2>/dev/null
    echo "삭제 완료"
fi
```

---

## Docker Space Management

### Docker 공간 사용량 확인

```bash
# 전체 Docker 사용량
docker system df

# 상세 정보
docker system df -v
```

### Docker 정리 전략

```bash
#!/bin/bash
# docker_cleanup.sh

echo "🐳 Docker Cleanup"
echo "================="

# 1. 중지된 컨테이너 삭제
echo "[1/5] Removing stopped containers..."
docker container prune -f

# 2. 사용하지 않는 이미지 삭제
echo "[2/5] Removing dangling images..."
docker image prune -f

# 3. 사용하지 않는 볼륨 삭제
echo "[3/5] Removing unused volumes..."
docker volume prune -f

# 4. 사용하지 않는 네트워크 삭제
echo "[4/5] Removing unused networks..."
docker network prune -f

# 5. 빌드 캐시 삭제
echo "[5/5] Removing build cache..."
docker builder prune -f

echo ""
echo "=== Docker Status ==="
docker system df
```

### Docker Desktop 가상 디스크 축소

Docker Desktop의 가상 디스크는 자동으로 축소되지 않습니다.

**방법 1: Docker Desktop 설정**
```
Docker Desktop → Settings → Resources → Advanced
→ Virtual disk limit 조정
→ Apply & Restart
```

**방법 2: 가상 디스크 재생성**
```bash
# Docker Desktop 종료 후
rm ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw

# Docker Desktop 재시작 (새 디스크 생성됨)
```

---

## IDE Cache Management

### VS Code

```bash
# 캐시 위치
~/Library/Application Support/Code/Cache/
~/Library/Application Support/Code/CachedData/
~/Library/Application Support/Code/CachedExtensionVSIXs/
~/Library/Application Support/Code/CachedExtensions/

# 정리
rm -rf ~/Library/Application\ Support/Code/Cache/*
rm -rf ~/Library/Application\ Support/Code/CachedData/*

# 확장 프로그램 정리
code --list-extensions
code --uninstall-extension [extension-id]
```

### JetBrains IDEs (IntelliJ, PyCharm, WebStorm 등)

```bash
# 캐시 위치
~/Library/Caches/JetBrains/

# IDE별 크기 확인
du -sh ~/Library/Caches/JetBrains/*

# 전체 정리
rm -rf ~/Library/Caches/JetBrains/*

# IDE 내에서 정리
# File → Invalidate Caches / Restart → Invalidate and Restart
```

### Xcode

```bash
# DerivedData (가장 큰 부분)
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Previews (SwiftUI)
rm -rf ~/Library/Developer/Xcode/UserData/Previews/*

# Archives (선택적)
# Xcode → Window → Organizer → Archives

# Device Logs
rm -rf ~/Library/Developer/Xcode/iOS\ Device\ Logs/*
```

---

## Automated Maintenance

### launchd를 이용한 자동 정리

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
        <integer>0</integer> <!-- 일요일 -->
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
```

```bash
# 등록
launchctl load ~/Library/LaunchAgents/com.dev.cleanup.plist

# 해제
launchctl unload ~/Library/LaunchAgents/com.dev.cleanup.plist
```

### Git Hook을 이용한 프로젝트 정리

```bash
# .git/hooks/post-checkout
#!/bin/bash

# 이전 브랜치에서 사용하던 빌드 캐시 정리
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

### 일일 습관

- [ ] 작업 완료 후 시뮬레이터 종료
- [ ] 사용하지 않는 Docker 컨테이너 중지
- [ ] 빌드 성공 확인 후 불필요한 브랜치 삭제

### 주간 루틴

- [ ] Derived Data 정리 (Xcode 개발자)
- [ ] `npm cache clean --force` 또는 `yarn cache clean`
- [ ] `brew cleanup`
- [ ] Docker 미사용 이미지 정리

### 월간 유지보수

- [ ] 오래된 node_modules 폴더 정리
- [ ] iOS Device Support 정리 (오래된 버전)
- [ ] 가상 환경 정리 (pyenv, conda)
- [ ] 오래된 프로젝트 아카이브 또는 삭제
- [ ] Time Machine 로컬 스냅샷 확인

### 분기별 점검

- [ ] 전체 디스크 사용량 분석
- [ ] 사용하지 않는 앱 제거
- [ ] 개발 도구 버전 정리 (Xcode, 시뮬레이터 런타임)
- [ ] 백업 검증

---

## Space Monitoring Dashboard

```bash
#!/bin/bash
# dev_space_dashboard.sh

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           Developer Space Usage Dashboard                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# 전체 디스크
echo "📊 Disk Overview"
df -h / | tail -1 | awk '{print "   Used: "$3" / "$2" ("$5" full) | Free: "$4}'
echo ""

# 개발 관련 디렉토리
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

### "디스크 공간 부족" 긴급 상황

```bash
# 1. 가장 큰 영향을 주는 항목 먼저 정리
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/.Trash/*

# 2. Docker 정리 (Docker 사용자)
docker system prune -a -f

# 3. 시뮬레이터 정리
xcrun simctl delete unavailable

# 4. 캐시 정리
rm -rf ~/Library/Caches/*
```

### Xcode 빌드 오류 후 정리

```bash
# 클린 빌드를 위한 정리
rm -rf ~/Library/Developer/Xcode/DerivedData/[ProjectName]*

# 전체 클린 (문제가 계속될 때)
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Caches/com.apple.dt.Xcode/*
```

### npm/yarn 설치 오류

```bash
# 캐시 문제일 경우
npm cache clean --force
# 또는
yarn cache clean

# node_modules 재설치
rm -rf node_modules package-lock.json
npm install
```

---

## References

- [05-developer-caches.md](05-developer-caches.md) - 상세 캐시 위치 정보
- [06-safe-cleanup-guide.md](06-safe-cleanup-guide.md) - 안전한 정리 가이드
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Docker Documentation](https://docs.docker.com/config/pruning/)
