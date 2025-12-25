# macOS Temporary Files Reference

> Last Updated: 2025-12-25

## Overview

macOS는 시스템과 애플리케이션 성능 향상을 위해 다양한 임시 파일을 생성합니다. 이 문서는 주요 임시 파일 위치와 그 목적을 설명합니다.

## Primary Temporary File Locations

### 1. /tmp (→ /private/tmp)

| 속성 | 값 |
|-----|-----|
| 경로 | `/tmp` (symlink to `/private/tmp`) |
| 목적 | 시스템 전체 임시 파일 저장소 |
| 권한 | 모든 사용자 접근 가능 (sticky bit 설정) |
| 자동 정리 | 재부팅 시 또는 정기 시스템 작업 |

```bash
# 현재 크기 확인
du -sh /private/tmp

# 내용 확인 (주의: 삭제하지 말 것)
ls -la /private/tmp
```

### 2. /private/var/folders

| 속성 | 값 |
|-----|-----|
| 경로 | `/private/var/folders` |
| 목적 | 사용자별 임시 파일 및 캐시 |
| 하위 구조 | 해시 기반 2단계 디렉토리 |
| 자동 정리 | 매일 새벽 3:35am (3일 미접근 파일 삭제) |

#### 내부 구조

```
/private/var/folders/
├── xx/           # 첫 번째 해시 레벨
│   └── xxxxxxx/  # 두 번째 해시 레벨 (사용자별)
│       ├── C/    # Caches - 캐시 파일
│       ├── T/    # Temporary - 임시 파일
│       └── 0/    # 기타 임시 데이터
```

> **중요**: macOS 10.5부터 도입된 이 구조는 보안 향상을 위해 기존 `/tmp` 및 `/Library/Caches` 대체

### 3. /private/var/tmp

| 속성 | 값 |
|-----|-----|
| 경로 | `/private/var/tmp` |
| 목적 | 재부팅 후에도 유지되는 임시 파일 |
| 자동 정리 | 주기적 시스템 정리 스크립트 |

```bash
# 크기 확인
du -sh /private/var/tmp
```

## User-Level Temporary Locations

### ~/Library/Caches

각 애플리케이션의 캐시 데이터 저장

```bash
# 전체 캐시 크기 확인
du -sh ~/Library/Caches

# 앱별 캐시 크기 (상위 10개)
du -sh ~/Library/Caches/* 2>/dev/null | sort -hr | head -10
```

#### 주요 캐시 디렉토리

| 디렉토리 | 설명 |
|---------|------|
| `com.apple.Safari` | Safari 브라우저 캐시 |
| `com.spotify.client` | Spotify 오프라인 데이터 |
| `com.google.Chrome` | Chrome 브라우저 캐시 |
| `com.apple.bird` | iCloud 동기화 캐시 |
| `CloudKit` | iCloud 메타데이터 캐시 |

### ~/Library/Application Support

애플리케이션 데이터 (영구적이지만 큰 파일 포함 가능)

```bash
# 크기 확인
du -sh ~/Library/Application\ Support

# 대용량 항목 찾기
du -sh ~/Library/Application\ Support/* 2>/dev/null | sort -hr | head -10
```

## Temporary File Types

### 1. 시스템 임시 파일

| 유형 | 위치 | 설명 |
|-----|------|------|
| Sleep Image | `/private/var/vm/sleepimage` | 잠자기 모드 메모리 덤프 |
| Swap Files | `/private/var/vm/swapfile*` | 가상 메모리 스왑 |
| Kernel Caches | `/System/Library/Caches/` | 커널 캐시 (SIP 보호) |

### 2. 애플리케이션 임시 파일

| 유형 | 위치 | 설명 |
|-----|------|------|
| 문서 자동저장 | `~/Library/Autosave Information/` | 미저장 문서 복구용 |
| Saved States | `~/Library/Saved Application State/` | 앱 상태 복원용 |
| Containers | `~/Library/Containers/` | 샌드박스 앱 데이터 |

### 3. 브라우저 임시 파일

| 브라우저 | 캐시 위치 |
|---------|----------|
| Safari | `~/Library/Caches/com.apple.Safari/` |
| Chrome | `~/Library/Caches/Google/Chrome/` |
| Firefox | `~/Library/Caches/Firefox/` |
| Edge | `~/Library/Caches/Microsoft Edge/` |

## Automatic Cleanup Mechanisms

### 1. dirhelper 데몬

```bash
# 담당 프로세스
/usr/libexec/dirhelper

# 실행 스케줄: 매일 새벽 3:35am
# 대상: /private/var/folders 내 3일 이상 미접근 파일
```

### 2. 주기적 시스템 스크립트

```bash
# 일간 작업 (daily)
/etc/periodic/daily/

# 주간 작업 (weekly)
/etc/periodic/weekly/

# 월간 작업 (monthly)
/etc/periodic/monthly/

# 수동 실행
sudo periodic daily weekly monthly
```

### 3. ASL (Apple System Log) 정리

```bash
# 시스템 로그 정리 (7일 이상 된 로그)
# 자동으로 /private/var/log/asl/ 정리
```

## Safe Cleanup Commands

### 권장되는 정리 방법

```bash
# 1. 가장 안전: 재부팅
# 재부팅 시 대부분의 임시 파일 자동 정리

# 2. Safe Mode 부팅 (더 철저한 정리)
# 시작 시 Shift 키 누르기

# 3. 수동으로 주기적 스크립트 실행
sudo periodic daily weekly monthly
```

### 주의사항

> **경고**: `/private/var/folders`나 `/tmp` 내용을 수동으로 삭제하지 마세요.
>
> - 실행 중인 앱이 손상될 수 있음
> - 시스템 불안정 유발 가능
> - 재부팅이 가장 안전한 정리 방법

## Disk Space Analysis Commands

```bash
# 전체 디스크 사용량
df -h /

# 주요 임시 디렉토리 크기
echo "=== Temporary Directories Size ==="
du -sh /private/tmp 2>/dev/null
du -sh /private/var/tmp 2>/dev/null
du -sh /private/var/folders 2>/dev/null
du -sh ~/Library/Caches 2>/dev/null

# 대용량 파일 찾기 (100MB 이상)
sudo find /private/var -size +100M -exec ls -lh {} \; 2>/dev/null
```

## References

- [OSXDaily - Delete Temporary Items](https://osxdaily.com/2016/01/13/delete-temporary-items-private-var-folders-mac-os-x/)
- [iBoysoft - private/var Folder](https://iboysoft.com/wiki/private-var-folder-mac.html)
- [Magnusviri - What is /var/folders](https://magnusviri.com/what-is-var-folders)
- [Apple Community Discussions](https://discussions.apple.com/thread/251685409)
