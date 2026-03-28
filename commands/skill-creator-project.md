---
name: "ft:skill-creator-project"
description: "프로젝트 전용 스킬을 생성한다. 특정 패키지나 모듈을 Claude가 자동으로 참조하도록 강제하는 배경 지식 스킬을 만든다."
allowed-tools: Read, Grep, Glob, Write, Edit, Agent, Bash
---

# /ft:skill-creator-project — 프로젝트 전용 스킬 생성

특정 패키지/모듈을 분석하고, Claude가 해당 코드를 자동으로 참조하도록 강제하는 프로젝트 레벨 스킬을 생성한다.

## 사용법

```
/ft:skill-creator-project {패키지명 또는 폴더 경로}
```

예시:
- `/ft:skill-creator-project tjdtjq5.editortoolkit`
- `/ft:skill-creator-project Assets/Scripts/Core/NetworkManager`
- `/ft:skill-creator-project Packages/com.company.uiframework`

## 실행 흐름

### Step 1: 대상 찾기

$ARGUMENTS로 전달된 패키지명 또는 경로를 프로젝트에서 찾는다:

1. 정확한 경로면 → 바로 사용
2. 패키지명이면 → 아래 순서로 탐색:
   - `Packages/com.{name}/` (Unity 패키지 컨벤션)
   - `Packages/` 하위에서 package.json의 name 매칭
   - `Assets/` 하위에서 asmdef의 name 매칭
   - Glob으로 `**/*{name}*` 패턴 검색
3. 못 찾으면 → "해당 패키지를 찾을 수 없습니다. 정확한 경로를 알려주세요." 안내 후 중단

### Step 2: 코드 분석

해당 패키지/폴더의 코드를 Explore 에이전트로 철저히 분석한다:

**파악할 것:**
- 전체 파일 구조 (디렉토리 + .cs 파일 목록)
- public 클래스/struct/enum 목록
- 베이스 클래스 (상속해서 쓰는 것)
- static 유틸리티/헬퍼 메서드
- 주요 패턴과 컨벤션 (네이밍, 구조)
- 어셈블리 이름 + 네임스페이스
- 다른 패키지와의 의존 관계

**분석 결과를 사용자에게 요약해서 보여준다:**
```
## 분석 결과: {패키지명}
- 클래스: N개 (public M개)
- 베이스 클래스: ClassA, ClassB
- 유틸리티: HelperX, HelperY
- 어셈블리: Assembly.Name
- 네임스페이스: Namespace.Name
```

### Step 3: 사용자와 스킬 범위 확정

사용자에게 질문한다:

> "이 패키지를 어떤 상황에서 강제로 참조하게 할까요?"
>
> 예시:
> 1. 에디터 코드 작성 시
> 2. UI 코드 작성 시
> 3. 네트워크 관련 코드 작성 시
> 4. 모든 코드 작성 시
> 5. (직접 입력)

사용자 답변에 따라:
- description의 트리거 키워드 결정
- 스킬명 자동 제안 (패키지명에서 추출, 사용자 확인)

### Step 4: /skill-creator로 SKILL.md 생성

Step 1~3에서 수집한 정보를 `/skill-creator`에 전달하여 스킬을 생성한다.
`/skill-creator`는 테스트 케이스 작성, eval 루프, description 최적화까지 지원하므로 품질이 더 높다.

**`/skill-creator`에 전달할 프롬프트 구성:**

```
/skill-creator create .claude/skills/{스킬명}/SKILL.md

## 스킬 정보
- 이름: {스킬명}
- 위치: .claude/skills/{스킬명}/SKILL.md (프로젝트 레벨)
- 자동 발동: O
- user-invocable: false

## 스킬 목적
{발동 조건} 코드를 작성할 때 반드시 `{패키지명}` 패키지를 참조하고 활용하도록 강제한다.

## 발동 조건
{Step 3에서 사용자가 확정한 발동 조건 + 키워드}

## 강제 규칙
1. 코드 작성 전 {패키지 경로}의 코드를 먼저 읽고 파악
2. 패키지의 베이스 클래스/유틸리티가 있으면 반드시 사용
3. 패키지에 없는 기능만 직접 구현
4. 직접 구현 시에도 패키지의 스타일을 따름

## 패키지 분석 결과 (이 정보를 SKILL.md 본문에 포함할 것)
{Step 2에서 분석한 전체 결과를 여기에 붙여넣기}
- 패키지 경로: {경로}
- 어셈블리: {어셈블리명}
- 네임스페이스: {네임스페이스}
- 주요 클래스/API 목록
- 사용 패턴 예시
- 금지 사항 (패키지에 대응 API가 있는데 직접 구현하면 안 되는 것들)
```

**`/skill-creator`가 알아서 해줄 것:**
- SKILL.md 초안 작성
- 테스트 프롬프트 생성 + 실행 (사용자가 원하면)
- eval 루프로 반복 개선 (사용자가 원하면)
- description 최적화 (자동 트리거 정확도)

**중요:**
- 같은 이름의 스킬이 이미 있으면 → "이미 {경로}에 존재합니다. 덮어쓰시겠습니까?" 확인 (이건 /skill-creator 호출 전에 체크)
- `.claude/skills/` 폴더가 없으면 생성
- 프로젝트 레벨에만 생성 (글로벌 ~/.claude/skills/ 에는 절대 생성하지 않음)

### Step 5: 완료 안내

```
✓ 스킬 생성 완료: .claude/skills/{스킬명}/SKILL.md

이제 {발동 조건} 시 자동으로 {패키지명}을 참조합니다.
패키지 코드가 크게 변경되면 이 스킬도 업데이트가 필요합니다.

수정할 부분이 있으면 알려주세요.
```

## 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| 인자 없음 | "패키지명 또는 경로를 지정해주세요" 안내 |
| 패키지를 못 찾음 | 검색 결과 후보를 보여주고 선택 요청 |
| 이미 같은 이름 스킬 존재 | 덮어쓰기 확인 |
| 패키지에 코드가 없음 | "분석할 코드가 없습니다" 안내 |
| 패키지가 매우 큼 (100+ 파일) | 핵심 public API만 요약, 상세는 "패키지 코드를 직접 읽어라" 지시 |

## 경계

**한다:**
- 패키지/폴더 탐색 + 코드 분석
- 사용자와 대화로 스킬 범위 확정
- `.claude/skills/`에 SKILL.md 생성

**안한다:**
- 글로벌 스킬 생성 (~/.claude/skills/)
- 패키지 코드 수정
- asmdef 수정
- 코드 구현 (스킬 생성만)
