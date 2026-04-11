---
name: "ft:rules"
description: "프로젝트 규칙 관리 — 프로젝트 고유 규칙을 rules/ 폴더에 구조화된 md로 생성·갱신하고, 세션 시작 훅으로 자동 주입되게 설정한다. init(최초 설정), scan(분석 후 갱신 제안), add(개별 규칙 추가), list(현황) 네 모드. '규칙 만들어줘', '프로젝트 규칙 정리', 'rules 초기화', '훅 설정해줘' 같은 요청이 오면 이 커맨드를 사용한다."
---

# /ft:rules — 프로젝트 규칙 관리

프로젝트별 고유 규칙(아키텍처, 금지 패턴, 리뷰/감사용 규칙, 경험 기록)을 `rules/` 폴더에 구조화된 md 파일로 관리한다. 세션 시작 훅으로 매 대화에 주입되므로 **작성 단계부터 Claude가 규칙을 인지**한다.

## 왜 이 커맨드가 필요한가

1. **CLAUDE.md 산만함** — 프로젝트 규칙이 CLAUDE.md 한 파일에 섞여 있어 참조가 어렵다. 목적별 분리 필요.
2. **스킬 간 규칙 소스 공유** — `ft:review`, `ft:audit`이 규칙 파일을 기대하는데 수동으로 만들면 빠뜨리기 쉽다.
3. **훅 설정 자동화** — 매 세션 훅 설정을 사용자가 직접 `.claude/settings.json`에 쓰는 건 비효율. 커맨드가 자동 등록.
4. **작성 단계 인지** — 세션 시작 훅으로 규칙이 컨텍스트에 들어가면 **코드를 쓰기 전에** 규칙을 본다. 리뷰(`ft:review`)나 감사(`ft:audit`)에서 **잡기 전에 예방**.

## 4개 모드

| 모드 | 용도 | 호출 |
|---|---|---|
| `init` | 최초 설정 (rules/ 생성 + 초안 분석 생성 + 훅 등록) | `/ft:rules init` |
| `scan` | 기존 rules/ 유지한 채 코드 재분석, 추가/수정 제안 | `/ft:rules scan` |
| `add` | 개별 규칙 대화식 추가 | `/ft:rules add [파일] [id]` |
| `list` | 현황 표시 (파일·규칙·훅 상태) | `/ft:rules list` |

## rules/ 파일 구조

5개 파일로 분리한다. **각 파일 200줄 이내 유지**가 원칙. 초과하면 경고 + 분할 제안.

| 파일 | 역할 | 누가 읽음 |
|------|------|----------|
| `architecture.md` | 레이어 방향, DI 규칙, MB/ECS 경계, 네임스페이스 — **큰 골격** | 세션 훅 (Always) |
| `forbidden.md` | 금지 API, 금지 패턴 — **빨간불 목록** | 세션 훅 (Always) |
| `audit-rules.md` | `ft:audit` 특화 체크, 예외/면제, 임계값 재정의 | `ft:audit` |
| `review-rules.md` | `ft:review` 특화 금지 패턴 + 대안 코드 | `ft:review` |
| `learnings.md` | 과거 사례 기록 ("이렇게 해서 버그났다") | 세션 훅 (Always) |

**세션 훅은 `rules/` 전체를 주입**한다 (결정 C-3). INDEX 분리 없이 5개 파일 모두. 그래서 **각 파일을 작게 유지**하는 것이 핵심 제약이다.

## 규칙 포맷 (D 포맷)

모든 규칙은 이 포맷을 따른다:

```markdown
## {id}  [MUST|SHOULD|MAY]
**{원칙 한 문장}.** {구체적 기준 — 숫자나 패턴}

> **Why**: {왜 이 규칙이 존재하는지, 1~2줄}
> **대안**: {금지 대신 써야 할 것}
> **예외**: {이 규칙이 적용 안 되는 경우}
```

