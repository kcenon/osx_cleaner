# macOS Cache System Analysis

> Last Updated: 2025-12-25

## Overview

macOS의 캐시 시스템은 성능 최적화를 위해 다양한 레벨에서 데이터를 저장합니다. 이 문서는 각 캐시 유형, 위치, 안전한 정리 방법을 분석합니다.

## Cache Hierarchy

```
                    ┌─────────────────────┐
                    │    System Cache     │
                    │   /Library/Caches   │
                    │   (Root Required)   │
                    └──────────┬──────────┘
                               │
                    ┌──────────┴──────────┐
                    │     User Cache      │
                    │  ~/Library/Caches   │
                    │  (User Accessible)  │
                    └──────────┬──────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
    ┌─────┴─────┐       ┌─────┴─────┐       ┌─────┴─────┐
    │    App    │       │  Browser  │       │  System   │
    │   Cache   │       │   Cache   │       │  Service  │
    └───────────┘       └───────────┘       └───────────┘
```

## System Cache (/Library/Caches)

### 위치 및 특성

| 속성 | 값 |
|-----|-----|
| 경로 | `/Library/Caches` |
| 권한 | root 필요 (일부 하위 디렉토리) |
| 용량 | 일반적으로 1-5GB |
| 위험도 | **높음** - 시스템 파일 포함 |

### 주요 시스템 캐시

| 디렉토리 | 설명 | 삭제 안전성 |
|---------|------|------------|
| `com.apple.iconservices.store` | 아이콘 캐시 | ⚠️ 주의 |
| `com.apple.amsengagementd` | App Store 관련 | ⚠️ 주의 |
| `com.apple.preferencepanes.cache` | 시스템 설정 캐시 | ✅ 안전 |

> **권장사항**: 시스템 캐시는 수동으로 삭제하지 않는 것이 좋습니다.

## User Cache (~/Library/Caches)

### 위치 및 특성

| 속성 | 값 |
|-----|-----|
| 경로 | `~/Library/Caches` |
| 권한 | 사용자 접근 가능 |
| 용량 | 5-50GB+ (사용 패턴에 따라 다름) |
| 위험도 | **낮음** - 대부분 재생성 가능 |

### 캐시 분석 명령어

```bash
# 전체 사용자 캐시 크기
du -sh ~/Library/Caches

# 앱별 캐시 크기 (상위 20개)
du -sh ~/Library/Caches/* 2>/dev/null | sort -hr | head -20

# 특정 앱 캐시 상세 정보
du -sh ~/Library/Caches/com.apple.Safari/*
```

### 주요 애플리케이션 캐시

#### Apple 앱

| 앱 | 캐시 경로 | 일반적 크기 | 삭제 안전성 |
|---|----------|-----------|------------|
| Safari | `com.apple.Safari/` | 0.5-5GB | ✅ 안전 |
| Mail | `com.apple.mail/` | 0.1-2GB | ✅ 안전 |
| Photos | `com.apple.Photos/` | 0.5-3GB | ⚠️ 주의 |
| Finder | `com.apple.finder/` | 0.01-0.1GB | ✅ 안전 |
| Preview | `com.apple.Preview/` | 0.01-0.5GB | ✅ 안전 |

#### 서드파티 앱

| 앱 | 캐시 경로 | 일반적 크기 | 삭제 안전성 |
|---|----------|-----------|------------|
| Chrome | `Google/Chrome/` | 0.5-10GB | ✅ 안전 |
| Spotify | `com.spotify.client/` | 1-15GB | ✅ 안전 |
| Slack | `com.tinyspeck.slackmacgap/` | 0.1-2GB | ✅ 안전 |
| VS Code | `com.microsoft.VSCode/` | 0.1-1GB | ✅ 안전 |
| Docker | `com.docker.docker/` | 1-20GB | ⚠️ 주의 |

## Browser Cache Deep Dive

### Safari

```bash
# Safari 캐시 위치
~/Library/Caches/com.apple.Safari/

# Safari 웹사이트 데이터
~/Library/Safari/

# 캐시 크기 확인
du -sh ~/Library/Caches/com.apple.Safari/
```

**안전한 정리 방법:**
1. Safari → 설정 → 개인정보 보호 → 웹 사이트 데이터 관리
2. 또는 Safari → 방문 기록 → 방문 기록 지우기

### Chrome

```bash
# Chrome 캐시 위치
~/Library/Caches/Google/Chrome/

# Chrome 프로필 데이터
~/Library/Application Support/Google/Chrome/

# 캐시 크기 확인
du -sh ~/Library/Caches/Google/Chrome/
```

**안전한 정리 방법:**
1. Chrome → 설정 → 개인 정보 보호 및 보안 → 인터넷 사용 기록 삭제

