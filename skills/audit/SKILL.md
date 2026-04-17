---
name: "ft:audit"
description: "코드 구조 감사 — 기존 코드가 책임분리/유지보수성/테스트 용이성 3원칙을 12개 체크리스트로 점검하고, 실패 항목에 리팩토링 제안을 제공한다. '감사해줘', '구조 점검', '책임분리 됐어?', '건강도', 'audit', 'Humble Object', 'Lean MB', '구조 감사', '부채 확인' 같은 요청이 오면 이 스킬을 사용한다. diff 리뷰가 아니라 기존 코드의 구조적 건강도를 본다 — diff 리뷰는 ft:review를 사용한다."
---

# /ft:audit — 코드 구조 감사

기존 코드의 구조적 건강도를 3카테고리 12체크리스트로 점검하고, 실패 항목에 리팩토링 제안을 제공한다.

## 왜 이 스킬이 필요한가

코드 리뷰 스킬은 이미 `ft:review`가 있다. 왜 감사(audit) 스킬이 따로 필요한가?

**시점·범위·방법이 다르다**:

| 축 | `ft:review` | `ft:audit` |
|---|---|---|
| **대상** | `git diff` (방금 쓴 것) | 기존 코드 (이미 있는 것) |
| **질문** | "이 변경 괜찮나?" | "이 구조 장기적으로 괜찮나?" |
| **범위** | 파일/커밋 | 피처/모듈 단위 |
| **방법** | 패턴 매칭 + 규칙 대조 | 정량 지표 + 체크리스트 |
| **주기** | 매 커밋 | 리팩토링 전, 주기 점검 |
| **결과물** | 이슈 리스트 (BUG/PERF/SEC/STYLE/SLOP) | 체크리스트 (pass/fail) + 핫스팟 + 제안 |

**ft:review가 못 보는 것**:
- 파일 전체 구조 ("이 MB가 데이터·로직을 다 들고 있네")
- 변경되지 않은 부채 (diff에 안 잡힘)
- 시간 누적 핫스팟 (git 히스토리 기반)
- 3원칙의 정량 체크

**기본 철학**: **수집은 규칙 기반으로**(재현성 확보), **해석은 LLM으로**(Unity 예외·컨텍스트 판단). 이 분리가 없으면 "느낌 리포트"가 나오고 재현성이 무너진다.

## 실행 흐름

### 1단계: 감사 대상 파악

인자에 따라 대상을 정한다:

| 인자 | 대상 |
|---|---|
| 없음 | `git diff`가 속한 피처 자동 감지. 찾지 못하면 "피처를 지정해주세요" 안내 |
| 피처 경로 (예: `Combat/Weapon`) | 해당 피처 폴더 전체 |
| 파일 경로 (예: `Assets/.../Foo.cs`) | 파일 1개 핀포인트 |
| `--all` | 프로젝트 전체 (baseline / 핫스팟 랭킹용) |
| `--since HEAD~N` | 최근 N커밋에서 만진 파일들만 |

**감사 대상에서 자동 제외**:
- `*Tests.cs`, `_Tests/`, `Tests/` 폴더 — 테스트 코드
- `ThirdParty/`, `Library/`, `Packages/` (패키지 피처 제외하고) — 외부 코드
- 바이너리 / 자동 생성 파일 (`*.g.cs`, `*.designer.cs`)

**규모 경고**: `--all` 시 대상 .cs 파일이 1000개를 넘으면 "큰 범위입니다. 피처를 지정하시겠습니까?" 확인 후 진행.

### 2단계: 외부 규칙 파일 로딩 (선택적)

아래 경로에 규칙 파일이 있으면 로드해서 추가 체크 또는 임계값 재정의에 사용한다 (없으면 건너뜀):

```
.claude/rules/audit-rules.md
rules/audit-rules.md
```

파일이 없으면 내장 12체크만 사용한다. 프로젝트 고유 규칙은 향후 확장 포인트 — 이 스킬의 내장 로직은 손대지 않는다.

### 3단계: 정량 데이터 수집

감사 대상 파일들에 대해 아래 정량 데이터를 기계적으로 수집한다. **이 단계에서는 LLM 판단이 들어가지 않는다.**

#### 3-A. 파일 단위 메트릭
- **LOC**: `Read`로 읽어 라인 수 계산 (주석·빈 줄 포함한 물리 라인)
- **using 수**: `Grep -c "^using\s+[A-Za-z]"` — `using static`, `using X = ...` 제외
- **namespace 선언**: `Grep "^namespace\s+"`로 추출

