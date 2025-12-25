# macOS System Logs and Reports

> Last Updated: 2025-12-25

## Overview

macOS는 시스템 안정성 분석, 문제 해결, 보안 감사를 위해 광범위한 로그 시스템을 유지합니다. 이러한 로그 파일들은 시간이 지나면서 상당한 디스크 공간을 차지할 수 있습니다.

## Log File Hierarchy

```
┌────────────────────────────────────────────────────────┐
│                    System Logs                          │
│              /private/var/log/                          │
│              (Root Required)                            │
└────────────────────────┬───────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
┌────────┴────────┐             ┌───────┴────────┐
│   User Logs     │             │  Crash Reports │
│ ~/Library/Logs  │             │ ~/Library/Logs │
│                 │             │ /DiagnosticRep │
└─────────────────┘             └────────────────┘
```

## System Logs (/private/var/log)

### 위치 및 특성

| 속성 | 값 |
|-----|-----|
| 경로 | `/private/var/log` (symlink: `/var/log`) |
| 권한 | root 필요 |
| 자동 정리 | newsyslog, aslmanager에 의해 관리 |
| 일반적 크기 | 0.5-5GB |

### 주요 시스템 로그 파일

| 파일/디렉토리 | 설명 | 정리 안전성 |
|--------------|------|------------|
| `system.log` | 주요 시스템 이벤트 | ⚠️ 진단용으로 유지 권장 |
| `wifi.log` | Wi-Fi 연결 로그 | ✅ 안전 |
| `install.log` | 설치 기록 | ⚠️ 문제 해결용 유지 |
| `asl/` | Apple System Log 아카이브 | ✅ 오래된 것만 |
| `DiagnosticMessages/` | 진단 메시지 | ✅ 안전 |
| `powermanagement/` | 전원 관리 로그 | ✅ 안전 |
| `CoreDuet/` | Siri/검색 관련 | ✅ 안전 |

### 로그 크기 확인

```bash
# 전체 시스템 로그 크기
sudo du -sh /private/var/log

# 개별 로그 크기
sudo du -sh /private/var/log/* | sort -hr

# ASL 아카이브 크기
sudo du -sh /private/var/log/asl
```

## User Logs (~/Library/Logs)

### 위치 및 특성

| 속성 | 값 |
|-----|-----|
| 경로 | `~/Library/Logs` |
| 권한 | 사용자 접근 가능 |
| 자동 정리 | 앱에 따라 다름 |
| 일반적 크기 | 0.1-2GB |

### 주요 사용자 로그

| 디렉토리 | 설명 | 삭제 안전성 |
|---------|------|------------|
| `DiagnosticReports/` | 크래시 리포트 | ✅ 안전 |
| `CoreSimulator/` | iOS 시뮬레이터 로그 | ✅ 안전 |
| `JetBrains/` | IntelliJ, PyCharm 등 | ✅ 안전 |
| `Homebrew/` | Homebrew 로그 | ✅ 안전 |
| `com.apple.Commerce/` | App Store 로그 | ✅ 안전 |

### 크기 확인 및 분석

```bash
# 사용자 로그 전체 크기
du -sh ~/Library/Logs

# 앱별 로그 크기
du -sh ~/Library/Logs/* 2>/dev/null | sort -hr | head -10

# 크래시 리포트 크기
du -sh ~/Library/Logs/DiagnosticReports
```

## Crash Reports

### 위치

| 유형 | 경로 |
|-----|------|
| 사용자 크래시 리포트 | `~/Library/Logs/DiagnosticReports/` |
| 시스템 크래시 리포트 | `/Library/Logs/DiagnosticReports/` |
| 커널 패닉 리포트 | `/Library/Logs/DiagnosticReports/` |

### 크래시 리포트 파일 형식

| 확장자 | 설명 |
|-------|------|
| `.crash` | 일반 앱 크래시 |
| `.spin` | 응답 없음 (spinning) |
| `.hang` | 앱 행 |
| `.panic` | 커널 패닉 |
| `.diag` | 시스템 진단 |

### 크래시 리포트 분석

```bash
# 최근 크래시 리포트 확인
ls -lt ~/Library/Logs/DiagnosticReports/ | head -10

# 특정 앱 크래시 기록 찾기
ls ~/Library/Logs/DiagnosticReports/ | grep -i "safari"

# 크래시 리포트 내용 확인
cat ~/Library/Logs/DiagnosticReports/Safari_*.crash | head -50
```

## Console App을 통한 로그 관리

Console 앱은 macOS의 내장 로그 뷰어입니다.

### 사용 방법

1. `/Applications/Utilities/Console.app` 실행
2. 왼쪽 사이드바에서 로그 유형 선택:
   - **Log Reports**: 시스템 로그
   - **Crash Reports**: 크래시 리포트
   - **Spin Reports**: 응답 없음 리포트
   - **Diagnostic Reports**: 진단 리포트

### Console에서 정리

1. 항목 우클릭 → "Reveal in Finder"
2. Finder에서 삭제
3. 또는 우클릭 → "Move to Trash"

## Unified Logging System

### macOS 10.12+의 새 로깅 시스템

macOS Sierra부터 Apple은 통합 로깅 시스템을 도입했습니다.

