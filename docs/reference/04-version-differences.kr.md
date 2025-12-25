# macOS Version-Specific Differences

> Last Updated: 2025-12-25

## Overview

macOS 버전에 따라 임시 파일, 캐시 관리, 스토리지 최적화 방식이 다릅니다. 이 문서는 주요 버전별 차이점과 버전별 정리 시 주의사항을 설명합니다.

## Version Timeline

```
macOS 15 Sequoia    (2024)  ─────────────────────────────────┐
macOS 14 Sonoma     (2023)  ────────────────────────────┐    │
macOS 13 Ventura    (2022)  ───────────────────────┐    │    │
macOS 12 Monterey   (2021)  ──────────────────┐    │    │    │
macOS 11 Big Sur    (2020)  ─────────────┐    │    │    │    │
macOS 10.15 Catalina (2019) ────────┐    │    │    │    │    │
                                    │    │    │    │    │    │
                                    ▼    ▼    ▼    ▼    ▼    ▼
                              [Storage Management Evolution]
```

## Key Differences by Version

### macOS 15 Sequoia (2024)

#### 새로운 특성

| 특성 | 설명 |
|-----|------|
| Apple Intelligence | AI 기능을 위한 새로운 캐시 시스템 |
| iPhone Mirroring | 연결된 iPhone 데이터 캐시 |
| Enhanced Siri | 확장된 Siri 데이터 캐시 |

#### 알려진 이슈

> **주의**: Sequoia 15.1에서 `mediaanalysisd` 캐시 버그가 발생했습니다.
>
> - 매시간 64MB 캐시 파일 생성
> - 삭제 없이 계속 증가
> - 해결: 15.2 업그레이드

```bash
# 문제 캐시 위치
~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches

# 수동 정리 (15.2 이상에서만)
rm -rf ~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches/*
```

#### 스토리지 설정 접근

```
시스템 설정 → 일반 → 저장 공간
```

---

### macOS 14 Sonoma (2023)

#### 새로운 특성

| 특성 | 설명 |
|-----|------|
| Desktop Widgets | 위젯 캐시 증가 |
| Game Mode | 게임 모드 관련 캐시 |
| Safari Profiles | 프로필별 분리된 캐시 |

#### Safari 변경사항

```bash
# Safari 프로필별 캐시 위치
~/Library/Containers/com.apple.Safari/Data/Library/Caches/
└── [Profile_UUID]/

# 개발자 메뉴 설정 변경
# "개발자 메뉴 보기" → "웹 개발자용 기능 보기"
```

#### 캐시 관리

```bash
# 위젯 캐시
~/Library/Caches/com.apple.WidgetKit/

# 게임 모드 관련
~/Library/Caches/com.apple.GameCenter/
```

---

### macOS 13 Ventura (2022)

#### 주요 변경사항

| 특성 | 설명 |
|-----|------|
| System Settings | 시스템 환경설정 → 시스템 설정 |
| Stage Manager | 새로운 윈도우 관리 시스템 |
| System Data 카테고리 | 스토리지 분류 체계 변경 |

#### 스토리지 설정 접근 변경

```
# Ventura 이전
Apple 메뉴 → 이 Mac에 관하여 → 저장 공간

# Ventura 이후
시스템 설정 → 일반 → 저장 공간
```

#### Stage Manager 캐시

```bash
# Stage Manager 관련 데이터
~/Library/Application Support/com.apple.WindowServer/

# Dock 캐시 (Stage Manager 영향)
~/Library/Caches/com.apple.dock/
```

---

### macOS 12 Monterey (2021)

#### 주요 특성

| 특성 | 설명 |
|-----|------|
| Universal Control | 디바이스 간 캐시 공유 |
| Focus Modes | 집중 모드 설정 데이터 |
| Shortcuts | 단축어 앱 데이터 |

#### System Data 도입

Monterey부터 "Other" 카테고리가 "System Data"로 변경되었습니다.

