# macOS Developer Tools Cache Reference

> Last Updated: 2025-12-25

## Overview

개발자 도구(Xcode, iOS Simulator, CocoaPods, Homebrew 등)는 빌드 속도 향상을 위해 대량의 캐시를 생성합니다. 이러한 캐시는 수십 GB에 달할 수 있어 정기적인 관리가 필요합니다.

## Xcode Caches

### 공간 사용 개요

| 캐시 유형 | 일반적 크기 | 위치 |
|----------|-----------|------|
| Derived Data | 5-50GB | `~/Library/Developer/Xcode/DerivedData/` |
| Archives | 1-20GB | `~/Library/Developer/Xcode/Archives/` |
| iOS Device Support | 20-100GB | `~/Library/Developer/Xcode/iOS DeviceSupport/` |
| watchOS Device Support | 5-20GB | `~/Library/Developer/Xcode/watchOS DeviceSupport/` |
| Simulator Runtimes | 5-50GB | `/Library/Developer/CoreSimulator/Profiles/Runtimes/` |

### Derived Data

빌드 중간 파일, 인덱스, 모듈 캐시 저장

```bash
# 위치
~/Library/Developer/Xcode/DerivedData/

# 크기 확인
du -sh ~/Library/Developer/Xcode/DerivedData

# 전체 정리 (가장 효과적)
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 특정 프로젝트만 정리
rm -rf ~/Library/Developer/Xcode/DerivedData/MyProject-*

# Xcode에서 정리
# Xcode → Settings → Locations → Derived Data → 화살표 클릭 → 삭제
```

#### Derived Data 구조

```
DerivedData/
├── MyProject-abcdef123/
│   ├── Build/              # 빌드 결과물
│   │   ├── Intermediates/  # 중간 파일
│   │   └── Products/       # 빌드 산출물
│   ├── Index/              # 코드 인덱스
│   └── Logs/               # 빌드 로그
└── ModuleCache.noindex/    # Swift 모듈 캐시
```

### Module Cache

```bash
# 모듈 캐시 위치
~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/

# 정리
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/*

# Swift 모듈 캐시 (별도 위치)
rm -rf ~/Library/Caches/org.swift.swiftpm/
```

### Archives

App Store 제출용 아카이브 저장

```bash
# 위치
~/Library/Developer/Xcode/Archives/

# 크기 확인
du -sh ~/Library/Developer/Xcode/Archives

# 오래된 아카이브 찾기 (90일 이상)
find ~/Library/Developer/Xcode/Archives -mtime +90 -type d -name "*.xcarchive"

# 수동 정리: Xcode → Window → Organizer → Archives → 삭제
```

### iOS Device Support

연결된 iOS 기기의 디버깅 심볼

```bash
# 위치
~/Library/Developer/Xcode/iOS DeviceSupport/

# 크기 확인 (매우 큼)
du -sh ~/Library/Developer/Xcode/iOS\ DeviceSupport

# 버전별 크기
du -sh ~/Library/Developer/Xcode/iOS\ DeviceSupport/*

# 오래된 버전 정리 (현재 사용 기기 제외)
# 예: iOS 15 이하 삭제
find ~/Library/Developer/Xcode/iOS\ DeviceSupport -maxdepth 1 -name "15.*" -type d -exec rm -rf {} \;
```

> **주의**: 삭제 후 해당 iOS 버전 기기 연결 시 심볼 재다운로드 필요 (시간 소요)

---

## iOS Simulator

### Simulator 디바이스

```bash
# 디바이스 목록
xcrun simctl list devices

# 사용 불가능한 디바이스 삭제
xcrun simctl delete unavailable

# 모든 시뮬레이터 콘텐츠 초기화
xcrun simctl erase all

# 특정 시뮬레이터 삭제
xcrun simctl delete [DEVICE_UDID]
```

### Simulator Runtimes

```bash
# 런타임 목록
xcrun simctl runtime list

# 사용 불가능한 런타임 삭제
xcrun simctl runtime delete unavailable

# 특정 런타임 삭제
xcrun simctl runtime delete [RUNTIME_ID]

# 런타임 저장 위치
/Library/Developer/CoreSimulator/Profiles/Runtimes/
```

### Simulator Caches