#### 3-B. 클래스 단위 메트릭
한 파일에 top-level 클래스가 여러 개면 각 클래스별로 계산하고, **가장 높은 값**을 파일의 대표값으로 사용한다.

- **public 메서드 수**: `Grep "public\s+(static\s+)?(async\s+)?[\w<>\[\],\s]+\s+\w+\s*\("` — 생성자와 프로퍼티 getter/setter는 제외
- **인스턴스 필드 수**: `Grep "(private|protected|internal|public)\s+(?!static|const)\w[\w<>\[\]]*\s+\w+\s*[;=]"` — `static`, `const` 제외
- **MonoBehaviour 여부**: `Grep ":\s*MonoBehaviour\b"`
- **struct / IComponentData 여부**: `Grep "struct\s+\w+|:\s*IComponentData|:\s*IBufferElementData"`
- **interface / abstract 여부**: `Grep "\binterface\s+\w+|abstract\s+class\s+\w+"`

#### 3-C. 메서드 단위 메트릭
- **메서드 길이**: `Read`로 파일 읽고, 메서드 시그니처 → 여는 `{` → 짝 `}` 사이의 라인 수 계산. 중첩 `{}` 짝 맞춤.
- **Update / FixedUpdate 본문 길이**: 위와 동일 방법을 훅 메서드에 적용.

파싱 실패 시(짝 안 맞음 등) 해당 파일의 M2/T2는 skip + 경고.

#### 3-D. 테스트 방해 API 호출
- **Time.* 직접 호출**: `Grep "Time\.(time|deltaTime|fixedDeltaTime|unscaledTime|unscaledDeltaTime)"`
- **Random.* 직접 호출**: `Grep "UnityEngine\.Random\.|(?<!System\.)\bRandom\.Range"`
- **Input.* 직접 호출**: `Grep "\bInput\.(GetKey|GetButton|GetAxis|mousePosition|GetMouseButton)"`
- **Instance / Find 직접 호출**: `Grep "\.Instance\b|FindObjectOfType|FindObjectsOfType|GameObject\.Find\b|FindFirstObjectByType"`
- **static 가변 필드**: `Grep "(private|protected|internal|public)\s+static\s+(?!readonly|const)\w[\w<>\[\]]*\s+\w+\s*[;=]"`

#### 3-E. 히스토리 메트릭 (핫스팟)
- **변경 횟수**: `git log --follow --oneline -- "$file" | wc -l`
- `--since HEAD~N` 인자가 있으면 `git log --since` 또는 `git log HEAD~N..HEAD`로 범위 제한
- **핫스팟 점수** = `변경 횟수 × LOC`
- Git 히스토리가 없는 파일(새 파일)은 M3 판정에서 제외

#### 3-F. 의존 방향 (순환 의존 감지용)
- 각 파일의 `namespace` 선언 추출
- 각 파일의 `using` 중 감사 대상 범위 내 네임스페이스만 추출
- 인접 행렬 구성 후 사이클 탐지 (A → B, B → A 또는 더 긴 사이클)
- 파일 수가 많으면 피처(폴더) 단위로 집계하여 속도 확보

### 4단계: 12개 체크 판정

수집된 데이터를 기준과 대조하여 각 체크를 pass/fail로 판정한다.

#### 책임분리 (SRP) — 4개

| # | 체크 | 기준 | 실패 조건 |
|---|------|------|----------|
| **S1** | 파일 LOC ≤ 400 | 400 | 초과 파일이 1개라도 있으면 실패 |
| **S2** | 클래스당 public 메서드 ≤ 10 | 10 | 초과 클래스가 1개라도 있으면 실패 |
| **S3** | 클래스당 인스턴스 필드 ≤ 15 | 15 | 초과 클래스가 1개라도 있으면 실패 |
| **S4** | 한 파일의 using ≤ 12 | 12 | 초과 파일이 1개라도 있으면 실패 |

#### 유지보수성 — 3개

| # | 체크 | 기준 | 실패 조건 |
|---|------|------|----------|
| **M1** | 순환 의존 없음 (네임스페이스 단위) | 사이클 0 | 사이클이 1건이라도 있으면 실패 |
| **M2** | 메서드 최대 길이 ≤ 50줄 | 50 | 초과 메서드가 1개라도 있으면 실패 |
| **M3** | 핫스팟 과밀 없음 | 변경 10회 × LOC 200 | 이 임계값 초과 파일이 1개라도 있으면 실패 |

#### 테스트 용이성 (Humble Object) — 5개

