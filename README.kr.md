# OSX Cleaner

> **macOS 시스템 정리 도구** - 안전하게 불필요한 파일을 정리하여 디스크 공간을 확보합니다.

[![macOS](https://img.shields.io/badge/macOS-10.15--15.x-blue.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Development-orange.svg)]()

---

## 개요

**OSX Cleaner**는 macOS 시스템의 불필요한 파일(임시 파일, 캐시, 로그 등)을 **안전하게** 정리하여 디스크 공간을 확보하고 시스템 성능을 최적화하는 도구입니다.

### 주요 가치

| 가치 | 설명 |
|-----|------|
| **안전 최우선** | 4단계 안전 등급 시스템으로 시스템 손상 방지 |
| **개발자 친화적** | Xcode, Docker, npm, Homebrew 등 개발 도구 캐시 전문 관리 (50-150GB 절약 가능) |
| **버전 호환성** | macOS Catalina(10.15)부터 Sequoia(15.x)까지 완벽 지원 |
| **자동화 지원** | launchd 기반 스케줄링 및 CI/CD 파이프라인 통합 |

---

## 정리 가능 용량

```
┌─────────────────────────────────────────────────────────────────┐
│                    개발자 Mac (512GB SSD)                        │
├─────────────────────────────────────────────────────────────────┤
│ Xcode + 시뮬레이터        ██████████████░░░░░░  80GB (16%)       │
│ Docker                   ██████░░░░░░░░░░░░░░  30GB (6%)        │
│ 각종 캐시                 ████████░░░░░░░░░░░░  50GB (10%)       │
│ node_modules (분산)      ████░░░░░░░░░░░░░░░░  20GB (4%)        │
│ 시스템 데이터             ██████░░░░░░░░░░░░░░  35GB (7%)        │
└─────────────────────────────────────────────────────────────────┘
  → 캐시/임시 데이터만 200GB+ (40%) 차지
```

---

## 안전 등급 시스템

OSX Cleaner는 4단계 안전 등급 시스템을 사용합니다:

| 레벨 | 표시 | 설명 | 예시 |
|-----|------|------|------|
| **Safe** | ✅ | 즉시 삭제 가능, 자동 재생성 | 브라우저 캐시, 휴지통 |
| **Caution** | ⚠️ | 삭제 가능하나 재빌드 필요 | 사용자 캐시, 오래된 로그 |
| **Warning** | ⚠️⚠️ | 삭제 가능하나 재다운로드 필요 | iOS Device Support, Docker 이미지 |
| **Danger** | ❌ | 삭제 금지, 시스템 손상 가능 | `/System/*`, 키체인 |

---

## 정리 레벨

### Level 1: Light (✅ Safe)
- 휴지통 비우기
- 브라우저 캐시 (Safari, Chrome, Firefox, Edge)
- 오래된 다운로드 (90일 이상)
- 오래된 스크린샷 (30일 이상)

### Level 2: Normal (⚠️ Caution)
- Level 1 포함
- 모든 사용자 캐시 (`~/Library/Caches/*`)
- 오래된 로그 (30일 이상)
- 크래시 리포트 (30일 이상)

### Level 3: Deep (⚠️⚠️ Warning)
- Level 2 포함
- Xcode DerivedData
- iOS 시뮬레이터 (사용 불가 버전)
- CocoaPods/SPM 캐시
- npm/yarn/pnpm 캐시
- Docker (미사용 이미지, 빌드 캐시)
- Homebrew 구버전

### Level 4: System (❌ 권장하지 않음)
- `/Library/Caches` (root 권한 필요)
- 안전 모드 부팅이나 주기적 스크립트 권장

---

## 대상 사용자

### iOS/macOS 개발자
- **환경**: Xcode, 다수의 시뮬레이터, CocoaPods/SPM
- **정리 가능 용량**: 50-150GB

### Full-Stack 개발자
- **환경**: Node.js, Docker, Python, 여러 IDE
- **정리 가능 용량**: 30-80GB

### DevOps 엔지니어
- **환경**: CI/CD 빌드 머신, 다중 사용자 환경
- **정리 가능 용량**: 실시간 모니터링 및 자동 정리 필요

### 일반 파워 유저
- **환경**: 브라우저, 오피스 앱, 클라우드 동기화
- **정리 가능 용량**: 5-30GB

---

## 주요 기능

| 기능 ID | 기능명 | 우선순위 | 대상 사용자 |
|---------|--------|:--------:|------------|
| F01 | 안전 기반 정리 시스템 | P0 | 전체 |
| F02 | 개발 도구 캐시 관리 | P0 | 개발자 |
| F03 | 브라우저/앱 캐시 정리 | P0 | 전체 |
| F04 | 로그/크래시 리포트 관리 | P1 | 전체 |
| F05 | Time Machine 스냅샷 관리 | P1 | 전체 |
| F06 | 디스크 사용량 분석/시각화 | P1 | 전체 |
| F07 | 자동화 스케줄링 | P1 | 개발자/DevOps |
| F08 | CI/CD 파이프라인 통합 | P2 | DevOps |
| F09 | 팀 환경 관리 | P2 | DevOps |
| F10 | macOS 버전별 최적화 | P1 | 전체 |

---

## 기술 스택

OSX Cleaner는 **Swift + Rust 하이브리드** 아키텍처를 채택합니다.

```
┌─────────────────────────────────────────────────────────────────┐
│                   Swift + Rust Hybrid                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│   Swift Layer                                                     │
│   ├── Presentation: CLI (ArgumentParser), GUI (SwiftUI)          │
│   ├── Service: 비즈니스 로직 조율                                  │
│   └── Core: 설정 관리, 로깅                                       │
│                         │ FFI (C-ABI)                             │
│   Rust Layer            ▼                                         │
│   ├── Core Engine: 파일 스캔, 정리 실행, 안전 검증                 │
│   └── Infrastructure: 파일시스템 추상화, 병렬 처리                 │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

| 레이어 | 언어 | 주요 역할 |
|--------|------|-----------|
| **Presentation** | Swift | CLI, GUI (SwiftUI) |
| **Service** | Swift | 비즈니스 로직 |
| **Core** | Swift + Rust | Config/Logger (Swift), Engine/Safety (Rust) |
| **Infrastructure** | Rust | 파일시스템, 병렬 처리 |
| **Scripts** | Shell | launchd, 설치 스크립트 |

> 자세한 내용은 [SDS.kr.md](docs/SDS.kr.md) Section 1.5 참조

---

## 빠른 시작

### 설치

```bash
# 저장소 클론
git clone https://github.com/kcenon/osx_cleaner.git
cd osx_cleaner

# 빌드 및 설치
./scripts/install.sh
```

### 기본 사용법

```bash
# 디스크 사용량 분석
osxcleaner analyze

# 상세 분석
osxcleaner analyze --verbose

# 특정 카테고리 분석 (상위 N개 표시)
osxcleaner analyze --category xcode --top 10

# JSON 출력 (CI/CD용)
osxcleaner analyze --format json

# 기본 정리 레벨(normal)로 정리 (dry-run)
osxcleaner clean --dry-run

# 가벼운 정리 (안전한 항목만)
osxcleaner clean --level light --dry-run

# 개발자 캐시 심층 정리
osxcleaner clean --level deep --target developer

# CI/CD 환경 정리 (비대화식, JSON 출력)
osxcleaner clean --level normal --non-interactive --format json

# 설정 확인
osxcleaner config show

# 일일 자동 정리 스케줄 생성
osxcleaner schedule add --frequency daily --level light --hour 3

# 설정된 스케줄 목록
osxcleaner schedule list

# 스케줄 활성화
osxcleaner schedule enable daily
```

### CLI 명령어 참조

| 명령어 | 설명 |
|--------|------|
| `analyze` | 디스크 사용량 분석 및 정리 가능 항목 찾기 |
| `clean` | 안전성 검사를 통한 대상 정리 |
| `config` | osxcleaner 설정 관리 |
| `schedule` | 자동화 정리 스케줄 관리 |

### 주요 옵션

| 옵션 | 명령어 | 설명 |
|------|--------|------|
| `--level` | clean | 정리 레벨 (light, normal, deep, system) |
| `--target` | clean | 정리 대상 (browser, developer, logs, all) |
| `--category` | analyze | 카테고리 필터 (all, xcode, docker, browser, caches, logs) |
| `--format` | clean, analyze, schedule | 출력 형식 (text, json) |
| `--dry-run` | clean | 실제 삭제 없이 미리보기 |
| `--non-interactive` | clean | 확인 프롬프트 건너뛰기 (CI/CD용) |
| `--verbose` | clean, analyze | 상세 출력 |
| `--quiet` | clean, analyze | 최소 출력 |

### 수동 빌드

```bash
# 전체 빌드
make all

# 테스트 실행
make test

# 개발용 빌드
make debug
```

---

## 시스템 요구사항

### 지원 플랫폼
- **macOS 버전**: 10.15 (Catalina) ~ 15.x (Sequoia)
- **아키텍처**: Intel x64, Apple Silicon (arm64)

### 권장 사양
- **디스크 공간**: 100MB (애플리케이션)
- **메모리**: 4GB RAM 이상
- **권한**: 관리자 권한 (선택적, Level 4 정리 시 필요)

### 빌드 요구사항
- **Swift**: 5.9+
- **Rust**: 1.75+
- **Xcode**: 15+

---

## 프로젝트 구조

```
osxcleaner/
├── Package.swift               # Swift Package 정의
├── Makefile                    # 통합 빌드 스크립트
├── Sources/                    # Swift 소스
│   ├── osxcleaner/             # CLI 애플리케이션
│   │   ├── main.swift
│   │   ├── Commands/           # CLI 명령어
│   │   └── UI/                 # 진행률 표시
│   └── OSXCleanerKit/          # Swift 라이브러리
│       ├── Services/           # 비즈니스 로직
│       ├── Config/             # 설정
│       └── Logger/             # 로깅
├── rust-core/                  # Rust 소스
│   ├── Cargo.toml
│   ├── cbindgen.toml           # FFI 헤더 생성
│   └── src/
│       ├── lib.rs              # FFI 진입점
│       ├── safety/             # 안전 검증
│       ├── scanner/            # 디렉토리 스캔
│       ├── cleaner/            # 정리 실행
│       └── fs/                 # 파일시스템 유틸
├── include/                    # 생성된 C 헤더
├── scripts/                    # 셸 스크립트
│   ├── install.sh
│   ├── uninstall.sh
│   └── launchd/                # launchd 에이전트
├── Tests/                      # 테스트 파일
└── docs/                       # 문서
```

---

## 문서

### 프로젝트 문서

| 문서 | 설명 | 한글 | English |
|------|------|:----:|:-------:|
| **PRD** | 제품 요구사항 문서 | [PRD.kr.md](docs/PRD.kr.md) | [PRD.md](docs/PRD.md) |
| **SRS** | 소프트웨어 요구사항 명세 | [SRS.kr.md](docs/SRS.kr.md) | [SRS.md](docs/SRS.md) |
| **SDS** | 소프트웨어 설계 명세 | [SDS.kr.md](docs/SDS.kr.md) | [SDS.md](docs/SDS.md) |

### 참조 문서

| 문서 | 설명 |
|------|------|
| [01-temporary-files](docs/reference/01-temporary-files.md) | 임시 파일 가이드 |
| [02-cache-system](docs/reference/02-cache-system.md) | 캐시 시스템 분석 |
| [03-system-logs](docs/reference/03-system-logs.md) | 시스템 로그 관리 |
| [04-version-differences](docs/reference/04-version-differences.md) | macOS 버전별 차이점 |
| [05-developer-caches](docs/reference/05-developer-caches.md) | 개발자 캐시 관리 |
| [06-safe-cleanup-guide](docs/reference/06-safe-cleanup-guide.md) | 안전한 정리 가이드 |
| [07-developer-guide](docs/reference/07-developer-guide.md) | 개발자 가이드 |
| [08-automation-scripts](docs/reference/08-automation-scripts.md) | 자동화 스크립트 |
| [09-ci-cd-team-guide](docs/reference/09-ci-cd-team-guide.md) | CI/CD 팀 가이드 |

---

## 로드맵

### Phase 1: MVP (v0.1) - 핵심 기능
- [ ] CLI 기반 정리 도구
- [ ] 안전 등급 시스템 구현
- [ ] 기본 정리 레벨 (Level 1-2)

### Phase 2: 개발자 기능 (v0.5)
- [ ] 개발 도구 캐시 관리 (F02)
- [ ] Level 3 정리 지원
- [ ] 자동화 스케줄링 (F07)

### Phase 3: 완성 (v1.0)
- [ ] GUI 인터페이스
- [ ] CI/CD 통합 (F08)
- [ ] 팀 환경 관리 (F09)

---

## 기여

기여를 환영합니다! 자세한 내용은 [개발자 가이드](docs/reference/07-developer-guide.md)를 참조하세요.

---

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

---

## 연락처

- **Issues**: [GitHub Issues](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)

---

*마지막 업데이트: 2025-12-25*