```bash
# 시뮬레이터 캐시
~/Library/Developer/CoreSimulator/Caches/

# 시뮬레이터 기기 데이터
~/Library/Developer/CoreSimulator/Devices/

# 캐시 정리
rm -rf ~/Library/Developer/CoreSimulator/Caches/*

# 전체 시뮬레이터 초기화 (주의!)
rm -rf ~/Library/Developer/CoreSimulator/Devices/*
```

---

## Package Managers

### CocoaPods

```bash
# CocoaPods 캐시 위치
~/Library/Caches/CocoaPods/

# 크기 확인
du -sh ~/Library/Caches/CocoaPods

# 캐시 정리
rm -rf ~/Library/Caches/CocoaPods/*

# 또는 CocoaPods 명령 사용
pod cache clean --all
```

### Carthage

```bash
# Carthage 캐시
~/Library/Caches/org.carthage.CarthageKit/

# 프로젝트별 빌드
./Carthage/Build/

# 캐시 정리
rm -rf ~/Library/Caches/org.carthage.CarthageKit/*

# 프로젝트에서 정리
rm -rf ./Carthage/Build
```

### Swift Package Manager (SPM)

```bash
# SPM 캐시 위치
~/Library/Caches/org.swift.swiftpm/

# 크기 확인
du -sh ~/Library/Caches/org.swift.swiftpm

# 캐시 정리
rm -rf ~/Library/Caches/org.swift.swiftpm/*

# Xcode에서 정리
# File → Packages → Reset Package Caches
```

---

## Homebrew

```bash
# Homebrew 캐시 위치
$(brew --cache)
# 보통: ~/Library/Caches/Homebrew/

# 캐시 크기 확인
du -sh $(brew --cache)

# 오래된 버전 정리
brew cleanup

# 모든 캐시 정리
brew cleanup -s

# 강제 전체 정리
rm -rf $(brew --cache)/*
```

### Homebrew 로그

```bash
# Homebrew 로그
~/Library/Logs/Homebrew/

# 정리
rm -rf ~/Library/Logs/Homebrew/*
```

---

## Node.js / npm / yarn

### npm

```bash
# npm 캐시 위치
~/.npm/

# 캐시 크기
du -sh ~/.npm

# 캐시 정리
npm cache clean --force

# 캐시 검증
npm cache verify
```

### yarn

```bash
# yarn 캐시 위치
yarn cache dir
# 보통: ~/Library/Caches/Yarn/

# 캐시 크기
du -sh $(yarn cache dir)

# 캐시 정리
yarn cache clean
```

### pnpm

```bash
# pnpm 캐시/스토어 위치
pnpm store path

# 캐시 정리
pnpm store prune
```

---

## Python

### pip

```bash
# pip 캐시 위치
~/Library/Caches/pip/

# 캐시 크기
du -sh ~/Library/Caches/pip

# 캐시 정리
pip cache purge
```

### Conda / Miniconda

```bash
# conda 캐시 정리
conda clean --all

# 특정 항목만 정리
conda clean --packages  # 사용하지 않는 패키지
conda clean --tarballs  # 다운로드된 패키지 압축 파일
```

### pyenv

```bash
# pyenv 버전 위치
~/.pyenv/versions/

# 사용하지 않는 버전 확인
pyenv versions

# 버전 삭제
pyenv uninstall 3.8.0
```

---

## Docker

```bash
# Docker 데이터 위치
~/Library/Containers/com.docker.docker/Data/

# Docker 시스템 사용량 확인
docker system df

# 사용하지 않는 데이터 정리
docker system prune

# 볼륨 포함 전체 정리 (주의!)
docker system prune -a --volumes

# 빌드 캐시만 정리
docker builder prune
```

### Docker Desktop 설정

```bash
# Docker Desktop 가상 디스크
~/Library/Containers/com.docker.docker/Data/vms/

# 디스크 크기 제한: Docker Desktop → Settings → Resources
```

---

## JetBrains IDEs

### IntelliJ IDEA / Android Studio / PyCharm 등

```bash
# 캐시 위치 (버전별로 다름)
~/Library/Caches/JetBrains/

# 로그 위치
~/Library/Logs/JetBrains/

# 설정 위치
~/Library/Application Support/JetBrains/

# 캐시 정리
rm -rf ~/Library/Caches/JetBrains/*

# IDE 내에서: File → Invalidate Caches / Restart
```

### Android Studio 추가 항목

