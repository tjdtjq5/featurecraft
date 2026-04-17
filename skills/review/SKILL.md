---
name: "ft:review"
description: "코드 리뷰 — 변경된 코드의 품질, 버그, 프로젝트 규칙 위반, 성능을 체크하고 리포트를 제공한다. '리뷰해줘', '코드 봐줘', '검토해줘', 'review', '이거 괜찮아?', '문제 없어?' 같은 요청이 오면 이 스킬을 사용한다. 피처 코드뿐 아니라 일반 코드에도 사용 가능하다."
---

# /ft:review — 코드 리뷰

변경된 코드를 분석하여 프로젝트 규칙 위반, 버그, 성능, 코드 품질 관점에서 리포트를 제공한다.

## 왜 이 스킬이 필요한가

코드 리뷰에서 반복적으로 잡아야 하는 문제가 두 종류다:

**프로젝트 규칙 위반** — 프로젝트마다 금지 패턴, 아키텍처 규칙, 레이어 의존 규칙이 있다. 이를 diff 단위로 자동 검증한다.

**AI 생성 코드 품질** — Claude가 만든 코드의 반복적 문제를 잡는다:
- 과도한 try-catch, 불필요한 null 체크, 코드 반복 주석, 미사용 import

## 실행 흐름

### 1단계: 리뷰 대상 파악

인자가 있으면:
- 파일 경로 → 해당 파일 리뷰
- 폴더 경로 → 해당 폴더 내 코드 파일 전체 리뷰
- "최근 변경" / "마지막 커밋" → `git diff` 또는 `git diff HEAD~1`로 변경분 리뷰

인자가 없으면:
- `git diff --staged` → 스테이징된 변경분
- 없으면 `git diff` → 워킹 디렉토리 변경분
- 그것도 없으면 → "리뷰할 대상을 지정해주세요" 안내

### 2단계: 프로젝트 규칙 로딩

변경된 코드를 규칙과 대조하기 위해, 프로젝트 규칙 파일을 로딩한다.

#### 2-A. 프로젝트 규칙 파일 탐색

아래 경로에서 규칙 파일을 찾는다 (존재하는 것만):

```
.claude/rules/*.md          ← forbidden-patterns, architecture-rules 등
CLAUDE.md                   ← Forbidden Patterns 섹션
.featurecraft/learnings/*.md ← 프로젝트 특유의 패턴/주의사항
```

**로딩 우선순위**: `.claude/rules/` 폴더가 있으면 그 안의 파일들을 읽는다. 없으면 `CLAUDE.md`의 금지 패턴 섹션을 참조한다.

규칙 파일이 전혀 없으면 → 이 단계 건너뛰고 3단계의 범용 분석만 실행.

#### 2-B. 규칙에서 체크리스트 추출

규칙 파일에서 **diff에 적용 가능한 구체적 패턴**을 추출한다:

| 규칙 유형 | 추출 대상 | 예시 |
|-----------|-----------|------|
| 금지 패턴 | `❌ WRONG` 코드 블록의 패턴 | `InGameController.Instance` in Data 레이어 |
| 레이어 의존 | 폴더 간 참조 제한 | `Scripts/Data/` → `Scripts/InGame/` 직접 참조 금지 |
| 네이밍 | 명명 규칙 위반 | Behavior 클래스가 `CardBh` 접두사 미사용 |
| 필수 패턴 | 누락 체크 | `base.OnExecute` 호출 누락, `NextBehavior()` 누락 |
| 서비스 규칙 | 우회 감지 | UserData 직접 조작 (Service 미경유) |

### 3단계: 피처 컨텍스트 파악

리뷰 대상 파일이 피처 폴더에 있으면 (Feature.md 존재 여부 확인):

1. **Feature.md 읽기** → 용도, 의존성, 주의사항 파악
2. **주의사항**에 적힌 규칙 위반 여부를 추가 체크
3. **의존 피처 1단계 체이닝** → 의존 피처의 public API를 읽어, 변경이 API 계약을 깨는지 확인

