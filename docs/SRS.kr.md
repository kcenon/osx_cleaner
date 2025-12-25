# OSX Cleaner - Software Requirements Specification (SRS)

> **Version**: 0.1.0.0
> **Created**: 2025-12-25
> **Status**: Draft
> **Related PRD**: [PRD.md](PRD.md) v0.1.0.0

---

## Document Control

### Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 0.1.0.0 | 2025-12-25 | - | Initial SRS based on PRD v0.1.0.0 |

### Requirements ID Convention

| Prefix | Category | Example |
|--------|----------|---------|
| `SRS-FR-Fxx-nnn` | Functional Requirement | SRS-FR-F01-001 |
| `SRS-NFR-xxx-nnn` | Non-Functional Requirement | SRS-NFR-SEC-001 |
| `SRS-IR-xxx-nnn` | Interface Requirement | SRS-IR-CLI-001 |
| `SRS-DR-nnn` | Data Requirement | SRS-DR-001 |
| `SRS-CR-nnn` | Constraint Requirement | SRS-CR-001 |

---

## 1. Introduction

### 1.1 Purpose

이 문서는 OSX Cleaner 소프트웨어의 상세 기술 요구사항을 정의합니다. PRD(Product Requirements Document)에서 정의된 비즈니스 요구사항을 구현 가능한 기술 명세로 변환합니다.

**주요 독자**:
- 개발팀 (Backend, Frontend, QA)
- 시스템 아키텍트
- 테스트 엔지니어
- 프로젝트 관리자

### 1.2 Scope

**시스템 명칭**: OSX Cleaner

**시스템 범위**:
- macOS 10.15 (Catalina) ~ 15.x (Sequoia) 지원
- CLI(Command Line Interface) 및 GUI(Graphical User Interface) 제공
- 로컬 시스템 정리 기능 (네트워크 기능 없음)
- launchd 기반 자동화 지원

**범위 외 항목**:
- Windows/Linux 지원
- 클라우드 기반 원격 관리 (Phase 4 이후)
- 파일 복구 기능

### 1.3 Definitions, Acronyms, and Abbreviations

| 용어 | 정의 |
|-----|------|
| **DerivedData** | Xcode 빌드 과정에서 생성되는 중간 파일 저장소 |
| **Device Support** | iOS 기기 디버깅을 위한 심볼 파일 |
| **SIP** | System Integrity Protection - macOS 시스템 보호 메커니즘 |
| **APFS** | Apple File System - macOS High Sierra 이후 기본 파일 시스템 |
| **launchd** | macOS의 서비스/작업 관리 데몬 |
| **TCC** | Transparency, Consent, and Control - macOS 권한 관리 프레임워크 |
| **FDA** | Full Disk Access - 전체 디스크 접근 권한 |
| **Cleanup Level** | 정리 강도를 나타내는 레벨 (Light, Normal, Deep, System) |
| **Safety Level** | 삭제 안전도 (Safe, Caution, Warning, Danger) |

### 1.4 References

| 문서 | 버전 | 설명 |
|-----|------|------|
| PRD.md | 0.1.0.0 | Product Requirements Document |
| 01-temporary-files.md | 0.1.0.0 | 임시 파일 위치 참조 |
| 02-cache-system.md | 0.1.0.0 | 캐시 시스템 참조 |
| 06-safe-cleanup-guide.md | 0.1.0.0 | 안전한 정리 가이드 |

### 1.5 Document Overview

| Section | Content |
|---------|---------|
| Section 2 | 전반적 시스템 설명 |
| Section 3 | 기능 요구사항 (Functional Requirements) |
| Section 4 | 비기능 요구사항 (Non-Functional Requirements) |
| Section 5 | 인터페이스 요구사항 (Interface Requirements) |
| Section 6 | 데이터 요구사항 (Data Requirements) |
| Section 7 | 제약 조건 (Constraints) |
| Section 8 | 추적성 매트릭스 (Traceability Matrix) |

---

## 2. Overall Description

### 2.1 System Perspective