**필드 설명**:
- **id**: `kebab-case`. 다른 곳에서 참조 가능 (`ft:audit의 T1 → mb-lean 규칙`). 파일 내 유일.
- **강도**: `[MUST]` (어기면 BUG) / `[SHOULD]` (어기면 리팩토링 권장) / `[MAY]` (어기면 플래그만).
- **원칙**: 한 문장 + 구체 기준. 추상적이면 안 됨 ("좋은 코드 써라" ❌).
- **Why**: 1~2줄. 예외 판단의 근거가 되므로 필수.
- **대안**: "금지하면 뭘 써라"가 명확해야 실제 적용됨.
- **예외**: 규칙이 살아남는 핵심. 예외 없는 규칙은 1주일 뒤 주석 처리된다.

**예시 1**:

```markdown
## find-object  [MUST]
**`FindObjectOfType`, `GameObject.Find`를 런타임 코드에서 쓰지 않는다.**

> **Why**: DI 우회 → 테스트 고립 불가능, 참조 경로 추적 어려움, 초기화 순서 꼬임.
> **대안**: VContainer `[Inject]` 생성자·필드 주입.
> **예외**: `*Bootstrap.cs`, `*Installer.cs`, Editor 확장(`Editor/` 폴더).
```

**예시 2**:

```markdown
## mb-lean  [MUST]
**MB는 얇게 유지한다.** 비-훅 public 메서드 ≤ 3, Update 본문 ≤ 20줄.

> **Why**: 테스트 용이성(Humble Object). 로직을 plain class로 분리하면 Play 모드 없이 단위 테스트 가능.
> **대안**: 로직은 `XxxLogic` plain class, MB는 `_logic.Tick()` 호출만.
> **예외**: `*Bridge.cs`, `*Adapter.cs`, `*Connector.cs`는 경계 넘기가 역할이라 ≤6 허용.
```

---

## 모드 1: init — 최초 설정

`/ft:rules init`을 호출하면 **분석 → 초안 생성 → 사용자 검토 → 저장 → 훅 등록**을 순서대로 진행한다.

### 1단계: 사전 점검

1. **프로젝트 루트 확인** — 현재 디렉토리에 `.claude/` 또는 `CLAUDE.md`가 있으면 프로젝트 루트로 인식. 없으면 "프로젝트 루트에서 실행해주세요" 안내 후 중단.
2. **rules/ 폴더 존재 확인**:
   - 없음 → 2단계로 진행
   - 있음 → "이미 `rules/`가 존재합니다. (a) 덮어쓰기 / (b) 병합 / (c) 취소 중 선택해주세요" 질문
3. **`.claude/settings.json` 상태 확인** — 3단계(분석) 전에 미리 확인만.

### 2단계: 분석 소스 수집

아래 파일을 **있는 것만** 읽는다 (없으면 skip, 경고 없음):

| 소스 | 용도 | 추출 대상 |
|------|------|-----------|
| `CLAUDE.md` (루트/서브 디렉토리 모두) | 프레임워크, 패턴, Forbidden Patterns 섹션 | architecture, forbidden |
| `.claude/progress.md` | 진행 중 작업, 과거 완료 항목 | learnings 후보 |
| `.featurecraft/FEATURE_INDEX.md` | 피처 목록, 의존 관계, 로드맵 | architecture (피처 경계) |
| `.featurecraft/learnings/*.md` | 과거 학습 기록 | learnings |
| Feature.md들 (상위 N개 피처만, 최대 10개) | 피처별 주의사항·의존성 | architecture, audit-rules |
| `git log --oneline -30` | 최근 커밋 성격 | learnings (refactor/fix 커밋) |
| `.claude/` 이하 `memory/` | 개인 기억 (있으면) | learnings 참고만 |

**Feature.md 선정 기준**: `.featurecraft/FEATURE_INDEX.md`의 "stable" 상태 피처를 우선. 너무 많으면 상위 10개로 제한 (더 보고 싶으면 `scan` 모드로).

### 3단계: 초안 생성 (LLM 단계)

수집한 소스에서 규칙 후보를 추출하여 5개 파일의 초안을 생성한다. **D 포맷 강제.**

#### architecture.md 초안 (5~15 규칙)