```
시스템 데이터 구성:
├── Time Machine 로컬 스냅샷
├── 시스템 캐시
├── 임시 파일
├── VM 및 스왑 파일
└── 기타 시스템 데이터
```

#### 정리 도구

```bash
# 단축어 캐시
~/Library/Caches/com.apple.shortcuts/

# Focus 모드 데이터
~/Library/Preferences/com.apple.ncprefs.plist
```

---

### macOS 11 Big Sur (2020)

#### 아키텍처 변경

| 특성 | 설명 |
|-----|------|
| Apple Silicon | M1 칩 도입 |
| Signed System Volume | 시스템 볼륨 서명 |
| APFS Snapshots | 더 적극적인 스냅샷 사용 |

#### 시스템 볼륨 분리

```
Big Sur 이후 볼륨 구조:
├── Macintosh HD (System Volume, 읽기 전용)
└── Macintosh HD - Data (Data Volume, 읽기/쓰기)
```

> **중요**: 시스템 볼륨 수정 불가 (SIP + Sealed System Volume)

#### ARM vs Intel 캐시 차이

```bash
# Rosetta 2 캐시 (Intel 앱용)
/Library/Apple/usr/share/rosetta/

# 네이티브 ARM 캐시
~/Library/Caches/*/
```

---

### macOS 10.15 Catalina (2019)

#### 주요 변경사항

| 특성 | 설명 |
|-----|------|
| 읽기 전용 시스템 볼륨 | 시스템 보안 강화 |
| Zsh 기본 셸 | Bash에서 Zsh로 변경 |
| 32비트 앱 지원 종료 | 레거시 앱 제거 |

#### 볼륨 분리 시작

```
Catalina 볼륨 구조:
├── Macintosh HD (System)
└── Macintosh HD - Data
```

#### 레거시 앱 정리

```bash
# 32비트 앱 식별
mdfind "kMDItemExecutableArchitectures == 'i386' && kMDItemContentType == 'com.apple.application-bundle'"

# 관련 캐시 및 지원 파일 정리
~/Library/Application Support/[32bit_app]/
~/Library/Caches/[32bit_app]/
```

---

## Storage Categories Evolution

### 스토리지 카테고리 변화

| 버전 | 카테고리 구성 |
|-----|--------------|
| Catalina 이전 | Apps, Documents, Other |
| Monterey+ | Apps, Documents, **System Data**, macOS |

### System Data 일반적 크기

| 버전 | 일반적 크기 범위 |
|-----|-----------------|
| Sequoia/Sonoma/Ventura | 12-20GB |
| Monterey | 15-25GB |
| Big Sur | 15-30GB |

### System Data 과다 사용 시

```bash
# System Data 구성 요소 분석
# 1. Time Machine 스냅샷
tmutil listlocalsnapshots /

# 2. VM 파일
ls -lh /private/var/vm/

# 3. 캐시 확인
sudo du -sh /Library/Caches
du -sh ~/Library/Caches
```

## Version-Specific Cleanup Commands

### Sequoia/Sonoma (15.x/14.x)

```bash
#!/bin/bash
# cleanup_modern.sh

# Safari 캐시 정리 (프로필 지원)
rm -rf ~/Library/Containers/com.apple.Safari/Data/Library/Caches/*

# 위젯 캐시
rm -rf ~/Library/Caches/com.apple.WidgetKit/*

# Media Analysis 캐시 (15.2+ 전용)
rm -rf ~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches/*
```

### Ventura/Monterey (13.x/12.x)

```bash
#!/bin/bash
# cleanup_recent.sh

# 일반 캐시 정리
rm -rf ~/Library/Caches/*

# 로그 정리 (30일 이상)
find ~/Library/Logs -mtime +30 -delete

# Shortcuts 캐시
rm -rf ~/Library/Caches/com.apple.shortcuts/*
```

### Big Sur/Catalina (11.x/10.15)

```bash
#!/bin/bash
# cleanup_legacy.sh

# 일반 캐시
rm -rf ~/Library/Caches/*

# Rosetta 캐시 정리 (Big Sur+)
# 주의: 앱 재번역 필요할 수 있음
sudo rm -rf /Library/Apple/usr/share/rosetta/*
```