```bash
# Android SDK
~/Library/Android/sdk/

# AVD (Android Virtual Devices)
~/.android/avd/

# Gradle 캐시
~/.gradle/caches/

# Gradle 캐시 정리
rm -rf ~/.gradle/caches/*
```

---

## VS Code

```bash
# VS Code 캐시
~/Library/Application Support/Code/Cache/
~/Library/Application Support/Code/CachedData/
~/Library/Application Support/Code/CachedExtensions/

# 확장 프로그램
~/.vscode/extensions/

# 캐시 정리
rm -rf ~/Library/Application\ Support/Code/Cache/*
rm -rf ~/Library/Application\ Support/Code/CachedData/*
```

---

## Comprehensive Cleanup Script

```bash
#!/bin/bash
# developer_cache_cleanup.sh

echo "=== Developer Cache Cleanup ==="
echo "Date: $(date)"
echo ""

# 정리 전 공간 확인
echo "Before cleanup:"
df -h / | tail -1

# 1. Xcode Derived Data
echo -e "\n[1/10] Cleaning Xcode Derived Data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null
echo "Done"

# 2. iOS Simulator (unavailable only)
echo -e "\n[2/10] Cleaning unavailable simulators..."
xcrun simctl delete unavailable 2>/dev/null
echo "Done"

# 3. CocoaPods cache
echo -e "\n[3/10] Cleaning CocoaPods cache..."
rm -rf ~/Library/Caches/CocoaPods/* 2>/dev/null
echo "Done"

# 4. SPM cache
echo -e "\n[4/10] Cleaning Swift Package Manager cache..."
rm -rf ~/Library/Caches/org.swift.swiftpm/* 2>/dev/null
echo "Done"

# 5. Homebrew cleanup
echo -e "\n[5/10] Cleaning Homebrew..."
brew cleanup -s 2>/dev/null
echo "Done"

# 6. npm cache
echo -e "\n[6/10] Cleaning npm cache..."
npm cache clean --force 2>/dev/null
echo "Done"

# 7. pip cache
echo -e "\n[7/10] Cleaning pip cache..."
pip cache purge 2>/dev/null
echo "Done"

# 8. Gradle cache
echo -e "\n[8/10] Cleaning Gradle cache..."
rm -rf ~/.gradle/caches/* 2>/dev/null
echo "Done"

# 9. Docker (if available)
echo -e "\n[9/10] Cleaning Docker..."
docker system prune -f 2>/dev/null || echo "Docker not available"
echo "Done"

# 10. JetBrains cache
echo -e "\n[10/10] Cleaning JetBrains cache..."
rm -rf ~/Library/Caches/JetBrains/* 2>/dev/null
echo "Done"

# 정리 후 공간 확인
echo -e "\n=== Cleanup Complete ==="
echo "After cleanup:"
df -h / | tail -1
```

---

## Space Usage Summary

| 도구 | 예상 정리 공간 | 위험도 |
|-----|--------------|--------|
| Xcode Derived Data | 5-50GB | ✅ 안전 |
| iOS Device Support (오래된) | 10-50GB | ⚠️ 재다운로드 필요 |
| Simulator Runtimes (오래된) | 5-30GB | ⚠️ 재다운로드 필요 |
| CocoaPods/SPM | 1-5GB | ✅ 안전 |
| Homebrew | 1-10GB | ✅ 안전 |
| npm/yarn | 1-5GB | ✅ 안전 |
| Docker | 5-50GB | ⚠️ 이미지 재다운로드 |
| Gradle | 2-10GB | ✅ 안전 |

---

## Recommended Tools

### DevCleaner for Xcode

- 오픈소스 (GPL-3.0)
- Xcode 관련 캐시 전문
- GUI로 쉬운 관리

[GitHub - DevCleaner](https://github.com/vashpan/xcode-dev-cleaner)

### xcleaner

- 메뉴바 앱
- Derived Data 자동 정리
- 프로젝트 연결 확인

---

## References

- [MacPaw - Clear Xcode Cache](https://macpaw.com/how-to/clear-xcode-cache)
- [SwiftyPlace - Clean Xcode Junk](https://www.swiftyplace.com/blog/how-to-clean-xcode-on-your-mac)
- [Dr.Buho - Delete Xcode Cache](https://www.drbuho.com/how-to/delete-xcode-cache-mac)
- [Medium - Clearing Xcode Cache](https://vikramios.medium.com/clearing-xcode-cache-a-guide-to-boosting-development-efficiency-e83fbf6c480b)
