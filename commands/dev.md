---
name: "ft:dev"
description: "플러그인 개발 — ft 플러그인의 스킬/훅을 수정하고, 버전을 올리고, GitHub에 배포한다."
---

# /ft:dev — 플러그인 개발/배포

ft 플러그인의 스킬, 훅, 설정을 수정하고 배포하는 워크플로우.

## 왜 이 스킬이 필요한가

플러그인을 수정하려면 여러 단계를 거쳐야 한다:
파일 수정 → plugin.json 버전 올리기 → 커밋 → push → 사용자에게 업데이트 안내.
이걸 매번 수동으로 하면 빠뜨리기 쉽다. 특히 버전 올리기를 잊으면 사용자가 업데이트해도 반영이 안 된다.

## 실행 흐름

### 모드 1: 스킬 수정
```
/ft:dev edit build
```

1. 플러그인 루트 찾기 (`.claude-plugin/plugin.json` 검색)
2. 해당 스킬/커맨드의 .md 읽기 (skills/ 또는 commands/ 확인)
3. 사용자와 대화하며 수정할 내용 파악
4. .md 수정
5. "수정 완료. `/ft:dev release`로 배포하세요." 안내

### 모드 2: 스킬/커맨드 추가
```
/ft:dev add 스킬명
```

1. 플러그인 루트 찾기
2. 자동 발동이 안전한 것 → `skills/{스킬명}/SKILL.md` 생성
3. 명시적 호출만 할 것 → `commands/{스킬명}.md` 생성
4. 사용자와 대화하며 내용 작성
5. "추가 완료. `/ft:dev release`로 배포하세요." 안내

### 모드 3: 릴리스
```
/ft:dev release
```

1. 플러그인 루트 찾기
2. 변경 내역 확인 (`git diff`, `git status`)
3. 현재 버전 읽기 (`plugin.json`의 version)
4. 버전 올리기 제안:
   - 스킬 내용 수정 → patch (0.1.0 → 0.1.1)
   - 스킬 추가/삭제 → minor (0.1.0 → 0.2.0)
   - 구조 변경 → major (0.1.0 → 1.0.0)
5. 사용자 확인 후 plugin.json 버전 업데이트
6. **코드 + marketplace SHA를 한 번에 커밋 + push** (충돌 방지):
   - 코드 변경사항을 스테이징 (`git add -A`)
   - 커밋 (아직 push 안 함)
   - push → SHA 확정 (`git rev-parse HEAD`)
   - **같은 클론(cache)**에서 `.claude-plugin/marketplace.json`의 `"sha"` 필드를 방금 push한 커밋의 **전체 40자 SHA**로 업데이트
   - marketplace SHA 업데이트 커밋 + push (메시지: `chore: update marketplace SHA to v{버전}`)
   - 마켓플레이스 로컬 클론(`~/.claude/plugins/marketplaces/featurecraft/`)에서 `git pull`만 실행 (push 안 함, pull만)
7. **플러그인 업데이트 실행** — `installed_plugins.json`을 갱신해야 다음 세션에서도 반영된다:
   - `claude plugin uninstall ft@featurecraft && claude plugin install ft@featurecraft` 실행 (Bash 도구 사용)
8. 안내: "배포 완료. 현재 세션에 이미 반영됨."

> **왜 한 클론에서 모든 push를 해야 하는가:**
> 플러그인 소스와 marketplace.json이 같은 GitHub 리포에 있다.
> 두 개의 로컬 클론(cache + marketplaces)에서 각각 push하면
> marketplace.json에서 rebase 충돌이 반복 발생한다.
> **해결:** cache 클론에서 코드 + marketplace SHA를 모두 push하고,
> marketplaces 클론은 `git pull`로 동기화만 한다.

> **현재 세션 반영 원리:**
> ft:dev는 캐시 파일을 직접 수정한 뒤 push한다. 스킬/커맨드는 호출 시마다 .md를 캐시에서 읽으므로,
> 캐시가 수정된 현재 세션에서는 즉시 반영된다. `plugin update`는 `installed_plugins.json`의
> 버전/SHA를 갱신하여 **다음 세션**에서도 올바른 버전을 인식하게 하는 역할이다.

### 모드 4: 상태 확인
```
/ft:dev status
```

1. 플러그인 루트 찾기
2. 현재 버전 출력
3. 스킬 목록 (skills/) + 커맨드 목록 (commands/)
4. 훅 목록
5. 미커밋 변경 사항
6. 마지막 배포일 (git log에서)

## 플러그인 구조

```
featurecraft/
├── .claude-plugin/plugin.json
├── skills/          ← 자동 발동 OK (읽기/분석)
│   ├── plan/SKILL.md
│   ├── scan/SKILL.md
│   ├── review/SKILL.md
│   └── roadmap/SKILL.md
├── commands/        ← 명시적 호출만 (쓰기/Git)
│   ├── build.md
│   ├── push.md
│   ├── pull.md
│   ├── release.md
│   └── dev.md
├── scripts/
├── hooks.json
└── README.md
```

## 버전 규칙 (Semantic Versioning)

```
MAJOR.MINOR.PATCH

PATCH: 스킬 내용 수정, 버그 수정, 문서 개선
MINOR: 스킬 추가/삭제, 훅 변경, 새 기능
MAJOR: 구조 변경, 호환성 깨짐
```

## 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| 플러그인 루트 못 찾음 | 경로 안내 후 중단 |
| 미커밋 변경 + release | 자동으로 커밋 포함 |
| 존재하지 않는 스킬 edit | "스킬을 찾을 수 없습니다" 안내 |
| git 미설정 | "git init 먼저 실행하세요" 안내 |
| GitHub 미연결 | "git remote add origin 먼저 실행하세요" 안내 |

## 경계

**한다:**
- 스킬/커맨드/훅 파일 수정/추가
- plugin.json 버전 업데이트
- 커밋 + push (릴리스 모드)
- 플러그인 상태 확인

**안한다:**
- 플러그인 삭제/제거
- 다른 사람의 플러그인 수정
- GitHub 리포 생성 (이미 있어야 함)
- 마켓플레이스 등록 (수동으로 해야 함)