피처 폴더가 아니면 → 이 단계 건너뛰기

### 4단계: 코드 분석

아래 6가지 관점으로 코드를 분석한다. **변경된 코드(diff)만 분석** — 기존 코드의 문제는 리포트하지 않는다.

#### RULE — 프로젝트 규칙 위반
2단계에서 로딩한 규칙 체크리스트를 diff에 대조한다:
- 금지 패턴 매칭 (코드 패턴 단위)
- 레이어 의존 규칙 위반 (using/참조 경로 기준)
- 필수 패턴 누락 (base 호출, NextBehavior 등)
- 서비스 규칙 우회 (UserData 직접 변경)

**심각도**: 항상 **BUG** (프로젝트가 명시적으로 금지한 패턴)

#### BUG — 버그
- null reference 가능성
- 범위 초과 (off-by-one, 배열 인덱스)
- 리소스 미해제 (Dispose, Close)
- 비동기 처리 누락 (await 빠짐, async void)
- 예외 삼킴 (빈 catch)

#### PERF — 성능
- 루프 안 반복 할당 (매 프레임 new)
- 불필요한 LINQ/lambda 할당 (GC 압박)
- 큰 컬렉션 전체 복사
- 매 호출 반복 연산 (캐싱 가능)

#### SEC — 보안
- 하드코딩된 비밀키/토큰
- 인젝션 가능성
- 입력 검증 누락 (외부 입력에 대해서만)

#### STYLE — 구조/스타일
- 단일 책임 위반 (한 클래스가 너무 많은 일)
- 매직 넘버/스트링
- 중복 코드

#### SLOP — AI 생성 코드 특유의 문제
- 과도한 try-catch (필요 없는 곳에 감싸기)
- 코드를 그대로 반복하는 주석 ("// 아이템 추가")
- 불필요한 null 체크 (내부 코드인데 null이 올 수 없는 곳)
- 미사용 using/import
- 과도한 로깅 (모든 메서드 진입/종료 로깅)
- 불필요한 에러 핸들링/폴백 (일어날 수 없는 시나리오 방어)
- 요청하지 않은 docstring/type annotation 추가

#### 심각도 매핑

각 이슈는 카테고리와 **별개로 심각도(Critical/Warning/Info)가 부여**된다.
--fix 플래그는 심각도에 따라 수정 방식을 결정한다.

| 심각도 | 적용 기준 | --fix 동작 |
|--------|-----------|-----------|
| **Critical** | 버그, 금지 패턴, 보안 취약, 수정 방향이 명확한 SLOP | 자동 수정 |
| **Warning** | 성능 개선, 스타일 개선, 수정 방향 2개 이상, 영향 범위 5+ 파일, 애매한 SLOP | AskUserQuestion으로 1건씩 확인 |
| **Info** | Feature.md 갱신 알림, 수정 불필요한 관찰 | 리포트만, 수정 없음 |

**카테고리 → 심각도 기본 매핑**:

| 카테고리 | 심각도 | 비고 |
|----------|--------|------|
| RULE | Critical | 프로젝트 규칙은 명시적 금지 |
| BUG | Critical | 런타임 오류 가능성 |
| SEC | Critical | 보안 취약 |
| SLOP (명확): 미사용 import/반복 주석/빈 catch/불필요 null 체크 | Critical | 수정 방향이 1개뿐 |
| SLOP (애매): 과잉 방어/과도한 로깅 | Warning | 의도 파악 필요 |
| PERF | Warning | 개선 권장이지만 필수 아님 |
| STYLE | Warning 또는 Info | 영향도로 결정 (매직넘버 = Warning, 들여쓰기 = Info) |
| 정보성 (Feature.md 갱신) | Info | 알림만 |

**심각도 승격 조건**: 아래 중 하나에 해당하면 기본 매핑에서 한 단계 승격한다 (Info→Warning, Warning→Critical).
- 영향 범위가 10+ 파일
- 다른 이슈와 연쇄 영향
- 사용자가 `CLAUDE.md`에서 명시적으로 중시한 패턴