CLAUDE.md의 "Key Frameworks", 로드맵의 리팩토링 Pillar, Feature.md의 의존성 섹션에서 추출:
- 레이어 방향 (예: `_Core → _Feature → UI` 역방향 금지)
- DI 원칙 (예: VContainer `[Inject]` 우선)
- MB/ECS 경계 (예: `*Bridge.cs`에서만 넘나듦)
- 네임스페이스 통일 규칙
- 피처 경계 (Feature.md 의존성 목록 내)
- Stats/Skills/Combat 프레임워크 사용 의무 (InGameCore 경유)

#### forbidden.md 초안 (10~30 규칙)

CLAUDE.md의 "Forbidden Patterns" 섹션, ft:audit의 T3/T5 체크 대상, 과거 버그 커밋에서 추출:
- `FindObjectOfType` / `GameObject.Find` 금지
- `Time.*` 직접 호출 금지 (MB 로직)
- `Debug.Log` 프로덕션 남김 금지
- 매 프레임 `new` / LINQ 금지 (모바일 GC)
- `async void` 금지
- static 가변 필드 금지

#### audit-rules.md 초안

`ft:audit`의 기본 12체크 외에, **이 프로젝트 특화 예외/추가**만:
- Unity 특화 예외 재정의 (Authoring/Bridge/Bootstrap 등 — `ft:audit` 기본값으로 충분하면 빈 파일)
- 임계값 재정의 (예: 기본 LOC 400 → 300으로 엄격화)
- 프로젝트 고유 체크 (예: "모든 Feature 폴더엔 Feature.md 필수")

#### review-rules.md 초안

`ft:review`의 RULE 카테고리가 참조할 금지 패턴 **상세 대안 코드**:
- `forbidden.md`와 중복되면 `forbidden.md`를 참조(`see forbidden.md#find-object`)만 하고 상세는 여기 두지 않는다.

#### learnings.md 초안

git log의 `fix:` / `refactor:` 커밋 중 중요한 것 1~3개를 사례로 기록:
```markdown
## wave-manager-monolith (2026-03)
**증상**: WaveManager가 412줄 + 8 public 메서드로 성장, 테스트 불가.
**해결**: WaveCore(로직) + WaveState(상태) plain class로 분리.
**교훈**: MB에 로직 쌓이면 계속 커진다. 처음부터 plain class로 뽑자.
```

비어도 OK — 템플릿 한두 개만 넣고 시작.

### 4단계: 초안 요약 제시

생성한 초안을 사용자에게 보여준다. **전체 내용이 아니라 요약**:

```
## rules/ 초안 생성 완료

### architecture.md (12 규칙, 187줄)
- [MUST] layer-direction — _Core → _Feature → UI 역방향 금지
- [MUST] namespace-unified — Com.Tjdtjq5.* 통일
- [MUST] feature-boundary — Feature.md 의존성 목록 밖 참조 금지
- [MUST] di-over-find — VContainer [Inject] 우선
- [SHOULD] mb-ecs-bridge — MB/ECS 경계는 *Bridge.cs에서만
- [SHOULD] ingamecore-usage — Stats/Skills는 InGameCore 경유
- ...

### forbidden.md (18 규칙, 156줄)
- [MUST] find-object — FindObjectOfType 금지
- [MUST] time-direct — MB에서 Time.* 직접 사용 금지
- [MUST] debug-log-prod — 프로덕션 Debug.Log 남김 금지
- ...

### audit-rules.md (4 규칙, 62줄)
- 임계값 재정의: LOC 400 → 350 (이 프로젝트 엄격화)
- 추가 예외: *Authoring.cs S3 면제
- ...

### review-rules.md (8 규칙, 98줄)
- 상세 대안 코드 포함

### learnings.md (2 사례, 45줄)
- wave-manager-monolith (2026-03)
- spatial-hash-gc-burst (2026-01)

### 전체: 5파일, 548줄 (훅 주입 시 약 12K 토큰)
```

### 5단계: 사용자 검토 대화