| # | 체크 | 기준 | 실패 조건 |
|---|------|------|----------|
| **T1** | MB 비-훅 public 메서드 ≤ 3 | 3 | 초과 MB가 1개라도 있으면 실패 |
| **T2** | Update/FixedUpdate 본문 ≤ 20줄 | 20 | 초과 MB가 1개라도 있으면 실패 |
| **T3** | Time/Random/Input 직접 호출 없음 | 0 | 1회 이상 호출 발견 시 실패 |
| **T4** | static 가변 상태 없음 | 0 | `static readonly`/`const` 제외 static 필드 1개라도 있으면 실패 |
| **T5** | Instance/FindObjectOfType 직접 호출 없음 | 0 | 1회 이상 호출 발견 시 실패 |

**Unity 훅 목록** (T1에서 public 메서드 카운트 시 제외):
`Awake`, `Start`, `OnEnable`, `OnDisable`, `Update`, `FixedUpdate`, `LateUpdate`, `OnDestroy`, `OnTriggerEnter`, `OnTriggerExit`, `OnTriggerStay`, `OnTriggerEnter2D`, `OnTriggerExit2D`, `OnTriggerStay2D`, `OnCollisionEnter`, `OnCollisionExit`, `OnCollisionStay`, `OnCollisionEnter2D`, `OnCollisionExit2D`, `OnCollisionStay2D`, `OnMouseEnter`, `OnMouseExit`, `OnMouseDown`, `OnMouseUp`, `OnMouseOver`, `OnGUI`, `OnBecameVisible`, `OnBecameInvisible`, `OnDrawGizmos`, `OnDrawGizmosSelected`, `OnValidate`, `Reset`, `OnApplicationPause`, `OnApplicationFocus`, `OnApplicationQuit`, `OnRenderObject`, `OnPreRender`, `OnPostRender`.

### 5단계: Unity 특화 예외 해석 (LLM 단계)

기계 수집으로 잡힌 실패 중 Unity 관례상 허용되는 경우는 **면제** 또는 **INFO 격하**한다. **이 단계만 LLM 판단을 사용한다.**

| 체크 | 예외 케이스 | 처리 | 판단 근거 |
|------|-------------|------|----------|
| **S1 (LOC)** | `*Authoring.cs` + `[SerializeField]` 비율이 높은 파일 | 면제 | 데이터 정의 파일. 로직 없음. |
| **S1 (LOC)** | `*Config.cs`, `*Def.cs` (순수 데이터 홀더) | 면제 | 설정 홀더. |
| **S2 (public 메서드)** | `interface`, `abstract class` | 완화 (≤15) | 계약 정의는 본질상 메서드 多. |
| **S3 (필드)** | `struct`, `IComponentData`, `IBufferElementData` | 면제 | ECS 데이터 컴포넌트는 필드가 본질. |
| **S3 (필드)** | DTO, record 류 | 면제 | 데이터 홀더. |
| **S4 (using)** | ECS 시스템 (`ISystem`, `SystemBase` 구현) | 완화 (≤16) | Unity/Burst/Collections/Mathematics 패키지를 묶음으로 사용. |
| **T1 (MB 메서드)** | `*Bridge.cs`, `*Adapter.cs`, `*Connector.cs` | 완화 (≤6) | 경계 넘기가 역할. 외부 API 노출이 본질. |
| **T3 (Time.*)** | `TimeProvider`, `*Clock.cs`, `*TimeSource.cs` | 면제 | Time을 추상화하는 구현체. |
| **T4 (static)** | `static readonly` singleton (레거시 DI 전환 전) | **INFO 격하** | 계속 경고는 하되 실패 카운트에는 반영 안 함. |
| **T5 (Find*)** | `Bootstrap.cs`, `Installer.cs`, `*Initializer.cs` | 면제 | 부트스트랩 1회성 접근. |
| **T5 (Find*)** | 커스텀 `Editor`, `EditorWindow` | 면제 | 에디터 툴은 DI 대상 아님. |
| **전체** | 커스텀 `Editor/` 폴더 내 코드 | 완화 | 에디터 확장은 자유도 허용. |

**처리 구분**:
- **면제**: 체크 통과로 간주 (`[✓]`)
- **완화**: 기준값을 해당 파일에만 다르게 적용
- **INFO 격하**: 실패지만 pass/fail 카운트에는 반영 안 함. 별도 `INFO` 섹션에만 표시.

예외 판단이 애매하면 격하보다 **실패로 남겨두는 쪽이 안전**하다. 사용자가 직접 예외 규칙을 `rules/audit-rules.md`에 추가할 수 있음을 리포트 하단에 안내.

### 6단계: 리포트 출력

