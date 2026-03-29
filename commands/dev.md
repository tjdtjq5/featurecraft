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
6. **squash push** (detached HEAD 충돌 방지):
   cache 클론은 detached HEAD라 `git pull --rebase`하면 이전 커밋들이 replay되며 충돌한다.
   **절대 `git pull --rebase`를 사용하지 않는다.** 대신 squash 방식:
   ```bash
   # 1) remote 최신 가져오기
   git fetch origin main
   # 2) HEAD를 origin/main으로 이동 (변경사항은 스테이징에 보존)
   git reset --soft origin/main
   # 3) 모든 변경을 단일 커밋으로
   git add -A
   git commit -m "feat/fix: ..."
   # 4) push (rebase 불필요, origin/main 바로 위의 커밋이므로)
   git push origin HEAD:main
   ```
7. **marketplace SHA 업데이트** (같은 cache 클론에서):
   ```bash
   SHA=$(git rev-parse HEAD)
   sed -i "s/\"sha\": \".*\"/\"sha\": \"$SHA\"/" .claude-plugin/marketplace.json
   git add .claude-plugin/marketplace.json
   git commit -m "chore: update marketplace SHA to v{버전}"
   git push origin HEAD:main
   ```
8. **marketplaces 클론 동기화** (pull만, push 안 함):
   ```bash
   cd ~/.claude/plugins/marketplaces/featurecraft
   git pull origin main
   ```
9. **플러그인 재설치**:
   ```bash
   claude plugin uninstall ft@featurecraft
   claude plugin install ft@featurecraft
   ```
10. 안내: "배포 완료. 현재 세션에 이미 반영됨."

> **왜 squash 방식인가:**
> cache 클론은 설치 시점의 SHA에서 detached HEAD로 분기된다.
> `git pull --rebase`는 분기 이후의 모든 로컬 커밋을 remote 위에 하나씩 replay하는데,
> 이전 릴리스의 marketplace.json 수정 커밋이 매번 충돌을 일으킨다.
> `git reset --soft origin/main`은 히스토리를 replay하지 않고
> 현재 변경사항만 origin/main 위에 깨끗한 단일 커밋으로 올린다.
> **절대 cache 클론에서 `git pull --rebase`를 사용하지 말 것.**

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
