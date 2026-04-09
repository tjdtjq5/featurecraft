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

## 경로 정책

ft 플러그인은 두 경로에 존재한다:

- **주 저장소 (편집 대상)**: `~/.claude/plugins/marketplaces/{marketplace}/`
  - git 저장소 (`.git` 존재)
  - 모든 편집·커밋·push의 대상
  - `plugin.json`, `marketplace.json` 등 메타 파일 포함
- **cache (읽기 전용)**: `~/.claude/plugins/cache/{marketplace}/{plugin}/{version}/`
  - Claude Code가 실제로 읽는 설치본
  - git 저장소 **아님** — 단순 스냅샷
  - `plugin uninstall/install`로 재구성됨
  - **직접 편집하지 않는다** — git에 반영되지 않음

**원칙**:
- 모든 파일 편집은 **marketplaces**에서 한다
- 모든 git 작업은 **marketplaces**에서 한다
- cache는 배포 후 `plugin uninstall/install`로 자동 갱신된다
- 예외: 사용자가 cache에서 직접 편집한 경우, release 1단계에서 cache → marketplaces로 동기화한다 (복구 경로)

## 실행 흐름

### 모드 1: 스킬/커맨드/에이전트 수정
```
/ft:dev edit build
```

1. 플러그인 주 저장소 찾기 (`~/.claude/plugins/marketplaces/{marketplace}/`)
2. 대상 파일 읽기:
   - `skills/{이름}/SKILL.md`
   - `commands/{이름}.md`
   - `agents/{이름}.md`
   - `rules/{이름}.md`
3. 사용자와 대화하며 수정 내용 파악
4. **marketplaces 경로에서** .md 수정
5. "수정 완료. `/ft:dev release`로 배포하세요." 안내

### 모드 2: 스킬/커맨드/에이전트 추가
```
/ft:dev add 이름
```

1. 플러그인 주 저장소 찾기
2. 추가 유형 결정:
   - 자동 발동 (읽기/분석) → `skills/{이름}/SKILL.md`
   - 명시적 호출만 (쓰기/Git) → `commands/{이름}.md`
   - Claude가 위임하는 전문 실행기 → `agents/{이름}.md`
   - 세션 로드 컨텍스트 → `rules/{이름}.md`
3. 사용자와 대화하며 내용 작성
4. **marketplaces 경로에** 파일 생성
5. "추가 완료. `/ft:dev release`로 배포하세요." 안내

### 모드 3: 릴리스
```
/ft:dev release
```

#### 0단계: 경로 및 환경 확인
- 주 저장소: `~/.claude/plugins/marketplaces/{marketplace}/`
- 해당 저장소가 git 저장소인지 확인 (`.git` 디렉토리 존재)
- git 저장소가 아니면 "git init + remote add 먼저" 안내 후 중단

#### 1단계: cache ↔ marketplaces 동기화 체크
```bash
CACHE_VERSION=$(jq -r '.plugins."{plugin}@{marketplace}"[0].version' ~/.claude/plugins/installed_plugins.json)
CACHE="$HOME/.claude/plugins/cache/{marketplace}/{plugin}/$CACHE_VERSION"
MARKET="$HOME/.claude/plugins/marketplaces/{marketplace}"

diff -r "$CACHE" "$MARKET" --brief 2>&1 | grep -v "\.git\|marketplace\.json"
```

차이가 있으면 사용자에게 선택지 제시:
- **(a) cache → marketplaces 복사** — 사용자가 cache에서 직접 편집한 경우 (복구)
- **(b) marketplaces → cache 복사** — 사용자가 marketplaces에서 편집한 경우 (정상)
- **(c) 무시하고 진행** — 사용자가 차이를 이해할 때

복사: `rsync -av --exclude='.git' --exclude='marketplace.json' {source}/ {target}/`

차이가 없거나 복사 완료 후 2단계로.

#### 2단계: 변경 내역 확인
```bash
cd "$MARKET"
git status --short
git diff --stat
```

변경 없음 → "릴리스할 변경이 없습니다" 안내 후 중단.
변경 있음 → 파일 목록을 사용자에게 보여준다.

#### 3단계: 현재 버전 읽기
`$MARKET/.claude-plugin/plugin.json`의 `version` 필드.

#### 4단계: 버전 올리기 제안
변경 유형에 따라:
- 스킬/커맨드/에이전트 **내용 수정만** → PATCH (0.9.1 → 0.9.2)
- 스킬/커맨드/에이전트/rules/훅 **추가·삭제** → MINOR (0.9.1 → 0.10.0)
- **구조 변경, 호환성 깨짐** → MAJOR (0.9.1 → 1.0.0)

사용자 확인 후 결정.

#### 5단계: plugin.json 버전 업데이트
```bash
sed -i 's/"version": "[^"]*"/"version": "{새 버전}"/' "$MARKET/.claude-plugin/plugin.json"
```

#### 6단계: 커밋 메시지 작성
변경 파일 목록을 사용자에게 보여주고, 느슨한 초안 제시:
- `feat: ...` — 새 기능 추가
- `fix: ...` — 버그 수정
- `chore: ...` — 메타/도구 변경
- `refactor: ...` — 리팩터링
- `docs: ...` — 문서만

사용자와 대화하며 확정. 형식 강제하지 않음.

#### 7단계: git commit + push
```bash
cd "$MARKET"
git add -A
git commit -m "{확정된 메시지}"
git push origin main
```