```
## /ft:audit {대상} 결과

### 대상
- 분석 파일: {n}개 (제외: 테스트 {t}개, 외부 {e}개, 예외 면제 {x}개)
- 규칙 파일: {외부 규칙 파일 경로 또는 "없음 (내장 12체크)"}
- 범위: {피처 경로 또는 --all 또는 --since HEAD~N}

### 책임분리 (SRP) — {pass}/4 통과

[✓] S1. 파일 LOC ≤ 400
[✗] S2. 클래스당 public 메서드 ≤ 10
    - WaveManager.cs `WaveManager` 13개
    - SkillController.cs `SkillController` 11개
    → 제안: WaveManager를 WaveCore(로직) + WaveState(상태)로 분리
[✓] S3. 클래스당 인스턴스 필드 ≤ 15
[✗] S4. 한 파일의 using ≤ 12
    - EnemySpawnSystem.cs 14개 (ECS 시스템 예외 미적용 — 실제 과다)
    → 제안: 중복/미사용 using 정리, 필요하면 도우미 클래스 분리

### 유지보수성 — {pass}/3 통과

[✓] M1. 순환 의존 없음 (네임스페이스 단위)
[✗] M2. 메서드 최대 길이 ≤ 50줄
    - SkillController.cs `Tick()` 87줄
    - FireContextBuilder.cs `BuildContext()` 62줄
    → 제안: Tick()의 단계별(검출/쿨다운/발사/이펙트) 분리
[✗] M3. 핫스팟 과밀 없음
    - WaveManager.cs   변경 23회 × LOC 412 = 9476
    - SkillController.cs 변경 18회 × LOC 287 = 5166
    → 제안: 분리 리팩토링이 S2/M2 실패와 겹침 — 같이 해결 가능

### 테스트 용이성 (Humble Object) — {pass}/5 통과

[✗] T1. MB 비-훅 public 메서드 ≤ 3
    - WaveManager.cs 8개 (StartWave, StopWave, SkipWave, SetDifficulty, ...)
    → 제안: WaveLogic plain class로 로직 이동, MB는 Tick 호출만
[✓] T2. Update/FixedUpdate 본문 ≤ 20줄
[✗] T3. Time/Random/Input 직접 호출 없음
    - GunAttackPattern.cs:42 `Time.time`
    - SwordAttackPattern.cs:68 `Time.deltaTime`
    - 외 1개
    → 제안: `ITimeProvider` 주입 (InGameCore.Timing 또는 신규)
[✓] T4. static 가변 상태 없음
[✗] T5. Instance / FindObjectOfType 직접 호출 없음
    - AreaDamageAttackPattern.cs:87 `FindObjectOfType<WaveManager>()`
    → 제안: VContainer `[Inject]`로 생성자 주입

### INFO (격하된 예외)

- GameContext.cs:12 — `static readonly` singleton (T4 대상이지만 레거시 DI 전환 전)
- PlayerBootstrap.cs:34 — `FindObjectOfType` (부트스트랩 1회성 — T5 면제)

### 실패가 많은 파일 (리팩토링 우선순위)

1. **WaveManager.cs**      — 3개 실패 (S2, M3, T1)
2. **SkillController.cs**  — 2개 실패 (S2, M2)
3. **GunAttackPattern.cs** — 1개 실패 (T3)

### 요약

- 전체: 6/12 통과
- 핵심 부채: **WaveManager.cs** — 여러 체크가 한 파일에 몰림. 먼저 리팩토링 권장.
- 다음 액션:
  - 구현 시작: `/ft:build "WaveManager를 Core + State로 분리"`
  - 또는 `feature-writer`에게 위임

> 예외 규칙을 추가하고 싶다면: `rules/audit-rules.md`에 패턴 추가 후 재실행.
```

**리포트 원칙**:
- **통과한 체크도 보여준다** (`[✓]`) — 전체 건강도 한눈에 파악
- **실패한 체크의 근거는 상위 3개만 표시** — 더 있으면 `외 N개`로 축약
- 실패 옆에 **자연어 제안 1줄** — LLM 판단. "어떻게 고칠까" 방향 제시
- **실패가 많은 파일 섹션**이 리팩토링 우선순위 랭킹 역할
- **INFO 섹션**은 예외로 격하된 항목 — 실패 카운트 반영 안 함, 투명성 위해 표시

## 임계값 (초기값)

이 숫자는 고정이 아니다. 프로젝트에 따라 `rules/audit-rules.md`에서 재정의 가능(향후 확장).

