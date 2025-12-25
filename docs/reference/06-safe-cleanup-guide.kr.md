# macOS Safe Cleanup Guidelines

> Last Updated: 2025-12-25

## Overview

이 가이드는 macOS에서 안전하게 디스크 공간을 확보하는 방법을 설명합니다. 시스템 안정성을 유지하면서 효과적으로 정리하는 것이 목표입니다.

## Safety Classification

### 위험도 분류

| 레벨 | 설명 | 예시 |
|-----|------|------|
| ✅ **안전** | 자유롭게 삭제 가능, 자동 재생성 | 브라우저 캐시, 앱 캐시 |
| ⚠️ **주의** | 삭제 가능하나 영향 있음 | iOS Device Support, 로그 |
| ❌ **위험** | 삭제 금지, 시스템 손상 가능 | 시스템 파일, SIP 보호 영역 |

---

## Golden Rules

### 1. 수동 삭제보다 재부팅

```
재부팅 > 수동 삭제
```

대부분의 임시 파일은 재부팅 시 자동 정리됩니다.

### 2. 시스템 폴더 손대지 않기

```
절대 수정 금지:
├── /System/
├── /usr/  (단, /usr/local 제외)
├── /bin/
├── /sbin/
└── /private/var/ (대부분)
```

### 3. com.apple.* 주의

`com.apple.*`로 시작하는 항목은 시스템 구성요소일 수 있습니다.

### 4. 백업 후 삭제

중요한 정리 전에는 Time Machine 백업을 권장합니다.

---

## Safe Cleanup Checklist

### 정리 전 확인사항

- [ ] 중요 작업 저장 완료
- [ ] 관련 앱 종료
- [ ] 클라우드 동기화 완료
- [ ] (선택) Time Machine 백업

### 정리 후 확인사항

- [ ] 시스템 정상 부팅
- [ ] 주요 앱 정상 실행
- [ ] 중요 파일 접근 가능

---

## Safe Cleanup Targets

### Level 1: 완전 안전 (✅)

즉시 삭제 가능, 부작용 없음

```bash
#!/bin/bash
# safe_cleanup_level1.sh

# 1. 휴지통 비우기
rm -rf ~/.Trash/*

# 2. 다운로드 폴더 오래된 파일 (90일+)
find ~/Downloads -mtime +90 -delete 2>/dev/null

# 3. 브라우저 캐시
rm -rf ~/Library/Caches/com.apple.Safari/WebKitCache/* 2>/dev/null
rm -rf ~/Library/Caches/Google/Chrome/Default/Cache/* 2>/dev/null
rm -rf ~/Library/Caches/Firefox/Profiles/*/cache2/* 2>/dev/null

# 4. 스크린샷 (30일+)
find ~/Desktop -name "Screenshot*.png" -mtime +30 -delete 2>/dev/null

echo "Level 1 cleanup complete"
```

#### 대상 목록

| 대상 | 위치 | 예상 공간 |
|-----|------|----------|
| 휴지통 | `~/.Trash/` | 변동적 |
| 브라우저 캐시 | `~/Library/Caches/[browser]/` | 0.5-5GB |
| 다운로드 (오래된) | `~/Downloads/` | 변동적 |
| 스크린샷 (오래된) | `~/Desktop/Screenshot*` | 0.1-1GB |
| Mail 다운로드 | `~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads/` | 0.1-1GB |

---

### Level 2: 안전 (⚠️ 약간 주의)

삭제 가능, 약간의 재구축 시간 필요

```bash
#!/bin/bash
# safe_cleanup_level2.sh

# 관련 앱 종료 확인
echo "앱을 종료했는지 확인하세요..."
read -p "계속하려면 Enter를 누르세요..."

# 1. 사용자 캐시 전체
rm -rf ~/Library/Caches/* 2>/dev/null

# 2. 오래된 로그 (30일+)
find ~/Library/Logs -mtime +30 -delete 2>/dev/null

# 3. 크래시 리포트 (오래된)
find ~/Library/Logs/DiagnosticReports -mtime +30 -delete 2>/dev/null

# 4. Saved Application State
rm -rf ~/Library/Saved\ Application\ State/* 2>/dev/null

echo "Level 2 cleanup complete"
echo "참고: 앱 첫 실행 시 약간 느릴 수 있습니다"
```

#### 대상 목록

| 대상 | 위치 | 예상 공간 | 영향 |
|-----|------|----------|------|
| 사용자 캐시 | `~/Library/Caches/` | 5-30GB | 앱 초기 로딩 느림 |
| 오래된 로그 | `~/Library/Logs/` | 0.1-1GB | 과거 문제 추적 불가 |
| Saved State | `~/Library/Saved Application State/` | 0.1-0.5GB | 앱 상태 복원 안됨 |
| Font Cache | `~/Library/Caches/com.apple.FontRegistry/` | 0.01-0.1GB | 폰트 재로딩 |

