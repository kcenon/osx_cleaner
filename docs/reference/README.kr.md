# macOS Cleanup Reference Documentation

> Version: 1.1.0
> Last Updated: 2025-12-25

## Overview

이 문서 모음은 macOS 시스템에서 임시 파일, 캐시, 로그 등 불필요한 파일들을 안전하게 정리하기 위한 참조 자료입니다.

## Document Index

### Core Reference (기본 참조)

| # | Document | Description | Primary Use |
|---|----------|-------------|-------------|
| 01 | [Temporary Files](01-temporary-files.md) | 임시 파일 위치 및 유형 분석 | 시스템 이해 |
| 02 | [Cache System](02-cache-system.md) | 캐시 계층 구조 및 관리 방법 | 캐시 정리 |
| 03 | [System Logs](03-system-logs.md) | 로그 파일 위치 및 정리 방법 | 로그 관리 |
| 04 | [Version Differences](04-version-differences.md) | macOS 버전별 차이점 | 호환성 확인 |
| 05 | [Developer Caches](05-developer-caches.md) | 개발 도구 캐시 위치 정보 | 개발자용 |
| 06 | [Safe Cleanup Guide](06-safe-cleanup-guide.md) | 안전한 정리 가이드라인 | 실무 적용 |

### Developer Guide (개발자 가이드)

| # | Document | Description | Primary Use |
|---|----------|-------------|-------------|
| 07 | [Developer Guide](07-developer-guide.md) | 개발자 유형별 정리 전략 | iOS/Web/Backend 개발자 |
| 08 | [Automation Scripts](08-automation-scripts.md) | 자동화 스크립트 모음 | 정기 유지보수 |
| 09 | [CI/CD & Team Guide](09-ci-cd-team-guide.md) | CI/CD 및 팀 환경 관리 | DevOps/팀 리드 |

## Quick Reference

### 안전한 정리 대상 (✅)

```bash
# 즉시 정리 가능
~/Library/Caches/*                    # 사용자 캐시
~/.Trash/*                            # 휴지통
~/Downloads/* (오래된 파일)            # 다운로드
~/Library/Logs/DiagnosticReports/*    # 크래시 리포트
```

### 주의 필요 대상 (⚠️)

```bash
# 앱 종료 후 정리
~/Library/Developer/Xcode/DerivedData/  # Xcode 빌드 캐시
/Library/Caches/*                        # 시스템 캐시 (root 필요)
tmutil deletelocalsnapshots [date]       # Time Machine 스냅샷
```

### 삭제 금지 (❌)

```bash
# 절대 삭제하지 말 것
/System/*
/private/var/folders/* (수동 삭제 금지)
~/Library/Keychains/*
~/Library/Application Support/*
```

## Typical Space Usage

| 항목 | 일반적 크기 | 정리 안전성 |
|-----|-----------|------------|
| 휴지통 | 0-50GB | ✅ 안전 |
| 브라우저 캐시 | 0.5-5GB | ✅ 안전 |
| 사용자 캐시 | 5-30GB | ✅ 안전 |
| 시스템 로그 | 0.5-5GB | ⚠️ 주의 |
| Xcode (개발자) | 20-100GB | ⚠️ 주의 |
| Time Machine 스냅샷 | 10-100GB | ⚠️ 주의 |

## Recommended Cleanup Frequency

| 작업 | 권장 주기 | 예상 시간 |
|-----|----------|----------|
| 휴지통 비우기 | 주 1회 | 즉시 |
| 브라우저 캐시 | 월 1회 | 1분 |
| 다운로드 폴더 정리 | 월 1회 | 5분 |
| 사용자 캐시 전체 | 분기 1회 | 5분 |
| 개발자 도구 정리 | 월 1회 | 10분 |
| Safe Mode 부팅 | 필요 시 | 10분 |

## Quick Start Script

```bash
#!/bin/bash
# quick_cleanup.sh - 안전한 기본 정리

echo "=== macOS Quick Cleanup ==="

# 1. 휴지통
rm -rf ~/.Trash/*

# 2. 브라우저 캐시
rm -rf ~/Library/Caches/com.apple.Safari/WebKitCache/*
rm -rf ~/Library/Caches/Google/Chrome/Default/Cache/*

# 3. 오래된 다운로드 (90일+)
find ~/Downloads -mtime +90 -delete 2>/dev/null

# 4. 오래된 로그 (30일+)
find ~/Library/Logs -mtime +30 -delete 2>/dev/null

echo "Cleanup complete!"
df -h / | tail -1
```

## macOS Version Support

| 버전 | 코드명 | 지원 상태 | 특이사항 |
|-----|-------|----------|---------|
| 15.x | Sequoia | ✅ 완전 지원 | mediaanalysisd 버그 (15.1) |
| 14.x | Sonoma | ✅ 완전 지원 | Safari 프로필 분리 |
| 13.x | Ventura | ✅ 완전 지원 | 시스템 설정 UI 변경 |
| 12.x | Monterey | ✅ 완전 지원 | System Data 도입 |
| 11.x | Big Sur | ✅ 완전 지원 | Apple Silicon 도입 |
| 10.15 | Catalina | ⚠️ 부분 지원 | 볼륨 분리 시작 |

## Related Resources

### Apple Documentation
- [Mac Storage Management](https://support.apple.com/en-us/HT206996)
- [Time Machine Local Snapshots](https://support.apple.com/en-us/102154)
- [Safe Mode](https://support.apple.com/guide/mac-help/mchl0e7fd83d/mac)

### Third-Party Tools
- [DevCleaner for Xcode](https://github.com/vashpan/xcode-dev-cleaner) - Xcode 캐시 관리
- [OnyX](https://titanium-software.fr/en/onyx.html) - 시스템 유지보수
- [DaisyDisk](https://daisydiskapp.com/) - 디스크 사용량 시각화

### Community Resources
- [MacRumors Forums](https://forums.macrumors.com/)
- [Apple Community](https://discussions.apple.com/)

## Contributing

이 문서에 기여하려면:
1. 최신 macOS 버전에서 검증
2. 안전성 레벨 명시
3. 실제 명령어 테스트 후 추가

## Changelog

### v1.1.0 (2025-12-25)
- Added Developer Guide documents (07-09)
- Developer-specific cleanup strategies by role (iOS, Web, Backend)
- Automation scripts with launchd integration
- CI/CD pipeline integration examples (GitHub Actions, Jenkins, Fastlane)
- Team environment management guide

### v0.1.0.0 (2025-12-25)
- Initial documentation release
- 6 reference documents created
- Covers macOS Catalina through Sequoia

---

*이 문서는 시스템 정리를 위한 참조용입니다. 중요한 데이터는 항상 백업 후 작업하세요.*
