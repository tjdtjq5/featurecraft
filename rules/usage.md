# ft Plugin Usage Guide

이 플러그인은 **Git · UPM 패키지 워크플로 핀포인트 커맨드** 모음입니다.
범용 코드 하네스(에이전트/설계/룰/스킬 생성/셋업)는 0.18.0에서 제거되어 전용 오픈소스 하네스에 위임합니다.

---

## 커맨드 (명시 호출)

| 스킬 | 용도 |
|------|------|
| `/ft:push` | 커밋 → PR → 머지 한방 |
| `/ft:pull` | 기본브랜치 최신 반영 |
| `/ft:release` | dev → main 릴리스 |
| `/ft:pkg-dev` | UPM 패키지 로컬 개발 모드 ON/OFF |
| `/ft:pkg-list` | UPM 패키지 목록 + 업데이트 확인 |
| `/ft:pkg-publish` | UPM 패키지 배포 |
| `/ft:dev` | 플러그인 자체 수정/배포 |

### 사용자 확인 필요 (커맨드 제안)

| 키워드 | 제안 |
|--------|------|
| "커밋하고 머지", "한 번에 반영", "PR 만들어서 머지" | `/ft:push` |
| "기본브랜치 최신", "dev 반영", "최신 받아줘" | `/ft:pull` |
| "릴리스해줘", "main 배포" | `/ft:release` |
| "패키지 배포", "UPM 올려줘" | `/ft:pkg-publish` |

---

## 코드 작업은 어디로?

범용 코드 작성/진단/감사/탐색, 설계 대화, 프로젝트 룰, 스킬 생성은 ft가 더 이상 제공하지 않는다.
다음 도구를 사용한다 (프로젝트 환경에 맞게):

| 작업 | 도구 |
|------|------|
| 코드 작성/수정 | 기본 도구(Edit/Write) 또는 채택한 외부 코딩 에이전트 |
| 버그 진단 | `context-mode:diagnose` |
| 구조 감사 | wshobson `comprehensive-review` 등 외부 에이전트 |
| 설계 대화 | `context-mode:grill-me` / 내장 Plan mode |
| 스킬 생성 | 공식 `skill-creator` |
| C# 심볼/참조 탐색 | `cwm-roslyn-navigator` MCP 직접 사용 |
