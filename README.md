# ft (FeatureCraft)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.16.0-blue.svg)](https://github.com/tjdtjq5/featurecraft/releases)

> AI 코드 워크플로 Claude Code 플러그인.
> **핀포인트 명령은 스킬로**, **코드 본문 작업은 에이전트로** 깔끔하게 분리한 도구 모음.

## 해결하는 문제

Claude는 코드를 작성할 때 기존 API를 무시하고 자기 방식으로 새로 만든다.
그리고 매번 사용자가 워크플로(커밋 → PR → 머지, 패키지 배포 등)를 직접 챙겨야 한다.

ft는 두 가지로 답한다:
1. **에이전트 3개**가 코드 사실(cwm-roslyn-navigator MCP)과 자동 컨텍스트(메모리·룰)를 결합해 코드 작성/디버그/감사를 자동화.
2. **스킬 11개**가 Git/패키지/메타 작업의 정해진 절차를 1회 호출로 처리.

## 설치

```bash
# 마켓플레이스 등록
claude plugin marketplace add github:tjdtjq5/featurecraft

# ft 플러그인 설치
claude plugin install ft@featurecraft
```

설치 후 `/ft:setup`을 호출해 필수 외부 도구 (uloop-cli, context-mode, CWM.RoslynNavigator) 설치 여부를 검증/자동 설치할 수 있다.

## 도구 한눈에 보기

### 에이전트 — 자동 발동 (코드 본문 작업)

| 에이전트 | 역할 | 자동 발동 키워드 |
|---------|------|------------------|
| `code-writer` | 코드 작성/수정. 7원칙. cwm으로 기존 API 정확 파악 | "구현해줘", "만들어줘", "수정해줘" |
| `code-diagnose` | 버그 근본 원인 추적. 증거 기반. 해결 옵션 비교 | "왜 안돼", "원인 분석", "진단해줘" |
| `code-auditor` | 구조 감사. 12체크리스트 + Unity 예외 해석 | "감사해줘", "구조 점검", "건강도" |

### 스킬 — 명시 호출

| 카테고리 | 명령 | 역할 |
|---------|------|------|
| **Git** | `/ft:push` | 커밋 → PR → 머지 한방 |
| | `/ft:pull` | 기본브랜치 최신 반영 |
| | `/ft:release` | dev → main 릴리스 |
| **패키지** | `/ft:pkg-dev` | UPM 로컬 개발 모드 |
| | `/ft:pkg-list` | 패키지 목록 + 업데이트 확인 |
| | `/ft:pkg-publish` | UPM 패키지 배포 |
| **메타** | `/ft:dev` | ft 자체 수정/배포 |
| | `/ft:rules` | 프로젝트 룰 관리 + 훅 등록 |
| | `/ft:skill-creator-project` | 프로젝트 전용 가이드 스킬 생성 |
| | `/ft:setup` | Claude Code 필수 외부 도구 자동 셋업 |
| **설계** | `/ft:design` | 설계 대화 (저장 X) |

## 핵심 개념

### cwm-roslyn-navigator 통합

에이전트는 cwm MCP의 의미 분석을 **1순위 도구**로 사용:
- `find_symbol` / `get_public_api` — 기존 API 정확 파악 (큰 파일 안 읽고)
- `get_dependency_graph` — 호출 트리 자동 추적
- `find_callers` / `find_references` — 영향 범위 분석
- `detect_circular_dependencies` — 구조 감사

Roslyn 기반이라 정확하고, 결정론적이고, 빠르다.

### 자동 컨텍스트

코드 본문 작업 시 다음이 **모두 자동으로** 들어옴:
- **auto memory** — 결정/제약/선호 (`project_*.md`, `feedback_*.md`)
- **context-mode** — 세션 상태 (최근 변경/에러)
- **rules/ 인덱스** — `forbidden`, `architecture` 등
- **CLAUDE.md** — 프로젝트 룰

에이전트가 별도로 호출하지 않아도 컨텍스트가 형성된다.

### Unity 한계 영역 폴백

cwm은 Roslyn 기반이라 다음을 못 봄:
- `[SerializeField]`, `[Inject]` 같은 attribute
- prefab/Inspector 와이어링
- reflection 기반 콜백 (`OnDrawGizmos`, `[RuntimeInitializeOnLoadMethod]`)
- Quantum의 ViewComponent shadowing 패턴 (`new` 키워드)

이 영역은 자동으로 `Grep`/`Read` 폴백.

### 결정 분리

| 무엇 | 어디 |
|------|------|
| 코드 사실 (호출 그래프, API 시그니처) | cwm |
| 결정/제약/선호 | auto memory |
| 세션 상태 (작업 흐름) | context-mode |
| 룰 (금지 패턴, 아키텍처) | `rules/*.md` (사용자 프로젝트) |

각자 자기 영역만 담당. ft는 이 시스템들을 **통합해서 활용**한다.

## 워크플로 예시

```
"카드 진화 시 강화 수치가 누락돼"
  ↓ 자동 발동
code-diagnose
  → 직접 원인 (CardEvolveCase.TryEvolve:31)
  → 구조적 원인 (진화/강화 분산)
  → 옵션 A 빠른 수정 / 옵션 B 구조적 수정
  ↓ "B로 가자"
code-writer (자동 발동)
  → 7원칙 + cwm 검증 + 구현
  ↓
/ft:push
  → 커밋 + PR + 머지
```

## 설계 철학

**제거한 것** (FeatureCraft 0.x → 0.15.0):
- Feature.md 기반 의존성 체이닝 → cwm으로 대체 (정확도 압승)
- 피처 단위 워크플로 → 에이전트 자동 위임으로 단순화
- 매번 문서 갱신 부담 → auto memory + context-mode 자동 캡처
- diff 리뷰 도구 → cwm `detect_antipatterns` + code-auditor로 대체

**유지한 것**:
- 핀포인트 작업의 1회 호출 (Git/패키지)
- 7원칙 (단일 책임 / Premature Abstraction 금지 등)
- 12체크리스트 감사
- Unity 예외 해석 (Authoring/Bridge/Bootstrap/ECS)

## 이슈 / 기여

- **버그 리포트 / 기능 제안**: [github.com/tjdtjq5/featurecraft/issues](https://github.com/tjdtjq5/featurecraft/issues)
- **PR 환영**: 이슈에서 먼저 합의 후 PR 권장

## 라이센스

[MIT](LICENSE)