## Time Machine Local Snapshots

### 버전별 스냅샷 관리

모든 최신 버전에서 동일한 방법 사용:

```bash
# 스냅샷 목록
tmutil listlocalsnapshots /

# 스냅샷 삭제
sudo tmutil deletelocalsnapshots [날짜]

# 모든 로컬 스냅샷 비활성화/재활성화
tmutil thinlocalsnapshots / 9999999999999

# Time Machine 임시 비활성화 (스냅샷 자동 삭제)
# 시스템 설정 → Time Machine → 끄기 → 대기 → 다시 켜기
```

### 스냅샷 공간 관리 정책

| 디스크 사용률 | 동작 |
|-------------|------|
| < 80% | 스냅샷 정상 유지 |
| 80-90% | 낮은 우선순위로 삭제 시작 |
| > 90% | 높은 우선순위로 빠른 삭제 |

## APFS Volume Differences

### APFS 특성 (High Sierra 이후)

| 특성 | 설명 |
|-----|------|
| 공간 공유 | 컨테이너 내 볼륨 간 공간 공유 |
| 스냅샷 | 효율적인 포인트-인-타임 복사 |
| 클론 | Copy-on-Write 파일 복제 |

### 공간 계산 차이

```bash
# 실제 사용 공간 vs 표시 공간이 다를 수 있음
diskutil apfs list

# 컨테이너 정보
diskutil apfs listContainers

# Purgeable 공간 확인
diskutil info / | grep "Purgeable"
```

## Safe Mode Cleanup by Version

모든 버전에서 Safe Mode는 추가 정리 수행:

```
Safe Mode 정리 항목:
├── 폰트 캐시 재구축
├── 커널 캐시 재구축
├── 시스템 캐시 정리
└── Startup Items 검증
```

### Safe Mode 진입

| Mac 유형 | 방법 |
|---------|------|
| Apple Silicon | 종료 → 전원 버튼 길게 → 옵션 → Shift + "Macintosh HD" |
| Intel | 재시동 → Shift 키 누르기 |

## Compatibility Matrix

### 정리 도구 호환성

| 도구/기능 | Catalina | Big Sur | Monterey | Ventura | Sonoma | Sequoia |
|----------|:--------:|:-------:|:--------:|:-------:|:------:|:-------:|
| `tmutil` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 스토리지 관리 | ✅ | ✅ | ✅ | ✅* | ✅* | ✅* |
| `diskutil apfs` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Safe Mode 정리 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

\* UI 경로 변경됨

## Migration Considerations

### 버전 업그레이드 전 정리

```bash
#!/bin/bash
# pre_upgrade_cleanup.sh

echo "=== Pre-Upgrade Cleanup ==="

# 1. 사용자 캐시 정리
rm -rf ~/Library/Caches/*

# 2. 오래된 로그 정리
find ~/Library/Logs -mtime +30 -delete

# 3. Time Machine 스냅샷 정리 (옵션)
# tmutil thinlocalsnapshots / 10000000000

# 4. 휴지통 비우기
rm -rf ~/.Trash/*

# 5. 다운로드 폴더 정리 (오래된 파일)
find ~/Downloads -mtime +90 -delete

echo "=== Cleanup Complete ==="
echo "권장: 업그레이드 전 최소 20GB 여유 공간 확보"
```

## References

- [Apple Support - Time Machine Snapshots](https://support.apple.com/en-us/102154)
- [OSXHub - macOS Storage Cleanup Guide 2025](https://osxhub.com/macos-storage-cleanup-guide-2025/)
- [Dr.Buho - Clear System Storage Mac](https://www.drbuho.com/how-to/clear-system-storage-mac)
- [MacPaw - Optimize macOS Sequoia](https://macpaw.com/how-to/optimize-macos-sequoia)
- [Apple Community - Sequoia System Data](https://discussions.apple.com/thread/255806791)