**질문 1**: "전체 초안 괜찮으세요? 아니면 개별 파일을 보고 싶으세요?"
- "괜찮다" → 6단계로
- "A 파일 보고 싶다" → 그 파일 전체 출력 → 수정 여부 대화 → 반복
- "특정 규칙 바꾸고 싶다" → 해당 규칙만 수정

**질문 2**: (수정 반영 후) "이 상태로 저장할까요?"
- 승인 → 6단계로
- 재수정 → 대화 반복

### 6단계: 파일 저장

1. `rules/` 폴더 생성 (없으면)
2. 5개 파일을 모두 Write
3. 각 파일 저장 후 **라인 수 체크** — 200 초과 시 사용자에게 경고:
   ```
   ⚠️ forbidden.md가 234줄입니다. 200줄 상한 초과.
   권장: 카테고리별로 forbidden-runtime.md / forbidden-perf.md로 분할.
   지금 분할할까요? (y/n)
   ```

### 7단계: 훅 등록

#### 7-A. `.claude/settings.json` 확인 및 준비

```bash
SETTINGS=".claude/settings.json"
if [ ! -d ".claude" ]; then
    mkdir -p ".claude"
fi
```

#### 7-B. 기존 settings.json 읽기

**파일 없음** → 새로 생성 (아래 7-D로).

**파일 있음** → `Read`로 읽고 JSON 파싱:
- `hooks.SessionStart` 배열 확인
- 배열 없으면 → 새 배열 생성
- 배열 있음 → 중복 체크 (동일 command 이미 등록됐는지)