```
┌─────────────────────────────────────────────────────────────────┐
│                         OSX Cleaner                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐          │
│  │   CLI App   │    │   GUI App   │    │  launchd    │          │
│  │ (osxcleaner)│    │  (SwiftUI)  │    │   Agent     │          │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘          │
│         │                  │                  │                  │
│         └────────────┬─────┴─────────────────┘                  │
│                      │                                           │
│              ┌───────▼───────┐                                   │
│              │  Core Engine  │                                   │
│              │  (Rust/Swift) │                                   │
│              └───────┬───────┘                                   │
│                      │                                           │
│    ┌─────────────────┼─────────────────┐                        │
│    │                 │                 │                        │
│ ┌──▼───┐    ┌───────▼───────┐    ┌────▼────┐                   │
│ │Safety│    │    Cleaner    │    │Analyzer │                   │
│ │Module│    │    Module     │    │ Module  │                   │
│ └──────┘    └───────────────┘    └─────────┘                   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      macOS System                                │
├─────────────────────────────────────────────────────────────────┤
│  ~/Library/Caches  │  ~/Library/Developer  │  /private/var     │
│  ~/Library/Logs    │  Docker/node_modules  │  Time Machine     │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 System Functions Summary

| Function | PRD Reference | Description |
|----------|---------------|-------------|
| Safety Verification | F01 | 삭제 전 안전성 검증 |
| Developer Cache Cleanup | F02 | Xcode, npm, Docker 등 개발 도구 캐시 정리 |
| Browser/App Cache Cleanup | F03 | 브라우저 및 일반 앱 캐시 정리 |
| Log Management | F04 | 로그 및 크래시 리포트 관리 |
| Time Machine Management | F05 | 로컬 스냅샷 관리 |
| Disk Analysis | F06 | 디스크 사용량 분석 및 시각화 |
| Automation | F07 | launchd 기반 자동 정리 |
| CI/CD Integration | F08 | 빌드 파이프라인 통합 |
| Team Management | F09 | 팀 환경 관리 |
| Version Optimization | F10 | macOS 버전별 최적화 |

### 2.3 User Classes and Characteristics

| User Class | Technical Level | Primary Use | PRD Persona |
|------------|-----------------|-------------|-------------|
| iOS Developer | High | Xcode, Simulator 정리 | Persona 1 |
| Full-Stack Developer | High | Docker, node_modules 정리 | Persona 2 |
| DevOps Engineer | High | CI/CD 빌드 머신 관리 | Persona 3 |
| Power User | Medium | 브라우저, 일반 앱 캐시 | Persona 4 |
| System Administrator | High | 다중 머신 관리 | (Enterprise) |

### 2.4 Operating Environment

| Component | Requirement |
|-----------|-------------|
| Operating System | macOS 10.15 Catalina ~ 15.x Sequoia |
| Architecture | Intel x64, Apple Silicon (arm64) |
| Memory | 4GB RAM (minimum), 8GB+ (recommended) |
| Disk Space | 50MB (application), 500MB (working space) |
| Shell | zsh (default), bash (supported) |
| Xcode CLT | Required for iOS developer features |

### 2.5 Design and Implementation Constraints

| ID | Constraint | Rationale |
|----|------------|-----------|
| SRS-CR-001 | SIP 보호 영역 접근 불가 | macOS 시스템 보안 정책 |
| SRS-CR-002 | TCC 권한 필요 | Full Disk Access 요구 |
| SRS-CR-003 | 비동기 I/O 필수 | 대용량 파일 처리 성능 |
| SRS-CR-004 | Sandbox 호환성 | App Store 배포 시 제약 |

### 2.6 Assumptions and Dependencies

**Assumptions**:
1. 사용자는 관리자 권한 보유
2. 시스템은 정상 작동 상태
3. 충분한 여유 공간 존재 (최소 500MB)

**Dependencies**:
| Dependency | Purpose | Required |
|------------|---------|----------|
| xcrun | iOS Simulator 관리 | Optional |
| docker | Docker 정리 | Optional |
| brew | Homebrew 정리 | Optional |
| tmutil | Time Machine 관리 | Yes |
| osascript | 알림 표시 | Yes |

---

## 3. Functional Requirements

### 3.1 F01: Safety-Based Cleanup System

> **PRD Reference**: Section 4.2

#### SRS-FR-F01-001: Safety Level Classification

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F01-001 |
| **Priority** | P0 (Critical) |
| **Source** | PRD F01, Section 4.2.1 |

**Description**: 시스템은 모든 정리 대상에 대해 4단계 안전성 분류를 수행해야 한다.

**Input**: 파일/디렉토리 경로

**Processing**:
1. 경로를 보호 목록(PROTECTED_PATHS)과 대조
2. 경로를 경고 목록(WARNING_PATHS)과 대조
3. 파일 유형 및 수정일 분석
4. 안전성 레벨 결정

**Output**: Safety Level (SAFE | CAUTION | WARNING | DANGER)

**Safety Level Definitions**:

```
enum SafetyLevel {
    SAFE      = 1,  // ✅ 즉시 삭제 가능
    CAUTION   = 2,  // ⚠️ 삭제 가능, 재구축 시간 필요
    WARNING   = 3,  // ⚠️⚠️ 삭제 가능, 데이터 재다운로드 필요
    DANGER    = 4   // ❌ 삭제 금지
}
```

**Validation Rules**:
- DANGER 레벨 항목은 삭제 시도 시 오류 반환
- WARNING 레벨 항목은 사용자 확인 필수

---

#### SRS-FR-F01-002: Protected Path Enforcement

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F01-002 |
| **Priority** | P0 (Critical) |
| **Source** | PRD F01, Section 6.1.1 |

**Description**: 시스템은 보호된 경로에 대한 삭제 요청을 거부해야 한다.

**Protected Paths (Hardcoded)**:
```
PROTECTED_PATHS = [
    "/System/",
    "/usr/bin/",
    "/usr/sbin/",
    "/bin/",
    "/sbin/",
    "/private/var/db/",
    "/private/var/folders/",
    "~/Library/Keychains/",
    "~/Library/Application Support/",  # 전체 삭제 금지
    "~/Library/Mail/",
    "~/Library/Messages/",
    "~/Library/Preferences/"           # 전체 삭제 금지
]
```

**Behavior**:
- 보호 경로 삭제 시도 → Error Code: `E_PROTECTED_PATH`
- 로그에 시도 기록
- 사용자에게 경고 메시지 표시

---

#### SRS-FR-F01-003: Running Application Detection

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F01-003 |
| **Priority** | P1 (High) |
| **Source** | PRD F01, Section 4.2.2 |

**Description**: 시스템은 실행 중인 앱의 캐시 삭제 전 경고해야 한다.

**Input**: 삭제 대상 캐시 경로

**Processing**:
1. 캐시 경로에서 Bundle ID 추출 (예: `com.apple.Safari`)
2. `pgrep` 또는 `lsof`로 실행 중인 프로세스 확인
3. 실행 중이면 경고 표시

**Output**:
- Running: true/false
- Process Name: string
- PID: number (if running)

**User Interaction**:
```
⚠️ Safari가 실행 중입니다.
   캐시 삭제 시 예기치 않은 동작이 발생할 수 있습니다.

   [앱 종료 후 삭제] [강제 삭제] [취소]
```

---

#### SRS-FR-F01-004: Cleanup Level Selection

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F01-004 |
| **Priority** | P0 (Critical) |
| **Source** | PRD F01, Section 4.2.3 |

**Description**: 시스템은 4단계 정리 레벨을 제공해야 한다.

**Cleanup Levels**:

| Level | Name | Safety | Targets |
|-------|------|--------|---------|
| 1 | Light | SAFE only | 휴지통, 브라우저 캐시, 90일+ 다운로드 |
| 2 | Normal | SAFE + CAUTION | Level 1 + 사용자 캐시, 30일+ 로그 |
| 3 | Deep | SAFE + CAUTION + WARNING | Level 2 + 개발자 캐시, Docker |
| 4 | System | All (NOT RECOMMENDED) | Level 3 + 시스템 캐시 (root) |

**Level Inheritance**:
- Level N은 Level 1 ~ Level N-1의 모든 타겟 포함
- 상위 레벨은 하위 레벨의 확장

---

#### SRS-FR-F01-005: Pre-Cleanup Confirmation

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F01-005 |
| **Priority** | P1 (High) |
| **Source** | PRD F01, Section 6.2 |

**Description**: Level 2 이상 정리 시 사용자 확인을 요구해야 한다.

**Confirmation Dialog Content**:
1. 삭제 예정 항목 요약
2. 예상 확보 공간
3. 잠재적 영향 설명
4. Time Machine 마지막 백업 시간 (존재 시)

**CLI Format**:
```
=== OSX Cleaner: Normal Cleanup ===

다음 항목이 정리됩니다:
  • 사용자 캐시: 15.2GB (245개 앱)
  • 오래된 로그: 890MB (30일+)
  • 크래시 리포트: 120MB

예상 확보 공간: 16.2GB

⚠️ 주의: 일부 앱의 첫 실행이 느려질 수 있습니다.
⏰ 마지막 Time Machine 백업: 2시간 전