**push 충돌 시**:
```bash
git pull --rebase origin main
git push origin main
```

marketplaces는 일반 git 저장소이므로 rebase 사용 가능. 충돌 해결 불가 시 사용자에게 안내 후 중단.

#### 8단계: 플러그인 재설치 (cache 재구성)
```bash
claude plugin uninstall {plugin}@{marketplace}
claude plugin install {plugin}@{marketplace}
```

재설치 후 `installed_plugins.json`의 `gitCommitSha`가 새 HEAD로 갱신되고, cache가 새 버전으로 재구성된다.

**`claude plugin` 커맨드 실행 실패 시** 사용자에게 수동 실행 안내:
```
다음 명령을 터미널에서 실행하세요:
  claude plugin uninstall {plugin}@{marketplace}
  claude plugin install {plugin}@{marketplace}
```

#### 9단계: 완료 안내
```
✅ 배포 완료
- 버전: {old} → {new}
- 커밋: {HEAD SHA 단축}
- cache: 재구성됨
- 에이전트/스킬/커맨드: 현재 세션에서 즉시 사용 가능
- hooks.json: 다음 세션부터 반영
```

> **현재 세션 반영 원리**:
> ft:dev는 marketplaces 저장소에서 편집·커밋·push한 뒤, `plugin uninstall/install`로 cache를 재구성한다.
> 에이전트·스킬·커맨드는 호출 시마다 cache에서 .md를 읽으므로, 재설치 직후 **현재 세션에서도 즉시 반영**된다.
> 단 **hooks.json은 세션 시작 시점에 로드**되므로, 훅 변경은 다음 세션부터 반영된다.
> `plugin uninstall/install`은 `installed_plugins.json`의 버전/SHA를 갱신하여 다음 세션에서도 올바른 버전을 인식하게 한다.

### 모드 4: 상태 확인
```
/ft:dev status
```

1. 플러그인 주 저장소 찾기
2. 현재 버전 출력 (`.claude-plugin/plugin.json`)
3. 구성 요소 목록:
   - `agents/` 에이전트
   - `skills/` 스킬
   - `commands/` 커맨드
   - `rules/` 룰
4. `hooks.json` 훅 목록
5. git 상태 (`git status --short`)
6. 마지막 배포일 (`git log -1 --format="%ad" --date=short`)
7. cache 버전 (`installed_plugins.json`의 `version`)

## 플러그인 구조

```
{marketplace}/
├── .claude-plugin/
│   ├── plugin.json          ← 버전 관리
│   └── marketplace.json     ← 마켓플레이스 메타
├── agents/                  ← Claude가 위임하는 전문 실행기
│   ├── feature-explore.md
│   └── feature-writer.md
├── rules/                   ← 세션 로드 컨텍스트 (훅으로 주입)
│   └── usage.md
├── skills/                  ← 자동 발동 OK (읽기/분석)
│   ├── scan/SKILL.md
│   ├── review/SKILL.md
│   ├── roadmap/SKILL.md
│   ├── design/SKILL.md
│   └── skill-scan/SKILL.md
├── commands/                ← 명시적 호출만 (쓰기/Git)
│   ├── build.md
│   ├── push.md
│   ├── pull.md
│   ├── release.md
│   ├── dev.md
│   ├── pkg-dev.md
│   ├── pkg-list.md
│   ├── pkg-publish.md
│   └── skill-creator-project.md
├── scripts/                 ← 훅 스크립트
│   └── inject-ft-context.sh
├── hooks.json               ← 훅 등록
├── README.md
└── LICENSE
```

## 버전 규칙 (Semantic Versioning)

```
MAJOR.MINOR.PATCH

PATCH: 스킬/커맨드/에이전트 내용 수정, 버그 수정, 문서 개선
MINOR: 스킬/커맨드/에이전트/rules 추가·삭제, 훅 변경, 새 기능
MAJOR: 구조 변경, 호환성 깨짐
```

## 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| 플러그인 주 저장소 못 찾음 | 경로 안내 후 중단 |
| marketplaces가 git 저장소 아님 | `git init` + `git remote add origin` 안내 후 중단 |
| cache ↔ marketplaces 차이 존재 | 사용자에게 복사 방향 선택권 제시 |
| 미커밋 변경 없음 + release | "릴리스할 변경이 없습니다" 안내 후 중단 |
| 존재하지 않는 스킬 edit | "스킬을 찾을 수 없습니다" 안내 |
| git 미설정 | "git init 먼저 실행하세요" 안내 |
| GitHub 미연결 | "git remote add origin 먼저 실행하세요" 안내 |
| push 충돌 | `git pull --rebase origin main` 후 재시도 |
| `claude plugin` 커맨드 실행 실패 | 사용자에게 수동 실행 안내 |

## 경계

**한다:**
- 스킬/커맨드/에이전트/rules/훅 파일 수정·추가
- plugin.json 버전 업데이트
- cache ↔ marketplaces 파일 동기화 (복구 경로)
- marketplaces에서 git commit + push
- 플러그인 재설치 (cache 재구성)
- 플러그인 상태 확인

**안한다:**
- 플러그인 삭제/제거
- 다른 사람의 플러그인 수정
- GitHub 리포 생성 (이미 있어야 함)
- 마켓플레이스 등록 (수동으로 해야 함)
- cache 직접 편집 (예외: 복구 경로)