**심각도 강등 조건**: 아래에 해당하면 한 단계 강등한다.
- 이미 작성자가 `// reviewed:ok` 또는 `// intentional` 주석으로 명시
- 테스트 코드에서만 발생 (프로덕션 영향 없음)

### 5단계: Feature.md 갱신 필요성 감지

변경된 코드에서 다음을 감지하면 리포트에 **INFO**로 포함한다:

| 감지 대상 | Feature.md 갱신 필요 |
|-----------|---------------------|
| 새 public 클래스/메서드 추가 | API 섹션에 반영 |
| 새 .cs 파일 생성 | 구조 섹션에 반영 |
| 새 using으로 다른 피처 참조 | 의존성 섹션에 반영 |
| 새 제약/주의사항 발견 | 주의사항 섹션에 반영 |

Feature.md가 없는 피처 폴더의 변경이면 → "Feature.md 없음" INFO로 알림.

### 6단계: 리포트 출력

리포트는 **심각도 순서**로 출력한다 (Critical → Warning → Info).
각 이슈는 `[심각도][카테고리] 위치 — 설명 → 제안` 포맷.

```
## 코드 리뷰 결과

### 요약
- 파일: {n}개 분석
- 규칙 파일: {로딩한 규칙 파일 목록 또는 "없음"}
- 이슈: Critical {n} / Warning {n} / Info {n}

### Critical (자동 수정 대상)
1. **[Critical][RULE] PlayerHandler.cs:42** — `InGameController.Instance` 직접 참조 (Data 레이어 금지 패턴)
   → `GameContext.Current` 사용
2. **[Critical][BUG] InventoryService.cs:58** — RemoveItem에서 수량 0일 때 처리 없음
   → 0 이하 가드 추가
3. **[Critical][SLOP] PlayerHandler.cs:3** — 미사용 `using System.Linq`
   → 제거

### Warning (확인 후 수정)
1. **[Warning][PERF] ItemTable.cs:28** — 매 호출 LINQ ToList() 할당
   → 캐싱 vs 재설계 중 선택 필요
2. **[Warning][STYLE] InventoryService.cs** — 7개 public 메서드, 200줄
   → 분리 방식 여러 가지 (책임별/계층별)

### Info (참고 — 수정 불필요)
1. **[Info][META] WeaponFactory.cs** — 새 public API `CreateWeapon()` 추가됨
   → Feature.md API 섹션 갱신 필요
2. **[Info][STYLE] Helper.cs** — 들여쓰기 혼재 (tabs/spaces)
```

**포맷 원칙**:
- Critical은 **수정 방향 1개**로 명시 (`→ X 사용`)
- Warning은 **선택지 제시** (`→ A vs B 중 선택 필요`)
- Info는 **관찰만** 적고 제안 생략 가능

### 7단계: 자동 수정 (--fix 플래그 시)

`/ft:review --fix`로 호출하면 리포트 출력 후 심각도별로 순차 처리한다.

#### 7-A. 대량 변경 사전 확인

Critical 수정 대상이 **10+ 파일**에 걸쳐 있으면, 시작 전에 **1회만** 사전 요약을 보여주고 사용자에게 확인받는다:

```
📋 Critical {N}건을 {M}개 파일에 자동 수정합니다

주요 변경:
- InGameController 직접 참조 → GameContext.Current (6건, 5개 파일)
- 미사용 using 제거 (8건, 7개 파일)
- null 체크 누락 (2건, 2개 파일)

진행할까요? (y/n)
```

9개 이하는 확인 없이 바로 진행.

#### 7-B. Critical 자동 수정

수정 방향이 명확하므로 **개별 확인 없이** 연속 수정한다.
각 수정은 원자적으로 처리 (파일별 Edit) — 도중 실패 시 해당 이슈만 건너뛰고 계속.

#### 7-C. Warning 개별 확인 (AskUserQuestion)