계속하시겠습니까? [y/N]:
```

---

### 3.2 F02: Developer Tools Cache Management

> **PRD Reference**: Section 4.3

#### SRS-FR-F02-001: Xcode DerivedData Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F02-001 |
| **Priority** | P0 (Critical) |
| **Source** | PRD F02, Section 4.3.1 |

**Description**: Xcode DerivedData 디렉토리를 정리해야 한다.

**Target Paths**:
```
~/Library/Developer/Xcode/DerivedData/
~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/
```

**Cleanup Options**:

| Option | Description | Command |
|--------|-------------|---------|
| All | 전체 삭제 | `rm -rf ~/Library/Developer/Xcode/DerivedData/*` |
| Project | 특정 프로젝트만 | `rm -rf ~/Library/Developer/Xcode/DerivedData/{project}-*` |
| Old | 30일+ 미접근 | `find ... -atime +30 -delete` |

**Size Estimation**:
- Average: 5-50GB
- Calculation: `du -sh` 실행

---

#### SRS-FR-F02-002: iOS Simulator Management

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F02-002 |
| **Priority** | P1 (High) |
| **Source** | PRD F02, Section 4.3.2 |

**Description**: iOS Simulator 디바이스 및 런타임을 관리해야 한다.

**Operations**:

| Operation | Command | Safety |
|-----------|---------|--------|
| List Devices | `xcrun simctl list devices` | N/A |
| Delete Unavailable | `xcrun simctl delete unavailable` | SAFE |
| Delete Specific | `xcrun simctl delete [UDID]` | CAUTION |
| Erase All | `xcrun simctl erase all` | WARNING |
| List Runtimes | `xcrun simctl runtime list` | N/A |
| Delete Runtime | `xcrun simctl runtime delete [ID]` | WARNING |

**Error Handling**:
- Xcode CLT 미설치 시: `E_XCODE_NOT_FOUND`
- xcrun 실행 실패 시: `E_SIMCTL_FAILED`

---

#### SRS-FR-F02-003: iOS Device Support Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F02-003 |
| **Priority** | P1 (High) |
| **Source** | PRD F02, Section 4.3.1 |

**Description**: 오래된 iOS Device Support 파일을 정리해야 한다.

**Target Path**:
```
~/Library/Developer/Xcode/iOS DeviceSupport/
~/Library/Developer/Xcode/watchOS DeviceSupport/
```

**Cleanup Strategy**:
1. 현재 연결된 기기 iOS 버전 확인 (system_profiler)
2. 최근 2개 major 버전만 유지 권장
3. 사용자에게 버전별 크기 표시 후 선택 삭제

**Output Format**:
```
iOS Device Support 분석:
  ✓ 18.1 (19B81)       - 4.2GB  [현재 사용 중]
  ✓ 17.5 (21F90)       - 4.1GB  [최근 사용]
  ? 16.4 (20E247)      - 3.8GB  [90일 미사용]
  ? 15.7 (19H357)      - 3.5GB  [180일 미사용]

삭제할 버전을 선택하세요 (번호, 쉼표 구분):
```

---

#### SRS-FR-F02-004: Package Manager Cache Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F02-004 |
| **Priority** | P0 (Critical) |
| **Source** | PRD F02, Section 4.3.3 |

**Description**: 패키지 관리자 캐시를 정리해야 한다.

**Supported Package Managers**:

| Manager | Detection | Cache Path | Cleanup Method |
|---------|-----------|------------|----------------|
| CocoaPods | `command -v pod` | `~/Library/Caches/CocoaPods/` | `pod cache clean --all` |
| SPM | Always | `~/Library/Caches/org.swift.swiftpm/` | Direct delete |
| Carthage | `command -v carthage` | `~/Library/Caches/org.carthage.CarthageKit/` | Direct delete |
| npm | `command -v npm` | `~/.npm/` | `npm cache clean --force` |
| yarn | `command -v yarn` | `$(yarn cache dir)` | `yarn cache clean` |
| pnpm | `command -v pnpm` | `$(pnpm store path)` | `pnpm store prune` |
| pip | `command -v pip3` | `~/Library/Caches/pip/` | `pip cache purge` |
| Homebrew | `command -v brew` | `$(brew --cache)` | `brew cleanup -s` |

**Fallback**: 명령어 실패 시 직접 `rm -rf` 수행

---

#### SRS-FR-F02-005: Docker Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F02-005 |
| **Priority** | P1 (High) |
| **Source** | PRD F02, Section 4.3.4 |

**Description**: Docker 리소스를 정리해야 한다.

**Prerequisites**:
- Docker Desktop 실행 중
- `docker` 명령어 사용 가능

**Cleanup Levels**:

| Level | Command | Description | Safety |
|-------|---------|-------------|--------|
| Basic | `docker system prune -f` | 중지된 컨테이너, dangling 이미지 | CAUTION |
| Images | `docker image prune -a` | 모든 미사용 이미지 | WARNING |
| Volumes | `docker volume prune -f` | 미사용 볼륨 | WARNING |
| Builder | `docker builder prune -f` | 빌드 캐시 | CAUTION |
| Full | `docker system prune -a --volumes` | 전체 정리 | WARNING |

**Pre-Cleanup Info**:
```
Docker 사용량:
  Images:       12.5GB (15개)
  Containers:   2.1GB (3개 중지)
  Volumes:      8.3GB (5개)
  Build Cache:  4.2GB
  ─────────────────────────
  Total:        27.1GB
```

---

#### SRS-FR-F02-006: node_modules Discovery and Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F02-006 |
| **Priority** | P1 (High) |
| **Source** | PRD F02, Section 4.3 (implied) |

**Description**: 분산된 node_modules 디렉토리를 검색하고 정리해야 한다.

**Discovery Algorithm**:
```bash
find ~/{Projects,Developer,Sources,repos,code} \
    -name "node_modules" \
    -type d \
    -prune \
    2>/dev/null
```

**Output Format**:
```
node_modules 검색 결과 (~/Projects 기준):

 SIZE     LAST ACCESS    PATH
 ──────   ────────────   ─────────────────────────────────
 1.2GB    3일 전         ~/Projects/webapp/node_modules
 890MB    45일 전        ~/Projects/old-project/node_modules
 2.1GB    120일 전       ~/Projects/archived/node_modules
 ──────
 4.2GB    총 3개

[전체 삭제] [오래된 것만 (30일+)] [선택 삭제] [취소]
```

---

#### SRS-FR-F02-007: IDE Cache Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F02-007 |
| **Priority** | P2 (Medium) |
| **Source** | PRD F02, Section 4.3 (implied) |

**Description**: IDE 캐시를 정리해야 한다.

**Supported IDEs**:

| IDE | Cache Paths |
|-----|-------------|
| VS Code | `~/Library/Application Support/Code/Cache/`<br>`~/Library/Application Support/Code/CachedData/`<br>`~/Library/Application Support/Code/CachedExtensionVSIXs/` |
| JetBrains | `~/Library/Caches/JetBrains/IntelliJIdea*/`<br>`~/Library/Caches/JetBrains/PyCharm*/`<br>`~/Library/Caches/JetBrains/WebStorm*/` |
| Xcode | `~/Library/Developer/Xcode/DerivedData/` (SRS-FR-F02-001) |

---

### 3.3 F03: Browser/App Cache Cleanup

> **PRD Reference**: Section 4.4

#### SRS-FR-F03-001: Browser Cache Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F03-001 |
| **Priority** | P0 (Critical) |
| **Source** | PRD F03, Section 4.4.1 |

**Description**: 주요 브라우저 캐시를 정리해야 한다.

**Browser Definitions**:

| Browser | Bundle ID | Cache Paths | Safety |
|---------|-----------|-------------|--------|
| Safari | `com.apple.Safari` | `~/Library/Caches/com.apple.Safari/`<br>`~/Library/Caches/com.apple.Safari/WebKitCache/` | SAFE |
| Chrome | `com.google.Chrome` | `~/Library/Caches/Google/Chrome/`<br>`~/Library/Caches/Google/Chrome/Default/Cache/` | SAFE |
| Firefox | `org.mozilla.firefox` | `~/Library/Caches/Firefox/`<br>`~/Library/Caches/Firefox/Profiles/*/cache2/` | SAFE |
| Edge | `com.microsoft.edgemac` | `~/Library/Caches/Microsoft Edge/`<br>`~/Library/Caches/Microsoft Edge/Default/Cache/` | SAFE |
| Arc | `company.thebrowser.Browser` | `~/Library/Caches/company.thebrowser.Browser/` | SAFE |

**Pre-Cleanup Check**:
- SRS-FR-F01-003 (Running App Detection) 적용
- 브라우저 실행 중이면 경고

---

#### SRS-FR-F03-002: Application Cache Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F03-002 |
| **Priority** | P1 (High) |
| **Source** | PRD F03, Section 4.4 |

**Description**: 일반 애플리케이션 캐시를 정리해야 한다.

**Target Path**: `~/Library/Caches/*`

**Exclusion Rules**:
```
CACHE_EXCLUSIONS = [
    "com.apple.Photos",      # 사진 라이브러리 손상 위험
    "com.apple.CloudKit",    # iCloud 동기화 문제
    "com.apple.bird",        # iCloud Drive 캐시
    "Metadata",              # Spotlight 관련
    "CloudKit"               # CloudKit 메타데이터
]
```

**Processing**:
1. `~/Library/Caches/` 하위 디렉토리 열거
2. 제외 목록과 대조
3. 앱별 크기 계산
4. 사용자에게 목록 표시 (선택적)
5. 확인 후 삭제

---

#### SRS-FR-F03-003: Cloud Service Cache Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F03-003 |
| **Priority** | P2 (Medium) |
| **Source** | PRD F03, Section 4.4.2 |

**Description**: 클라우드 서비스 캐시를 안전하게 정리해야 한다.

**Cloud Services**:

| Service | Cache Path | Pre-Check |
|---------|------------|-----------|
| iCloud | `~/Library/Caches/com.apple.bird/` | 동기화 상태 확인 |
| Dropbox | `~/Library/Caches/com.getdropbox.dropbox/` | 동기화 상태 확인 |
| OneDrive | `~/Library/Caches/com.microsoft.OneDrive/` | 동기화 상태 확인 |
| Google Drive | `~/Library/Caches/com.google.GoogleDrive/` | 스트리밍 파일 확인 |

**Safety Level**: CAUTION (동기화 확인 필요)

---

### 3.4 F04: Log and Crash Report Management

> **PRD Reference**: Section 4.5

#### SRS-FR-F04-001: User Log Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F04-001 |
| **Priority** | P1 (High) |
| **Source** | PRD F04, Section 4.5.1 |

**Description**: 사용자 로그 파일을 정리해야 한다.

**Target Paths**:
```
~/Library/Logs/
~/Library/Logs/DiagnosticReports/
```

**Age-Based Cleanup**:
```bash
# 30일 이상 된 로그 파일 삭제
find ~/Library/Logs -type f -mtime +30 -delete

# 빈 디렉토리 정리
find ~/Library/Logs -type d -empty -delete
```

**Cleanup Options**:

| Option | Age Threshold | Target |
|--------|---------------|--------|
| Recent | 7+ days | 일주일 이상 |
| Normal | 30+ days | 한 달 이상 (기본값) |
| Deep | All | 전체 |

---

#### SRS-FR-F04-002: Crash Report Cleanup

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F04-002 |
| **Priority** | P1 (High) |
| **Source** | PRD F04, Section 4.5.1 |

**Description**: 크래시 리포트를 정리해야 한다.

**Target Paths**:
```
~/Library/Logs/DiagnosticReports/*.crash
~/Library/Logs/DiagnosticReports/*.spin
~/Library/Logs/DiagnosticReports/*.hang
~/Library/Logs/DiagnosticReports/*.diag
```

**Pre-Cleanup Analysis**:
- 앱별 크래시 횟수 집계
- 반복 크래시 앱 식별 및 경고

**Output**:
```
크래시 리포트 분석:
  Safari: 3개 (최근: 2일 전)
  Xcode: 12개 (최근: 오늘)  ⚠️ 반복 크래시
  Finder: 1개 (최근: 45일 전)

30일 이상 된 리포트: 8개 (2.3MB)
```

---

### 3.5 F05: Time Machine Snapshot Management

> **PRD Reference**: Section 4.6

#### SRS-FR-F05-001: Snapshot Listing

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F05-001 |
| **Priority** | P1 (High) |
| **Source** | PRD F05, Section 4.6.1 |

**Description**: 로컬 Time Machine 스냅샷 목록을 조회해야 한다.

**Command**: `tmutil listlocalsnapshots /`

**Output Parsing**:
```
com.apple.TimeMachine.2025-01-15-120000.local
com.apple.TimeMachine.2025-01-14-180000.local
...
```

**Display Format**:
```
Time Machine 로컬 스냅샷:
  DATE                    AGE         EST. SIZE
  ────────────────────    ─────────   ─────────
  2025-01-15 12:00:00     3시간 전    ~2.1GB
  2025-01-14 18:00:00     21시간 전   ~1.8GB
  2025-01-13 12:00:00     2일 전      ~3.2GB
  ────────────────────────────────────────────
  Total: 3 snapshots, estimated ~7.1GB
```

---

#### SRS-FR-F05-002: Snapshot Deletion

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F05-002 |
| **Priority** | P1 (High) |
| **Source** | PRD F05, Section 4.6.1 |

**Description**: 특정 또는 전체 스냅샷을 삭제해야 한다.

**Commands**:
```bash
# 특정 스냅샷 삭제
sudo tmutil deletelocalsnapshots 2025-01-15-120000

# 공간 확보를 위한 스냅샷 축소
tmutil thinlocalsnapshots / 9999999999999
```

**Safety Level**: CAUTION (복구 불가)

**Pre-Deletion Warning**:
```
⚠️ 경고: Time Machine 스냅샷 삭제

   삭제하면 해당 시점으로 복원할 수 없습니다.
   외부 Time Machine 백업은 영향받지 않습니다.

   [삭제 진행] [취소]
```

---

### 3.6 F06: Disk Analysis and Visualization

> **PRD Reference**: Section 4.7

#### SRS-FR-F06-001: Disk Usage Analysis

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F06-001 |
| **Priority** | P1 (High) |
| **Source** | PRD F06, Section 4.7.2 |

**Description**: 디스크 사용량을 분석해야 한다.

**Analysis Targets**:

| Target | Path | Method |
|--------|------|--------|
| User Home | `~/*` | `du -sh` |
| User Caches | `~/Library/Caches/*` | `du -sh` per app |
| Developer | `~/Library/Developer/*` | `du -sh` per component |
| Docker | Docker API | `docker system df` |
| node_modules | Discovered paths | `du -sh` per project |

**Output Structure**:
```typescript
interface DiskAnalysis {
    totalSize: number;           // bytes
    freeSpace: number;           // bytes
    usedSpace: number;           // bytes
    usagePercent: number;        // 0-100
    categories: Category[];
}

interface Category {
    name: string;
    size: number;
    percentage: number;
    safetyLevel: SafetyLevel;
    cleanable: boolean;
    items: Item[];
}
```

---

#### SRS-FR-F06-002: Cleanup Estimation

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F06-002 |
| **Priority** | P1 (High) |
| **Source** | PRD F06, Section 4.7.1 |

**Description**: 정리 가능 공간을 안전성 레벨별로 추정해야 한다.

**Estimation Categories**:

| Category | Calculation | Display |
|----------|-------------|---------|
| Safe Total | Sum of SAFE items | ✅ 즉시 정리 가능 |
| Caution Total | Sum of CAUTION items | ⚠️ 주의 필요 |
| Warning Total | Sum of WARNING items | ⚠️⚠️ 재다운로드 필요 |

**Accuracy Note**: 실제 정리 결과는 추정치와 다를 수 있음 (파일 공유, APFS 클론 등)

---

#### SRS-FR-F06-003: Progress Visualization (CLI)

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F06-003 |
| **Priority** | P2 (Medium) |
| **Source** | PRD F06, Section 4.7.1 |

**Description**: CLI에서 진행 상황을 시각적으로 표시해야 한다.

**Progress Bar Format**:
```
정리 중... [████████████░░░░░░░░] 60% (15.2GB / 25.3GB)
  현재: ~/Library/Caches/com.spotify.client/
```

**Category Progress**:
```
카테고리별 사용량:
  Xcode & Simulators ████████████████░░░░  80GB (16%)
  User Caches        ██████████░░░░░░░░░░  50GB (10%)
  Docker             ██████░░░░░░░░░░░░░░  30GB (6%)
```

---

### 3.7 F07: Automation Scheduling

> **PRD Reference**: Section 4.8

#### SRS-FR-F07-001: launchd Agent Installation

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F07-001 |
| **Priority** | P1 (High) |
| **Source** | PRD F07, Section 4.8.2 |

**Description**: launchd 에이전트를 설치하여 자동 정리를 스케줄링해야 한다.

**Agent Location**: `~/Library/LaunchAgents/`

**Agent Template**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.osxcleaner.{schedule}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/osxcleaner</string>
        <string>--level</string>
        <string>{level}</string>
        <string>--non-interactive</string>
        <string>--log</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <!-- Schedule-specific keys -->
    </dict>
    <key>StandardOutPath</key>
    <string>~/Library/Logs/osxcleaner/{schedule}.log</string>
    <key>StandardErrorPath</key>
    <string>~/Library/Logs/osxcleaner/{schedule}.error.log</string>
</dict>
</plist>
```

**Management Commands**:
```bash
# 설치
osxcleaner schedule --add daily --level light

# 제거
osxcleaner schedule --remove daily

# 목록
osxcleaner schedule --list
```

---

#### SRS-FR-F07-002: Schedule Options

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F07-002 |
| **Priority** | P1 (High) |
| **Source** | PRD F07, Section 4.8.1 |

**Description**: 다양한 스케줄 옵션을 제공해야 한다.

**Predefined Schedules**:

| Schedule | Timing | Default Level |
|----------|--------|---------------|
| daily | 매일 03:00 | Light |
| weekly | 매주 일요일 04:00 | Normal |
| monthly | 매월 1일 05:00 | Deep |

**Custom Schedule**:
```bash
osxcleaner schedule --add custom \
    --weekday 0,3 \
    --hour 3 \
    --minute 30 \
    --level normal
```

---

#### SRS-FR-F07-003: Disk Usage Alert

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F07-003 |
| **Priority** | P1 (High) |
| **Source** | PRD F07, Section 4.8.3 |

**Description**: 디스크 사용률이 임계값을 초과하면 알림을 표시해야 한다.

**Threshold Configuration**:
```json
{
    "alert_threshold": 85,
    "critical_threshold": 95,
    "auto_cleanup_on_critical": false
}
```

**Alert Methods**:
1. macOS Notification Center
2. Terminal bell (CLI)
3. Log file entry

**Notification Content**:
```
⚠️ 디스크 공간 경고

디스크 사용률이 87%입니다.
여유 공간: 41GB

[정리 실행] [무시]
```

---

### 3.8 F08: CI/CD Pipeline Integration

> **PRD Reference**: Section 4.9

#### SRS-FR-F08-001: Non-Interactive Mode

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F08-001 |
| **Priority** | P2 (Medium) |
| **Source** | PRD F08, Section 4.9.2 |

**Description**: CI/CD 환경에서 사용자 입력 없이 실행 가능해야 한다.

**CLI Flag**: `--non-interactive` 또는 `-y`

**Behavior**:
- 모든 확인 프롬프트 자동 승인
- 진행 상황은 stdout으로 출력
- 오류는 stderr로 출력
- Exit code로 결과 전달

**Exit Codes**:
| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Partial success (일부 항목 실패) |
| 2 | Invalid arguments |
| 3 | Permission denied |
| 4 | Disk full |
| 5 | Protected path violation attempt |

---

#### SRS-FR-F08-002: Machine-Readable Output

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F08-002 |
| **Priority** | P2 (Medium) |
| **Source** | PRD F08 |

**Description**: CI/CD 파싱을 위한 JSON 출력을 지원해야 한다.

**CLI Flag**: `--json` 또는 `--output json`

**Output Schema**:
```json
{
    "version": "0.1.0.0",
    "timestamp": "2025-01-15T12:00:00Z",
    "level": "deep",
    "status": "success",
    "summary": {
        "space_before": 385000000000,
        "space_after": 343000000000,
        "space_freed": 42000000000,
        "items_processed": 1523,
        "items_failed": 2
    },
    "categories": [
        {
            "name": "xcode_derived_data",
            "size_freed": 25000000000,
            "items": 45
        }
    ],
    "errors": [
        {
            "path": "/path/to/file",
            "error": "Permission denied"
        }
    ]
}
```

---

#### SRS-FR-F08-003: Disk Space Check Mode

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F08-003 |
| **Priority** | P2 (Medium) |
| **Source** | PRD F08, Section 4.9.2 |

**Description**: 정리 없이 디스크 상태만 확인하는 모드를 제공해야 한다.

**CLI Usage**:
```bash
osxcleaner check --min-free 20G --json
```

**Output**:
```json
{
    "status": "warning",
    "free_space": 15000000000,
    "required_space": 20000000000,
    "usage_percent": 88,
    "recommendation": "cleanup_required"
}
```

**Exit Codes (Check Mode)**:
| Code | Condition |
|------|-----------|
| 0 | Free space >= threshold |
| 1 | Free space < threshold |

---

### 3.9 F09: Team Environment Management

> **PRD Reference**: Section 4.9 (implied)

#### SRS-FR-F09-001: Multi-User Awareness

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F09-001 |
| **Priority** | P3 (Low) |
| **Source** | PRD F09 |

**Description**: 공유 머신에서 다른 사용자 세션을 인식해야 한다.

**Check**:
```bash
who | wc -l  # 로그인된 사용자 수
```

**Warning**:
```
⚠️ 다른 사용자가 로그인 중입니다 (2명).
   시스템 캐시 정리는 권장하지 않습니다.
```

---

### 3.10 F10: macOS Version Optimization

> **PRD Reference**: Section 4.10

#### SRS-FR-F10-001: Version Detection

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F10-001 |
| **Priority** | P1 (High) |
| **Source** | PRD F10, Section 4.10.1 |

**Description**: 현재 macOS 버전을 감지하고 버전별 최적화를 적용해야 한다.

**Detection Method**:
```bash
sw_vers -productVersion  # e.g., "15.2"
```

**Version Mapping**:

| Version Range | Codename | Special Handling |
|---------------|----------|------------------|
| 15.x | Sequoia | `mediaanalysisd` 캐시, AI 캐시 |
| 14.x | Sonoma | Safari 프로필별 경로 |
| 13.x | Ventura | 시스템 설정 경로 변경 |
| 12.x | Monterey | System Data 카테고리 |
| 11.x | Big Sur | Rosetta 캐시 (Intel 앱) |
| 10.15 | Catalina | 볼륨 분리, 레거시 앱 |

---

#### SRS-FR-F10-002: Sequoia-Specific Fixes

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F10-002 |
| **Priority** | P1 (High) |
| **Source** | PRD F10, Section 4.10.1 |

**Description**: macOS Sequoia 15.1의 `mediaanalysisd` 버그를 처리해야 한다.

**Bug**: 매시간 64MB 캐시 파일 생성, 자동 삭제 안됨

**Affected Path**:
```
~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches/
```

**Fix Condition**: macOS 15.1.x에서만 자동 정리 권장

---

#### SRS-FR-F10-003: Architecture Detection

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-FR-F10-003 |
| **Priority** | P2 (Medium) |
| **Source** | PRD F10 |

**Description**: CPU 아키텍처를 감지하고 관련 캐시를 식별해야 한다.

**Detection**:
```bash
uname -m  # arm64 or x86_64
```

**Apple Silicon Specific**:
- Rosetta 캐시: `/Library/Apple/usr/share/rosetta/`
- Universal 바이너리 관련

---

## 4. Non-Functional Requirements

### 4.1 Performance Requirements

#### SRS-NFR-PERF-001: Cleanup Execution Time

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-PERF-001 |
| **Priority** | P1 |
| **Source** | PRD Section 7.1 |

**Requirements**:
| Cleanup Level | Max Time | Condition |
|---------------|----------|-----------|
| Light | 2 minutes | Up to 10GB cleanup |
| Normal | 5 minutes | Up to 30GB cleanup |
| Deep | 10 minutes | Up to 100GB cleanup |

**Measurement**: Wall-clock time from start to completion

---

#### SRS-NFR-PERF-002: Memory Usage

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-PERF-002 |
| **Priority** | P1 |
| **Source** | PRD Section 7.2 |

**Requirements**:
- Peak memory usage: < 100MB
- Idle memory usage: < 20MB
- No memory leaks over 1-hour operation

---

#### SRS-NFR-PERF-003: Disk I/O Efficiency

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-PERF-003 |
| **Priority** | P2 |

**Requirements**:
- 비동기 I/O 사용
- 단일 파일 삭제는 동기, 대량 삭제는 병렬 처리
- 디스크 스로틀링: 최대 I/O 대역폭의 50% 이내

---

### 4.2 Security Requirements

#### SRS-NFR-SEC-001: Privilege Escalation

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-SEC-001 |
| **Priority** | P0 |
| **Source** | PRD Section 5.3 |

**Requirements**:
- 최소 권한 원칙 적용
- sudo는 시스템 캐시 정리 시에만 요청
- 권한 상승 이유를 사용자에게 명시

---

#### SRS-NFR-SEC-002: Audit Logging

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-SEC-002 |
| **Priority** | P1 |
| **Source** | PRD Section 5.3.2 |

**Requirements**:
- 모든 삭제 작업 로깅
- 로그 위치: `~/Library/Logs/osxcleaner/`
- 로그 보존: 최소 30일

**Log Format**:
```
[2025-01-15T12:00:00Z] [INFO] DELETE ~/Library/Caches/com.spotify.client/ (1.2GB)
[2025-01-15T12:00:01Z] [WARN] SKIP ~/Library/Caches/com.apple.bird/ (running)
[2025-01-15T12:00:02Z] [ERROR] FAIL /protected/path (E_PROTECTED_PATH)
```

---

#### SRS-NFR-SEC-003: Input Validation

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-SEC-003 |
| **Priority** | P0 |

**Requirements**:
- 경로 트래버설 공격 방지 (`../` 차단)
- 심볼릭 링크 대상 검증
- 특수 문자 이스케이프

---

### 4.3 Reliability Requirements

#### SRS-NFR-REL-001: Error Recovery

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-REL-001 |
| **Priority** | P1 |

**Requirements**:
- 단일 파일 삭제 실패 시 계속 진행
- 치명적 오류 시 현재 상태 저장 후 종료
- 재시작 시 이전 세션 복구 가능

---

#### SRS-NFR-REL-002: False Positive Prevention

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-REL-002 |
| **Priority** | P0 |
| **Source** | PRD Section 7.2 |

**Requirements**:
- False Positive Rate < 0.1%
- 의심스러운 경우 삭제하지 않음 (Fail-safe)
- 사용자 피드백 수집 메커니즘

---

### 4.4 Usability Requirements

#### SRS-NFR-USE-001: CLI Usability

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-USE-001 |
| **Priority** | P1 |

**Requirements**:
- `--help` 옵션으로 모든 명령어 설명 제공
- 명확한 진행률 표시
- 색상 코딩 지원 (터미널 지원 시)
- 국제화 지원 (한국어, 영어)

---

#### SRS-NFR-USE-002: Error Messages

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-USE-002 |
| **Priority** | P1 |

**Requirements**:
- 오류 메시지는 원인과 해결 방법 포함
- 에러 코드 제공
- 상세 정보는 `--verbose` 모드에서 표시

**Example**:
```
❌ 오류: 시스템 캐시에 접근할 수 없습니다 (E_PERMISSION_DENIED)

   해결 방법:
   1. sudo osxcleaner --level system 으로 재실행
   2. 또는 시스템 설정 > 개인정보 보호 > Full Disk Access에서
      osxcleaner 권한 부여
```

---

### 4.5 Compatibility Requirements

#### SRS-NFR-COMP-001: macOS Version Support

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-COMP-001 |
| **Priority** | P0 |
| **Source** | PRD Section 5.1 |

**Requirements**:
| Version | Support Level |
|---------|---------------|
| 15.x Sequoia | Full |
| 14.x Sonoma | Full |
| 13.x Ventura | Full |
| 12.x Monterey | Full |
| 11.x Big Sur | Full |
| 10.15 Catalina | Partial (no ARM) |

---

#### SRS-NFR-COMP-002: Shell Compatibility

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-COMP-002 |
| **Priority** | P1 |

**Requirements**:
- zsh (macOS default): Full support
- bash: Full support
- POSIX sh: Core features only

---

### 4.6 Maintainability Requirements

#### SRS-NFR-MAINT-001: Modularity

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-MAINT-001 |
| **Priority** | P2 |

**Requirements**:
- 정리 대상별 독립 모듈
- 새 정리 대상 추가 시 기존 코드 수정 최소화
- 설정 파일 기반 확장

---

#### SRS-NFR-MAINT-002: Configuration

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-NFR-MAINT-002 |
| **Priority** | P2 |

**Configuration File**: `~/.config/osxcleaner/config.yaml`

**Schema**:
```yaml
version: 1
cleanup:
  default_level: normal
  confirm_level: 2  # Level 2+ requires confirmation

schedule:
  enabled: true
  daily: light
  weekly: normal

alerts:
  threshold: 85
  critical: 95

exclusions:
  paths:
    - "~/Library/Caches/com.example.app/"
  patterns:
    - "*.important"
```

---

## 5. Interface Requirements

### 5.1 Command Line Interface

#### SRS-IR-CLI-001: Main Command Structure

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-CLI-001 |
| **Priority** | P0 |

**Command Format**:
```
osxcleaner [command] [options]
```

**Commands**:
| Command | Description |
|---------|-------------|
| `clean` | 정리 실행 (기본) |
| `analyze` | 분석만 수행 |
| `check` | 디스크 상태 확인 |
| `schedule` | 스케줄 관리 |
| `config` | 설정 관리 |
| `version` | 버전 정보 |
| `help` | 도움말 |

---

#### SRS-IR-CLI-002: Clean Command Options

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-CLI-002 |
| **Priority** | P0 |

**Options**:
```
osxcleaner clean [options]

Options:
  -l, --level <level>     정리 레벨 (light|normal|deep|system)
  -y, --non-interactive   사용자 입력 없이 실행
  -n, --dry-run           실제 삭제 없이 미리보기
  -v, --verbose           상세 출력
  -q, --quiet             최소 출력
  --json                  JSON 형식 출력
  --include <category>    특정 카테고리만 포함
  --exclude <category>    특정 카테고리 제외
  --older-than <days>     지정일 이상 된 파일만

Categories:
  browser, developer, logs, docker, homebrew, trash, downloads
```

---

#### SRS-IR-CLI-003: Analyze Command

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-CLI-003 |
| **Priority** | P1 |

**Usage**:
```
osxcleaner analyze [options]

Options:
  --top <n>     상위 n개 항목만 표시 (기본: 10)
  --sort <by>   정렬 기준 (size|name|date)
  --json        JSON 출력
```

---

#### SRS-IR-CLI-004: Schedule Command

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-CLI-004 |
| **Priority** | P1 |

**Usage**:
```
osxcleaner schedule <action> [options]

Actions:
  list          등록된 스케줄 목록
  add           스케줄 추가
  remove        스케줄 제거
  enable        스케줄 활성화
  disable       스케줄 비활성화

Options (add):
  --name <name>     스케줄 이름 (daily|weekly|monthly|custom)
  --level <level>   정리 레벨
  --weekday <0-6>   요일 (0=일요일)
  --hour <0-23>     시간
  --minute <0-59>   분
```

---

### 5.2 Graphical User Interface (Phase 3)

#### SRS-IR-GUI-001: Main Window Layout

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-GUI-001 |
| **Priority** | P3 |

**Components**:
1. **Header**: 디스크 사용량 요약, 여유 공간
2. **Category List**: 정리 가능 카테고리 트리
3. **Detail Panel**: 선택 카테고리 상세 정보
4. **Action Bar**: 정리 실행, 설정 버튼
5. **Status Bar**: 진행률, 마지막 정리 시간

---

### 5.3 System Interfaces

#### SRS-IR-SYS-001: File System Interface

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-SYS-001 |
| **Priority** | P0 |

**Operations**:
| Operation | API |
|-----------|-----|
| File size | `stat()` / `FileManager.attributesOfItem` |
| Directory traversal | `readdir()` / `FileManager.contentsOfDirectory` |
| File deletion | `unlink()` / `FileManager.removeItem` |
| Symlink resolution | `realpath()` / `FileManager.destinationOfSymbolicLink` |

---

#### SRS-IR-SYS-002: Process Interface

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-SYS-002 |
| **Priority** | P1 |

**Used For**: 실행 중인 앱 감지

**Methods**:
```bash
pgrep -l [process_name]
lsof +D [directory]
```

---

#### SRS-IR-SYS-003: Notification Interface

| Attribute | Value |
|-----------|-------|
| **ID** | SRS-IR-SYS-003 |
| **Priority** | P2 |

**macOS Notification Center**:
```bash
osascript -e 'display notification "message" with title "title"'
```

**User Notification Framework** (Swift):
```swift
UNUserNotificationCenter.current().requestAuthorization(...)
```

---

## 6. Data Requirements

### 6.1 Data Entities

#### SRS-DR-001: Cleanup Target

```typescript
interface CleanupTarget {
    id: string;                    // Unique identifier
    path: string;                  // Absolute path
    type: "file" | "directory";
    size: number;                  // bytes
    modifiedAt: Date;
    accessedAt: Date;
    safetyLevel: SafetyLevel;
    category: CleanupCategory;
    cleanable: boolean;
    reason?: string;               // If not cleanable
}
```

---

#### SRS-DR-002: Cleanup Session

```typescript
interface CleanupSession {
    id: string;                    // UUID
    startedAt: Date;
    completedAt?: Date;
    level: CleanupLevel;
    status: "running" | "completed" | "failed" | "cancelled";
    spaceBefore: number;
    spaceAfter?: number;
    itemsProcessed: number;
    itemsFailed: number;
    errors: CleanupError[];
}
```

---

#### SRS-DR-003: Configuration

```typescript
interface Configuration {
    version: number;
    cleanup: {
        defaultLevel: CleanupLevel;
        confirmLevel: number;
        dryRunDefault: boolean;
    };
    schedule: {
        enabled: boolean;
        daily?: CleanupLevel;
        weekly?: CleanupLevel;
        monthly?: CleanupLevel;
    };
    alerts: {
        threshold: number;        // Percentage
        critical: number;
        autoCleanup: boolean;
    };
    exclusions: {
        paths: string[];
        patterns: string[];
    };
}
```

---

### 6.2 Data Storage

#### SRS-DR-004: Local Storage

| Data | Location | Format |
|------|----------|--------|
| Configuration | `~/.config/osxcleaner/config.yaml` | YAML |
| Session Logs | `~/Library/Logs/osxcleaner/` | Plain text |
| Cache | `~/Library/Caches/osxcleaner/` | Binary |
| State | `~/.local/state/osxcleaner/` | JSON |

---

### 6.3 Data Retention

| Data Type | Retention Period |
|-----------|------------------|
| Session Logs | 30 days |
| Error Logs | 90 days |
| Cache | Until next run |
| Configuration | Permanent |

---

## 7. Constraints

### 7.1 Technical Constraints

| ID | Constraint | Impact |
|----|------------|--------|
| SRS-CR-001 | SIP 보호 영역 접근 불가 | `/System/`, `/usr/` 정리 불가 |
| SRS-CR-002 | TCC 권한 시스템 | Full Disk Access 필요 |
| SRS-CR-003 | App Sandbox (MAS) | 제한된 경로 접근 |
| SRS-CR-004 | APFS 클론 | 표시 크기와 실제 공간 차이 가능 |

### 7.2 Business Constraints

| ID | Constraint | Impact |
|----|------------|--------|
| SRS-CR-005 | 오픈소스 라이선스 | 의존성 라이선스 호환성 확인 |
| SRS-CR-006 | App Store 정책 | 시스템 유틸리티 제한 |

---

## 8. Traceability Matrix

### 8.1 PRD → SRS Mapping

| PRD Feature | SRS Requirements |
|-------------|------------------|
| **F01** Safety System | SRS-FR-F01-001 ~ SRS-FR-F01-005 |
| **F02** Developer Cache | SRS-FR-F02-001 ~ SRS-FR-F02-007 |
| **F03** Browser/App Cache | SRS-FR-F03-001 ~ SRS-FR-F03-003 |
| **F04** Log Management | SRS-FR-F04-001 ~ SRS-FR-F04-002 |
| **F05** Time Machine | SRS-FR-F05-001 ~ SRS-FR-F05-002 |
| **F06** Disk Analysis | SRS-FR-F06-001 ~ SRS-FR-F06-003 |
| **F07** Automation | SRS-FR-F07-001 ~ SRS-FR-F07-003 |
| **F08** CI/CD | SRS-FR-F08-001 ~ SRS-FR-F08-003 |
| **F09** Team Env | SRS-FR-F09-001 |
| **F10** Version Opt | SRS-FR-F10-001 ~ SRS-FR-F10-003 |

### 8.2 Requirements Summary

| Category | Count | Priority Distribution |
|----------|-------|----------------------|
| Functional (FR) | 28 | P0: 8, P1: 14, P2: 5, P3: 1 |
| Non-Functional (NFR) | 14 | P0: 4, P1: 7, P2: 3 |
| Interface (IR) | 10 | P0: 3, P1: 3, P2: 2, P3: 2 |
| Data (DR) | 4 | - |
| Constraint (CR) | 6 | - |
| **Total** | **62** | |

### 8.3 Complete Traceability Matrix

| SRS ID | PRD Section | Priority | Phase |
|--------|-------------|----------|-------|
| SRS-FR-F01-001 | 4.2.1 | P0 | 1 |
| SRS-FR-F01-002 | 6.1.1 | P0 | 1 |
| SRS-FR-F01-003 | 4.2.2 | P1 | 1 |
| SRS-FR-F01-004 | 4.2.3 | P0 | 1 |
| SRS-FR-F01-005 | 6.2 | P1 | 1 |
| SRS-FR-F02-001 | 4.3.1 | P0 | 1 |
| SRS-FR-F02-002 | 4.3.2 | P1 | 1 |
| SRS-FR-F02-003 | 4.3.1 | P1 | 1 |
| SRS-FR-F02-004 | 4.3.3 | P0 | 1 |
| SRS-FR-F02-005 | 4.3.4 | P1 | 1 |
| SRS-FR-F02-006 | 4.3 | P1 | 1 |
| SRS-FR-F02-007 | 4.3 | P2 | 2 |
| SRS-FR-F03-001 | 4.4.1 | P0 | 1 |
| SRS-FR-F03-002 | 4.4 | P1 | 1 |
| SRS-FR-F03-003 | 4.4.2 | P2 | 2 |
| SRS-FR-F04-001 | 4.5.1 | P1 | 1 |
| SRS-FR-F04-002 | 4.5.1 | P1 | 1 |
| SRS-FR-F05-001 | 4.6.1 | P1 | 2 |
| SRS-FR-F05-002 | 4.6.1 | P1 | 2 |
| SRS-FR-F06-001 | 4.7.2 | P1 | 1 |
| SRS-FR-F06-002 | 4.7.1 | P1 | 1 |
| SRS-FR-F06-003 | 4.7.1 | P2 | 2 |
| SRS-FR-F07-001 | 4.8.2 | P1 | 2 |
| SRS-FR-F07-002 | 4.8.1 | P1 | 2 |
| SRS-FR-F07-003 | 4.8.3 | P1 | 2 |
| SRS-FR-F08-001 | 4.9.2 | P2 | 2 |
| SRS-FR-F08-002 | 4.9 | P2 | 2 |
| SRS-FR-F08-003 | 4.9.2 | P2 | 2 |
| SRS-FR-F09-001 | 4.9 | P3 | 3 |
| SRS-FR-F10-001 | 4.10.1 | P1 | 1 |
| SRS-FR-F10-002 | 4.10.1 | P1 | 1 |
| SRS-FR-F10-003 | 4.10 | P2 | 2 |

---

## Appendix A: Error Codes

| Code | Name | Description |
|------|------|-------------|
| E_SUCCESS | Success | 작업 성공 |
| E_PARTIAL | Partial Success | 일부 항목 실패 |
| E_INVALID_ARGS | Invalid Arguments | 잘못된 인자 |
| E_PERMISSION_DENIED | Permission Denied | 권한 부족 |
| E_DISK_FULL | Disk Full | 디스크 여유 공간 부족 |
| E_PROTECTED_PATH | Protected Path | 보호 경로 접근 시도 |
| E_APP_RUNNING | App Running | 앱 실행 중 |
| E_NOT_FOUND | Not Found | 파일/디렉토리 없음 |
| E_IO_ERROR | I/O Error | 입출력 오류 |
| E_XCODE_NOT_FOUND | Xcode Not Found | Xcode CLT 미설치 |
| E_SIMCTL_FAILED | Simctl Failed | simctl 명령 실패 |
| E_DOCKER_NOT_RUNNING | Docker Not Running | Docker 미실행 |
| E_CONFIG_INVALID | Config Invalid | 설정 파일 오류 |

---

## Appendix B: Glossary

이 문서에서 사용된 용어는 Section 1.3 및 PRD의 Appendix A를 참조하세요.

---

## Document Approval

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Product Owner | | | |
| Tech Lead | | | |
| QA Lead | | | |

---

*이 문서는 PRD v0.1.0.0을 기반으로 작성되었으며, PRD 변경 시 함께 업데이트되어야 합니다.*