---

### Level 3: 주의 필요 (⚠️)

삭제 가능하나 시간/데이터 손실 가능

```bash
#!/bin/bash
# careful_cleanup_level3.sh

echo "=== 주의: 이 정리는 데이터 재다운로드가 필요할 수 있습니다 ==="
read -p "계속하려면 'yes'를 입력하세요: " confirm

if [ "$confirm" != "yes" ]; then
    echo "취소됨"
    exit 1
fi

# 1. Xcode Derived Data
rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null

# 2. iOS Device Support (오래된 버전)
# 현재 버전 확인 후 수동 삭제 권장
echo "iOS Device Support 정리는 수동으로 진행하세요"
echo "위치: ~/Library/Developer/Xcode/iOS DeviceSupport/"

# 3. Simulator unavailable 삭제
xcrun simctl delete unavailable 2>/dev/null

# 4. CocoaPods 캐시
rm -rf ~/Library/Caches/CocoaPods/* 2>/dev/null

# 5. Homebrew 오래된 버전
brew cleanup -s 2>/dev/null

echo "Level 3 cleanup complete"
```

#### 대상 목록

| 대상 | 위치 | 예상 공간 | 영향 |
|-----|------|----------|------|
| Xcode Derived Data | `~/Library/Developer/Xcode/DerivedData/` | 5-50GB | 프로젝트 재빌드 필요 |
| iOS Device Support | `~/Library/Developer/Xcode/iOS DeviceSupport/` | 10-50GB | 기기 연결 시 재다운로드 |
| Simulator Runtimes | 시스템 위치 | 5-30GB | 런타임 재다운로드 |
| Docker Images | Docker 관리 | 5-50GB | 이미지 재다운로드 |

---

### Level 4: 시스템 수준 (❌ 비권장)

root 권한 필요, 시스템 불안정 위험

> **경고**: 이 수준의 정리는 일반적으로 권장하지 않습니다.

```bash
#!/bin/bash
# system_cleanup_level4.sh (NOT RECOMMENDED)

echo "=== 경고: 시스템 수준 정리 ==="
echo "이 작업은 시스템을 불안정하게 만들 수 있습니다"
echo "대신 '재부팅' 또는 'Safe Mode'를 권장합니다"
read -p "그래도 계속하려면 'I UNDERSTAND'를 입력하세요: " confirm

if [ "$confirm" != "I UNDERSTAND" ]; then
    echo "취소됨"
    exit 1
fi

# 시스템 캐시 (주의!)
# sudo rm -rf /Library/Caches/*  # 권장하지 않음

# 대신 주기적 스크립트 실행
sudo periodic daily weekly monthly

# Safe Mode 부팅이 더 안전한 대안입니다
```

---

## Recommended Approach

### 단계별 접근법

```
Step 1: 재부팅
    ↓
Step 2: Level 1 정리 (완전 안전)
    ↓
Step 3: 공간 확인
    ↓ (부족하면)
Step 4: Level 2 정리 (안전)
    ↓
Step 5: 공간 확인
    ↓ (부족하면)
Step 6: Safe Mode 부팅
    ↓
Step 7: Level 3 정리 (주의)
```

### 월간 유지보수 루틴

```bash
#!/bin/bash
# monthly_maintenance.sh

echo "=== Monthly macOS Maintenance ==="
echo "Date: $(date)"

# 1. 휴지통 비우기
osascript -e 'tell app "Finder" to empty trash'

# 2. 다운로드 폴더 정리 (90일+)
find ~/Downloads -mtime +90 -delete 2>/dev/null

# 3. 브라우저 캐시 정리
rm -rf ~/Library/Caches/com.apple.Safari/WebKitCache/* 2>/dev/null

# 4. 오래된 로그 정리 (60일+)
find ~/Library/Logs -mtime +60 -delete 2>/dev/null

# 5. 개발자: Homebrew 정리
command -v brew &>/dev/null && brew cleanup -s

# 6. 디스크 사용량 보고
echo ""
echo "=== Current Disk Usage ==="
df -h / | tail -1

echo ""
echo "=== Largest User Directories ==="
du -sh ~/* 2>/dev/null | sort -hr | head -10

echo ""
echo "Maintenance complete!"
```

---

## Time Machine Snapshots

### 안전한 스냅샷 관리

```bash
# 스냅샷 확인
tmutil listlocalsnapshots /

# 특정 스냅샷 삭제
sudo tmutil deletelocalsnapshots 2025-01-15-120000

# 모든 스냅샷 정리 (가장 안전한 방법)
# 시스템 설정 → Time Machine → 끄기 → 5분 대기 → 다시 켜기
```