Warning 이슈마다 **AskUserQuestion 도구로 1건씩** 처리 방향을 묻는다.
예시 옵션:
- "제안대로 수정" (기본안 적용)
- "다른 방향으로 수정" (사용자 설명 받아 반영)
- "건너뛰기" (이번에는 수정 안 함)

사용자 응답에 따라 수정 or 건너뛰기.

#### 7-D. Info 리포트만

Info 항목은 **수정하지 않는다**. 리포트에만 남기고 사용자 인지에 맡긴다.

#### 7-E. 변경 내역 보고 (필수)

수정 완료 후 **반드시** 아래 포맷으로 결과를 보고한다:

```
✅ 수정 완료: {총 N}건

### Critical 자동 수정 ({M}건)
1. PlayerHandler.cs:42
   - 문제: InGameController.Instance 직접 참조
   - 수정: `GameContext.Current.Player.GetDamage(10)` 으로 교체
2. InventoryService.cs:58
   - 문제: RemoveItem 수량 0 가드 없음
   - 수정: `if (count <= 0) return;` 추가
...

### Warning 확인 후 수정 ({K}건)
1. ItemTable.cs:28
   - 문제: 매 호출 LINQ 할당
   - 사용자 선택: "캐싱"
   - 수정: `_cachedList` 필드 추가, 첫 호출 시 초기화

### 건너뛴 항목 ({S}건)
- Warning [STYLE] InventoryService.cs 분리 — 사용자 판단 보류
- Critical [BUG] Helper.cs:12 수정 실패 — 파일 잠김

### Info 리포트만 ({I}건)
- WeaponFactory.cs — Feature.md API 갱신 필요
- Helper.cs — 들여쓰기 혼재
```

건너뛴 항목의 이유도 반드시 명시한다 (사용자 선택 / 수정 실패 / 기타).

## 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| 바이너리 파일 포함 | 스킵 + 안내 |
| 변경분이 1000줄 이상 | "큰 변경입니다. 특정 파일을 지정하시겠습니까?" 질문 |
| 외부 라이브러리 코드 | 스킵 (프로젝트 코드만 리뷰) |
| Feature.md의 주의사항 위반 | Critical로 리포트 |
| 규칙 파일 없음 | RULE 카테고리 비활성, 나머지 5가지만 분석 |
| 피처 폴더 아닌 코드 | Feature.md 관련 단계 건너뛰기 |
| RULE 위반이면서 동시에 BUG | RULE로 분류 (중복 리포트 안 함), 심각도 Critical |
| Critical이 10+ 파일에 걸침 | 7-A 사전 요약 확인 후 진행 |
| Critical 수정 실패 (파일 잠김 등) | 해당 이슈 건너뛰기, 변경 내역 보고에 실패 사유 명시 |
| Warning인데 사용자가 "모두 제안대로" 응답 | 이후 Warning도 일괄 적용 (같은 세션 내) |
| `// reviewed:ok` / `// intentional` 주석 존재 | 해당 줄 이슈는 한 단계 강등 |
| 테스트 코드 전용 이슈 | 한 단계 강등 |

## 경계

**한다:**
- 프로젝트 규칙 파일 로딩 + diff 대조 검증
- 6가지 관점 코드 분석 (RULE/BUG/PERF/SEC/STYLE/SLOP)
- **심각도 3단계 분류** (Critical / Warning / Info)
- Feature.md 갱신 필요성 감지 (Info)
- 크로스 피처 API 호환성 체크
- 파일별 이슈 리포트 (심각도 + 카테고리 + 위치 + 설명 + 제안)
- --fix 시 **Critical 자동 수정** (10+ 파일이면 사전 요약 확인 1회)
- --fix 시 **Warning AskUserQuestion으로 1건씩 확인**
- --fix 시 **수정 후 변경 내역 보고** (필수)

**안한다:**
- 리포트 없이 바로 수정 (--fix 없으면 리포트만)
- **Warning/Info를 확인 없이 자동 수정**
- **Info 항목 수정** (리포트만)
- 변경되지 않은 기존 코드의 문제 리포트
- 테스트 작성/실행
- 아키텍처 변경 제안