#### 7-C. 훅 항목 구성

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "find rules -name '*.md' -type f 2>/dev/null | xargs cat 2>/dev/null"
    }
  ]
}
```

**명령 선택 근거**:
- `find ... | xargs cat`이 Windows bash / macOS / Linux 모두에서 동작
- `cat rules/*.md`는 glob 확장이 안정적이지 않을 수 있음 (특히 파일 없을 때)
- `2>/dev/null`로 에러 무시 (rules/ 없을 때도 세션 시작이 막히면 안 됨)

**이미 등록돼 있으면 skip**. 중복 체크는 command 문자열 일치로 판정.

#### 7-D. 파일 없을 때 전체 settings.json 생성

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "find rules -name '*.md' -type f 2>/dev/null | xargs cat 2>/dev/null"
          }
        ]
      }
    ]
  }
}
```

#### 7-E. 파일 있을 때 병합

`Read` → 파싱 → `hooks.SessionStart`에 항목 추가 (중복 아니면) → `Write`로 저장.

**주의**: 기존 SessionStart에 다른 훅이 있어도 **덮어쓰지 않고 배열에 append**. 사용자 기존 훅 보호 필수.

### 8단계: 검증

1. **파일 확인**: `ls rules/` — 5개 파일 존재 확인
2. **파싱 검증**: 각 파일을 Read해서 D 포맷 파싱 테스트 (ID 중복 검사, 강도 태그 누락 검사)
3. **훅 등록 확인**: settings.json에 훅 항목이 있는지 재확인
4. **크기 체크**: 각 파일 200줄 이내인지 재확인

### 9단계: 완료 안내

```
✅ /ft:rules init 완료

생성된 파일:
  - rules/architecture.md   (12 규칙, 187줄)
  - rules/forbidden.md      (18 규칙, 156줄)
  - rules/audit-rules.md    (4 규칙, 62줄)
  - rules/review-rules.md   (8 규칙, 98줄)
  - rules/learnings.md      (2 사례, 45줄)

훅 등록:
  - .claude/settings.json에 SessionStart 훅 추가 완료

다음 단계:
  - 새 세션을 시작하면 rules/가 자동으로 주입됩니다
  - 현재 세션에서 즉시 반영하려면 수동으로 Read 하거나 세션 재시작
  - 규칙 추가: /ft:rules add forbidden new-rule-id
  - 규칙 목록 확인: /ft:rules list
```

---

## 모드 2: scan — 분석 후 갱신 제안

`/ft:rules scan`은 기존 `rules/`를 **그대로 보존**한 채, 최신 코드·커밋·Feature.md를 재분석하여 **추가/수정/삭제 제안**을 리포트로 제시한다. 실제 파일 수정은 사용자 승인 후.

### 실행 흐름

1. **`rules/` 존재 확인** — 없으면 "`/ft:rules init`을 먼저 실행해주세요" 안내 후 중단.
2. **분석 소스 재수집** — init의 2단계와 동일.
3. **기존 규칙 로드** — 현재 `rules/*.md` 읽기, ID 목록 추출.
4. **차이 분석** (3축):
   - **추가 후보**: 분석 결과에 있지만 기존 규칙엔 없는 패턴
   - **수정 후보**: 기존 규칙의 임계값/대안이 현재 코드와 맞지 않는 경우
   - **완료 후보**: 과거에 "금지"했던 패턴이 이미 코드에서 사라졌다면 규칙이 더 이상 필요 없을 수 있음
   - **새 learnings**: 최근 `fix:`/`refactor:` 커밋 중 기록할 만한 것
5. **리포트 제시**:
   ```
   ## /ft:rules scan 결과
   
   ### 추가 권장 (5건)
   1. [forbidden] unity-find-first-object — Unity 2023+ `FindFirstObjectByType`도 같이 금지 권장
      근거: EnemyBridge.cs:42에서 사용 발견
   ...
   
   ### 수정 권장 (2건)
   1. [audit-rules] loc-threshold 300 → 350
      근거: 현재 코드의 p75 LOC가 280이라 300은 과도하게 엄격
   
   ### 완료 후보 (1건)
   1. [forbidden] old-input-system — Input.GetKeyDown 금지
      근거: 최근 30커밋에서 위반 사례 0건, 이미 Input System으로 이전 완료
   
   ### 새 learnings 후보 (2건)
   1. [learnings] ecs-baker-forgotten (2026-04)
      근거: 커밋 f5052e5c "refactor: Config 분기 적용" — Baker 수정 누락으로 빌드 실패
   ```
6. **사용자 승인 대화** — 항목별 "적용/보류/거절" 선택
7. **승인된 변경 적용** — 기존 파일 Edit/Write
8. **결과 보고**

### 주의

- **scan은 절대 파일을 덮어쓰지 않는다** (사용자 승인 전까지)
- **기존 ID를 함부로 바꾸지 않는다** — ID 변경은 참조 깨뜨림 (`ft:audit`의 T1 체크가 `mb-lean` 참조 중일 수 있음)

---

## 모드 3: add — 개별 규칙 추가

`/ft:rules add [파일] [id]`로 특정 파일에 규칙 하나를 대화식으로 추가한다.

### 인자

- `파일`: `architecture` / `forbidden` / `audit-rules` / `review-rules` / `learnings` 중 하나. 파일 이름 없이 `architecture`만 써도 OK.
- `id`: 추가할 규칙 ID. 생략 시 대화 중 물어봄.

### 실행 흐름

1. **파일 존재 확인** — 없으면 "`/ft:rules init`을 먼저 실행해주세요" 또는 빈 파일 생성 여부 질문.
2. **ID 중복 체크** — 이미 존재하면 "이미 있습니다. 수정하시겠습니까?" 질문.
3. **대화로 필드 수집**:
   - 강도: MUST / SHOULD / MAY 중 선택
   - 원칙 한 문장
   - 구체 기준 (숫자나 패턴)
   - Why
   - 대안
   - 예외 (선택)
4. **D 포맷으로 포매팅**
5. **파일 크기 프리체크** — 추가 후 200줄 초과 예상 시 경고 + 다른 파일 제안
6. **Edit로 파일 끝에 추가** (알파벳 순 정렬 안 함 — 사용자가 원하는 위치에 추가)
7. **검증** — 추가 후 파싱 테스트
8. **완료 안내**

### 대화 예시

```
User: /ft:rules add forbidden

Claude: forbidden.md에 규칙을 추가합니다. 규칙 ID를 알려주세요 (kebab-case).
User: singleton-mutation

Claude: 강도는? (MUST / SHOULD / MAY)
User: MUST

Claude: 원칙을 한 문장으로 알려주세요.
User: 싱글톤의 가변 상태를 외부에서 직접 수정하지 않는다

Claude: 구체 기준이 있나요? (숫자/패턴)
User: GameContext.Current.X = Y 같은 직접 필드 할당 금지

Claude: Why — 왜 이 규칙이 필요한가요?
User: 상태 변경 경로 추적 불가, 레이스 컨디션 가능

Claude: 대안 — 대신 무엇을 쓰나요?
User: GameContext.Current.UpdateX(y) 같은 메서드 경유

Claude: 예외 케이스가 있나요? (엔터만 치면 예외 없음)
User: 테스트 코드

Claude: 아래 규칙을 forbidden.md에 추가합니다:

## singleton-mutation  [MUST]
**싱글톤의 가변 상태를 외부에서 직접 수정하지 않는다.** GameContext.Current.X = Y 같은 직접 필드 할당 금지.

> **Why**: 상태 변경 경로 추적 불가, 레이스 컨디션 가능.
> **대안**: GameContext.Current.UpdateX(y) 같은 메서드 경유.
> **예외**: 테스트 코드.

확정? (y/n)
```

---

## 모드 4: list — 현황 표시

`/ft:rules list`는 현재 `rules/` 상태를 표시한다. 파일 수정 없음.

### 출력 내용

```
## /ft:rules list

### 파일별 현황
파일                   규칙 수    줄 수    상태
architecture.md         12        187      ✓ OK
forbidden.md            18        156      ✓ OK
audit-rules.md           4         62      ✓ OK
review-rules.md          8         98      ✓ OK
learnings.md             2         45      ✓ OK
---
합계                    44       548 / 1000

### 강도별 분포
MUST:    28
SHOULD:  12
MAY:      4

### 등록된 ID (파일별)
architecture.md:
  - layer-direction [MUST]
  - namespace-unified [MUST]
  - feature-boundary [MUST]
  - di-over-find [MUST]
  - mb-ecs-bridge [SHOULD]
  - ...

forbidden.md:
  - find-object [MUST]
  - time-direct [MUST]
  - ...

...

### 훅 상태
✓ .claude/settings.json에 SessionStart 훅 등록됨
  명령: find rules -name '*.md' -type f 2>/dev/null | xargs cat 2>/dev/null

### 경고
(없음)
```

**경고 섹션**에 표시될 수 있는 것:
- 200줄 초과 파일
- 중복 ID
- D 포맷 위반 규칙 (예: 강도 태그 누락)
- 훅 미등록
- `rules/` 폴더는 있지만 파일 없음

---

## 훅 설정 상세

### 왜 SessionStart 훅인가

- 세션 시작 시점에 stdout이 **additional context**로 주입됨
- 매 대화 시작마다 규칙이 Claude 컨텍스트에 들어감
- 작성 단계부터 인지 → `ft:review`/`ft:audit`으로 잡기 **전에** 예방

### 명령 선택 이유

```bash
find rules -name '*.md' -type f 2>/dev/null | xargs cat 2>/dev/null
```

- `find`: 크로스 플랫폼 안정적. Windows git-bash / macOS / Linux 전부 동일 동작.
- `cat rules/*.md`는 glob 확장이 shell에 따라 다르고, 파일 없을 때 "no match" 에러 발생 가능.
- `xargs cat`: 한 번에 모든 파일 내용 출력.
- `2>/dev/null`: `rules/` 없거나 파일 없어도 세션 시작이 막히면 안 되므로 에러 무시.

### 병합 전략

기존 `.claude/settings.json`이 있을 때:

1. **Read** → JSON 파싱
2. `hooks.SessionStart`가 배열이면 그대로 유지, 아니면 새 배열
3. 새 항목 (위 명령)이 **이미 같은 command로 등록됐는지 검사**
4. 미등록이면 배열에 push
5. **Write**로 저장

**중복 판정**: command 문자열 완전 일치로. 유사하지만 다른 훅(예: `cat rules/*.md`)은 별개 항목으로 취급.

### 수동 복원

자동 병합이 실패하거나 사용자가 직접 편집하고 싶다면, 아래 항목을 `hooks.SessionStart`에 추가:

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "find rules -name '*.md' -type f 2>/dev/null | xargs cat 2>/dev/null"
    }
  ]
}
```

---

## 파일 크기 제약

| 상황 | 처리 |
|------|------|
| 단일 파일 ≤ 200줄 | ✓ OK |
| 단일 파일 > 200줄 | ⚠️ 경고 + 분할 제안 |
| 단일 파일 > 300줄 | ⛔ `add` 모드에서 추가 차단, 분할 먼저 요구 |
| 전체 합 > 1000줄 | ⚠️ 토큰 주의 경고 (매 세션 ~20K 토큰) |

### 분할 제안 예시

```
⚠️ forbidden.md가 234줄로 200줄 상한을 초과했습니다.

분할 제안:
  forbidden-runtime.md — 런타임 금지 (find, time, instance 등, 12 규칙)
  forbidden-perf.md    — 성능 금지 (per-frame new, linq 등, 6 규칙)

지금 분할할까요? (y/n)
```

분할 승인 시:
1. 기존 파일을 읽고 규칙을 분류
2. 새 파일 2개 작성
3. 기존 파일 삭제
4. `ft:review` / `ft:audit`의 규칙 로딩이 여전히 동작하는지 확인 (글로브 `rules/forbidden*.md`는 문제 없음)

---

## 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| `rules/` 이미 존재 (init 시) | 덮어쓰기/병합/취소 질문 |
| `.claude/settings.json` 존재하지만 파싱 실패 | 사용자에게 "직접 수정 후 재시도" 안내 |
| 기존 SessionStart 훅과 충돌 | 배열에 append (덮어쓰지 않음) |
| `CLAUDE.md` 없음 | 분석 소스에서 skip, Feature.md/git log에만 의존 |
| Feature.md가 하나도 없음 | architecture.md 초안이 빈약해질 수 있음 → 경고 |
| git 저장소 아님 | git log skip, "learnings 초안은 수동 작성 필요" 안내 |
| 중복 ID 추가 시 (`add` 모드) | 기존 규칙 보여주고 수정 여부 질문 |
| 존재하지 않는 파일에 `add` | 빈 파일 생성 여부 질문 |
| 200줄 경고 무시하고 추가 강행 | `add` 모드에서 300줄 초과 시 차단 |
| learnings.md 빈 파일 | 허용 (템플릿 없어도 OK) |
| Windows 경로 구분자 문제 | 모든 경로는 `/` 사용 (git-bash 호환) |
| `rules/` 폴더 있지만 파일 0개 | `list`에서 "초기화 필요" 표시 |
| 포맷 위반 규칙 (D 포맷 아님) | `list`의 경고 섹션에 표시, `scan`에서 수정 제안 |
| 한 규칙이 너무 길어짐 (50줄+) | 경고 + "예시는 별도 섹션으로" 제안 |

---

## 경계

**한다:**
- `rules/` 폴더 생성 및 5개 파일 초안 자동 분석·생성
- `CLAUDE.md` / 로드맵 / Feature.md / git log 분석 기반 초안
- D 포맷 강제 (ID + 강도 + 원칙 + Why + 대안 + 예외)
- `.claude/settings.json`에 SessionStart 훅 등록 (없으면 생성, 있으면 병합)
- 파일 크기 200줄 상한 경고 + 분할 제안
- 규칙 추가/갱신/현황 표시 (init/scan/add/list)
- 중복 ID 감지, D 포맷 검증

**안한다:**
- 기존 `.claude/settings.json`의 다른 훅/설정 덮어쓰기 (병합만)
- 사용자 확인 없이 초안 저장 (항상 검토 단계 거침)
- 규칙 내용을 코드 수정으로 연결 (`ft:audit`/`ft:review` 영역)
- 규칙 위반 코드 자동 수정
- 기존 ID 임의 변경 (참조 깨뜨림)
- `rules/` 바깥 파일 생성
- 프로젝트 루트가 아닌 곳에서 실행 (안전장치)