### 자동 정리 정책

macOS는 디스크 사용률에 따라 자동으로 스냅샷을 관리합니다:
- 80% 이상: 낮은 우선순위로 삭제 시작
- 90% 이상: 높은 우선순위로 빠른 삭제

---

## Safe Mode Cleanup

가장 안전하고 효과적인 시스템 정리 방법

### 진입 방법

**Apple Silicon (M1/M2/M3):**
1. Mac 종료
2. 전원 버튼 길게 누르기 (시동 옵션 표시까지)
3. 시동 디스크 선택 후 Shift 누른 채 "Continue in Safe Mode" 클릭

**Intel Mac:**
1. Mac 시작/재시작
2. 즉시 Shift 키 누르기
3. 로그인 창이 나타날 때까지 유지

### Safe Mode에서 정리되는 항목

- 시스템 캐시
- 폰트 캐시
- 커널 캐시
- 일부 임시 파일

### 권장 사용 시점

- 시스템이 느려졌을 때
- 앱 충돌이 자주 발생할 때
- 디스크 공간이 급격히 감소했을 때

---

## What NOT to Delete

### 절대 삭제 금지

```
❌ 삭제 금지 목록:
├── /System/
├── /usr/bin/, /usr/sbin/
├── /private/var/db/
├── /private/var/folders/  (수동 삭제 금지)
├── ~/Library/Preferences/  (설정 손실)
├── ~/Library/Application Support/  (앱 데이터 손실)
├── ~/Library/Keychains/  (암호 손실)
├── ~/Library/Mail/  (이메일 손실)
└── ~/Library/Messages/  (메시지 손실)
```

### 주의해서 다룰 항목

```
⚠️ 주의 필요:
├── ~/Library/Containers/  (샌드박스 앱 데이터)
├── ~/Library/Group Containers/  (공유 앱 데이터)
├── /Library/Caches/  (시스템 캐시)
└── /private/var/log/  (문제 진단용)
```

---

## Recovery Options

### 실수로 삭제한 경우

1. **휴지통 확인**: 최근 삭제 항목 복원
2. **Time Machine**: 이전 버전 복원
3. **앱 재설치**: 앱 데이터 재생성
4. **Recovery Mode**: 심각한 문제 시

### Recovery Mode 진입

**Apple Silicon:**
1. Mac 종료
2. 전원 버튼 길게 누르기
3. "Options" 선택

**Intel:**
1. Mac 재시작
2. Command + R 누르기

---

## Monitoring Tools

### 내장 도구

```bash
# 디스크 사용량
df -h /

# 폴더별 사용량
du -sh ~/*

# 시스템 정보
system_profiler SPStorageDataType
```

### 스토리지 관리

```
시스템 설정 → 일반 → 저장 공간 → 권장 사항
```

권장 사항에서 제공하는 옵션:
- iCloud에 저장
- 저장 공간 최적화
- 휴지통 자동 비우기
- 혼잡 줄이기

---

## Emergency Cleanup

디스크 거의 가득 찬 경우 (< 5GB)

```bash
#!/bin/bash
# emergency_cleanup.sh

echo "=== Emergency Disk Cleanup ==="

# 1. 휴지통 즉시 비우기
rm -rf ~/.Trash/* 2>/dev/null

# 2. 다운로드 폴더 대용량 파일
find ~/Downloads -size +100M -delete 2>/dev/null

# 3. 브라우저 캐시
rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null
rm -rf ~/Library/Caches/Google/Chrome/* 2>/dev/null

# 4. Xcode (개발자용)
rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null

# 5. 현재 공간 확인
echo ""
echo "Current free space:"
df -h / | awk 'NR==2 {print $4}'
```

---

## Summary

### 정리 우선순위

1. **재부팅** - 가장 안전하고 효과적
2. **휴지통 비우기** - 즉시 공간 확보
3. **브라우저 캐시** - 안전하고 효과적
4. **다운로드 폴더** - 오래된 파일 정리
5. **사용자 캐시** - 앱 종료 후 정리
6. **개발자 캐시** - Xcode, npm 등

### 피해야 할 것

1. `/private/var/folders/` 수동 삭제
2. 시스템 폴더 수정
3. 실행 중인 앱 캐시 삭제
4. `com.apple.*` 무분별한 삭제

---

## References

- [Apple Support - Mac Storage](https://support.apple.com/en-us/HT206996)
- [Apple Support - Safe Mode](https://support.apple.com/guide/mac-help/mchl0e7fd83d/mac)
- [OSXDaily - Safe Cleanup](https://osxdaily.com/2016/01/13/delete-temporary-items-private-var-folders-mac-os-x/)
- [MacPaw - Cache Cleanup Safety](https://macpaw.com/how-to/clear-cache-on-mac)