| 체크 | 기본 임계값 | 예외 시 완화 값 |
|------|-------------|----------------|
| S1 LOC | 400 | Authoring/Config: 면제 |
| S2 public 메서드 | 10 | interface/abstract: 15 |
| S3 인스턴스 필드 | 15 | struct/IComponentData: 면제 |
| S4 using | 12 | ECS 시스템: 16 |
| M2 메서드 길이 | 50 | — |
| M3 핫스팟 | 변경 10회 × LOC 200 | — |
| T1 MB 비훅 메서드 | 3 | Bridge/Adapter: 6 |
| T2 Update 본문 | 20 | — |

## 체크리스트 빠른 참조

```
## 책임분리 (SRP) — 4개
[ ] S1. 파일 LOC ≤ 400
[ ] S2. 클래스당 public 메서드 ≤ 10
[ ] S3. 클래스당 인스턴스 필드 ≤ 15
[ ] S4. 한 파일의 using ≤ 12

## 유지보수성 — 3개
[ ] M1. 순환 의존 없음 (네임스페이스 단위)
[ ] M2. 메서드 최대 길이 ≤ 50줄
[ ] M3. 핫스팟 과밀 없음 (변경 횟수 × LOC)

## 테스트 용이성 (Humble Object) — 5개
[ ] T1. MB 비-훅 public 메서드 ≤ 3
[ ] T2. Update/FixedUpdate 본문 ≤ 20줄
[ ] T3. Time/Random/Input 직접 호출 없음
[ ] T4. static 가변 상태 없음
[ ] T5. Instance/FindObjectOfType 직접 호출 없음
```

## 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| 대상에 .cs 파일 없음 | "분석할 C# 파일이 없습니다" 안내 후 중단 |
| `--all` 시 파일 > 1000개 | "큰 범위입니다. 피처를 지정?" 확인 |
| Git 히스토리 없음 (신규 파일 다수) | M3 skip + 리포트에 `N/A` 표시 |
| `--since` 기간 내 변경 없음 | "해당 기간 내 변경된 파일 없음" 안내 |
| 메서드 길이 파싱 실패 (`{}` 짝 불일치) | 해당 파일의 M2/T2 skip + 경고 1줄 |
| Bridge/Bootstrap/Authoring 패턴 매칭 | 5단계 예외 해석에서 처리 |
| `*Tests.cs`, `_Tests/`, `ThirdParty/`, `Library/` | 감사 대상에서 제외 (1단계) |
| 자동 생성 파일 (`*.g.cs`, `*.designer.cs`) | 감사 대상에서 제외 |
| 규칙 파일 없음 | 내장 12체크만 사용 (정상 동작) |
| 외부 규칙 파일 파싱 실패 | 해당 규칙만 skip, 나머지는 계속 진행 |
| 한 파일이 여러 체크 실패 | "실패가 많은 파일" 섹션에서 종합 랭킹 |
| Feature.md 없는 폴더 | 감사는 정상 진행 (Feature.md는 ft:review/feature-writer 영역) |

## `--fix` 플래그는 지원하지 않는다

`ft:review --fix`와 달리, `ft:audit`은 **자동 수정을 제공하지 않는다.**

이유:
- 구조 변경(클래스 분리, DI 전환, plain class 추출)은 **의미론적 판단이 필요**함
- 자동화 위험이 크고, 잘못 적용하면 복구 비용이 크다
- 제안까지만 하고, 실제 구현은 `feature-writer` 에이전트 또는 `/ft:build` 커맨드에 인계하는 것이 안전

사용자가 제안을 받아들이기로 하면:
```
/ft:build "WaveManager를 WaveCore + WaveState로 분리"
```
또는 `feature-writer`에게 직접 위임.

## 경계

**한다:**
- 기존 코드의 구조적 건강도 12체크 (SRP / 유지보수성 / 테스트 용이성)
- Grep/Read/git 기반 정량 데이터 수집 (재현성 우선)
- Unity 특화 예외 해석 (Authoring, Bridge, Bootstrap, ECS System, struct 등)
- 외부 규칙 파일 로드 (있으면) — 프로젝트 확장 포인트
- 피처/파일/프로젝트 전체 단위 감사
- `--since`로 최근 변경 핫스팟 감지
- 카테고리별 pass/fail 체크리스트 리포트
- 실패 항목별 자연어 리팩토링 제안 1줄
- "실패가 많은 파일" 랭킹으로 리팩토링 우선순위 제시

**안한다:**
- diff 리뷰 (→ `ft:review`)
- 버그/보안/성능 검증 (→ `ft:review`)
- 코드 자동 수정 (`--fix` 없음)
- 점수화 (체크리스트만 — pass/fail로 충분)
- 테스트 작성/실행
- 아키텍처 변경 실행 (제안까지만)
- Feature.md 갱신 (→ `ft:review` / `feature-writer`)
- 규칙 파일 자동 생성 (사용자가 수동 작성)