### Firefox

```bash
# Firefox 캐시 위치
~/Library/Caches/Firefox/

# Firefox 프로필 데이터
~/Library/Application Support/Firefox/

# 캐시 크기 확인
du -sh ~/Library/Caches/Firefox/
```

## Cloud Service Cache

### iCloud

| 캐시 위치 | 설명 | 크기 |
|----------|------|-----|
| `com.apple.bird/` | iCloud 동기화 캐시 | 0.1-5GB |
| `CloudKit/` | CloudKit 메타데이터 | 0.01-1GB |
| `com.apple.iCloudDrive/` | iCloud Drive 캐시 | 변동적 |

```bash
# iCloud 관련 캐시 크기
du -sh ~/Library/Caches/com.apple.bird
du -sh ~/Library/Caches/CloudKit
```

### Dropbox, OneDrive, Google Drive

| 서비스 | 캐시 위치 | 주의사항 |
|-------|----------|---------|
| Dropbox | `com.getdropbox.dropbox/` | 동기화 상태 확인 후 삭제 |
| OneDrive | `com.microsoft.OneDrive/` | 동기화 완료 확인 필요 |
| Google Drive | `com.google.GoogleDrive/` | 스트리밍 파일 주의 |

## Font Cache

macOS는 폰트 렌더링을 위한 전용 캐시를 유지합니다.

```bash
# 폰트 캐시 위치
~/Library/Caches/com.apple.FontRegistry/
/private/var/folders/.../com.apple.FontRegistry/

# 폰트 캐시 초기화 (문제 발생 시)
sudo atsutil databases -remove
atsutil server -shutdown
atsutil server -ping
```

## Spotlight Cache

```bash
# Spotlight 인덱스 위치
/.Spotlight-V100/

# Spotlight 캐시 크기 확인
sudo du -sh /.Spotlight-V100

# Spotlight 재인덱싱 (문제 발생 시)
sudo mdutil -E /
```

## Safe Cache Cleanup Procedures

### 1. 앱별 캐시 정리

```bash
#!/bin/bash
# 안전한 캐시 정리 스크립트

# 앱 종료 확인
echo "정리할 앱을 종료하세요..."

# Safari 캐시
rm -rf ~/Library/Caches/com.apple.Safari/*

# Chrome 캐시
rm -rf ~/Library/Caches/Google/Chrome/*

# Spotify 캐시
rm -rf ~/Library/Caches/com.spotify.client/*

echo "캐시 정리 완료"
```

### 2. 전체 사용자 캐시 정리 (주의)

```bash
# 경고: 모든 앱이 종료된 상태에서만 실행

# 백업 생성 (선택사항)
# cp -r ~/Library/Caches ~/Library/Caches.backup

# 캐시 정리
rm -rf ~/Library/Caches/*

# 재부팅 권장
```

### 3. 특정 앱 캐시만 정리

```bash
# 앱 이름으로 캐시 찾기
find ~/Library/Caches -name "*spotify*" -type d

# 찾은 캐시 정리
rm -rf ~/Library/Caches/com.spotify.client/
```

## Cache Size Monitoring

### 정기 모니터링 스크립트

```bash
#!/bin/bash
# cache_monitor.sh

echo "=== macOS Cache Size Report ==="
echo "Date: $(date)"
echo ""
echo "User Cache Total:"
du -sh ~/Library/Caches 2>/dev/null
echo ""
echo "Top 10 Largest Caches:"
du -sh ~/Library/Caches/* 2>/dev/null | sort -hr | head -10
echo ""
echo "System Cache Total:"
sudo du -sh /Library/Caches 2>/dev/null
```

### launchd 자동 모니터링 설정

```xml
<!-- ~/Library/LaunchAgents/com.user.cachemonitor.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.cachemonitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/cache_monitor.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>9</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
```

## Best Practices

### 정리 권장 주기

| 캐시 유형 | 권장 주기 | 이유 |
|----------|----------|------|
| 브라우저 캐시 | 월 1회 | 자주 갱신됨 |
| 앱 캐시 | 분기 1회 | 성능에 영향 |
| 시스템 캐시 | 정리하지 않음 | 자동 관리됨 |

### 정리 전 체크리스트

- [ ] 모든 관련 앱 종료
- [ ] 중요한 작업 저장 완료
- [ ] 클라우드 동기화 완료 확인
- [ ] `com.apple.*` 제외 고려

## References

- [MacPaw - Clear Cache on Mac](https://macpaw.com/how-to/clear-cache-on-mac)
- [Avast - How to Clear Cache on Mac](https://www.avast.com/c-how-to-clear-cache-on-mac)
- [CleanMyMac - Clear Cache Mac 2025](https://cleanmymac.com/blog/clear-cache-mac)