```bash
# 실시간 로그 스트리밍
log stream

# 특정 프로세스 로그
log stream --predicate 'processImagePath CONTAINS "Safari"'

# 저장된 로그 검색
log show --last 1h

# 로그 내보내기
log collect --last 1h --output ~/Desktop/logs.logarchive
```

### 로그 아카이브 위치

```bash
# 시스템 로그 데이터베이스
/var/db/diagnostics/

# 타임머신 로그 아카이브
/var/db/diagnostics/Persist/
```

## Safe Log Cleanup

### 사용자 로그 정리

```bash
#!/bin/bash
# cleanup_user_logs.sh

echo "=== User Logs Cleanup ==="

# 30일 이상 된 크래시 리포트 삭제
find ~/Library/Logs/DiagnosticReports -mtime +30 -delete

# 빈 로그 파일 삭제
find ~/Library/Logs -type f -empty -delete

# 전체 로그 크기 표시
echo "Remaining logs size:"
du -sh ~/Library/Logs

echo "Cleanup complete"
```

### 시스템 로그 정리 (주의 필요)

```bash
#!/bin/bash
# cleanup_system_logs.sh (root 필요)

echo "=== System Logs Cleanup ==="

# ASL 로그 정리 (7일 이상)
sudo find /private/var/log/asl -mtime +7 -delete

# 오래된 시스템 로그 압축
sudo gzip /private/var/log/*.log.*[0-9]

# 로그 회전 강제 실행
sudo newsyslog -Fv

echo "Cleanup complete"
```

## Log Rotation Configuration

### newsyslog.conf

```bash
# 설정 파일 위치
/etc/newsyslog.conf
/etc/newsyslog.d/

# 현재 설정 확인
cat /etc/newsyslog.conf
```

### 주요 설정 필드

| 필드 | 설명 |
|-----|------|
| logfile | 로그 파일 경로 |
| mode | 새 파일 권한 |
| count | 유지할 아카이브 수 |
| size | 회전 트리거 크기 |
| when | 회전 스케줄 |

## ASL (Apple System Logger)

### ASL 데이터베이스

```bash
# ASL 저장 위치
/private/var/log/asl/

# ASL 크기 확인
sudo du -sh /private/var/log/asl

# ASL 로그 읽기
syslog -d /private/var/log/asl
```

### aslmanager 설정

```bash
# 설정 파일
/etc/asl/

# ASL 정리 정책 확인
cat /etc/asl/com.apple.system
```

## Diagnostics and Usage Data

### 시스템 진단 데이터

```bash
# 위치
/private/var/db/diagnostics/

# 크기 확인
sudo du -sh /private/var/db/diagnostics
```

### 사용 데이터 및 분석

시스템 설정에서 관리:
- **시스템 설정 → 개인 정보 보호 및 보안 → 분석 및 개선**
- "Mac 분석 공유" 끄기 → 향후 수집 중단

## Space Recovery Estimates

| 로그 유형 | 예상 정리 공간 | 위험도 |
|----------|--------------|--------|
| 크래시 리포트 | 100MB - 1GB | ✅ 낮음 |
| 사용자 앱 로그 | 200MB - 2GB | ✅ 낮음 |
| 시스템 로그 (오래된) | 500MB - 3GB | ⚠️ 중간 |
| ASL 아카이브 | 100MB - 500MB | ⚠️ 중간 |
| 진단 데이터 | 100MB - 1GB | ⚠️ 중간 |

## Monitoring Script

```bash
#!/bin/bash
# log_monitor.sh

echo "=== macOS Log Status Report ==="
echo "Date: $(date)"
echo ""

echo "User Logs:"
du -sh ~/Library/Logs 2>/dev/null

echo ""
echo "User Crash Reports:"
ls ~/Library/Logs/DiagnosticReports/*.crash 2>/dev/null | wc -l | xargs echo "Count:"
du -sh ~/Library/Logs/DiagnosticReports 2>/dev/null

echo ""
echo "System Logs (requires sudo):"
sudo du -sh /private/var/log 2>/dev/null

echo ""
echo "Top 5 Largest Log Directories:"
du -sh ~/Library/Logs/* 2>/dev/null | sort -hr | head -5
```

## Best Practices

### 정기 정리 권장사항

| 로그 유형 | 권장 정리 주기 | 방법 |
|----------|--------------|------|
| 크래시 리포트 | 월 1회 | 30일 이상 된 것 삭제 |
| 앱 로그 | 분기 1회 | 사용하지 않는 앱 로그 삭제 |
| 시스템 로그 | 연 1회 | newsyslog 자동 관리 신뢰 |

### 문제 해결 전 주의사항

> **경고**: 로그를 삭제하기 전에 현재 문제가 없는지 확인하세요.
>
> - 앱 크래시가 반복되는 경우 → 로그 유지
> - 시스템 불안정 시 → 로그 유지
> - 정상 작동 중 → 정리 가능

## References

- [Apple - Console App](https://support.apple.com/guide/console/)
- [MacKeeper - Delete Mac Log Files](https://mackeeper.com/blog/how-to-delete-mac-log-files/)
- [AppleInsider - Delete macOS Logs](https://appleinsider.com/inside/macos/tips/how-to-delete-macos-logs-and-crash-reports)
- [iBoysoft - Mac System Log Files](https://iboysoft.com/wiki/mac-system-log-files.html)
