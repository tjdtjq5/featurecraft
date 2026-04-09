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

**복사 명령 (OS별)**:

- **Linux/macOS** (rsync 사용 가능):
  ```bash
  rsync -av --delete --exclude='.git' --exclude='marketplace.json' {source}/ {target}/
  ```

- **Windows git-bash 등 rsync 미설치 환경**: `cp` + `rm` 조합으로 대체. `diff -r` 결과를 기반으로 파일별 처리:
  ```bash
  # 예시: cache에만 있는 신규 파일 → 복사
  cp -r "$CACHE/agents/new-agent.md" "$MARKET/agents/new-agent.md"
  mkdir -p "$MARKET/rules" && cp "$CACHE/rules/usage.md" "$MARKET/rules/usage.md"

  # 예시: cache에 없고 marketplaces에만 있는 파일 → 삭제
  rm "$MARKET/scripts/old-script.sh"

  # 예시: 양쪽에 있지만 내용이 다른 파일 → 덮어쓰기
  cp "$CACHE/hooks.json" "$MARKET/hooks.json"
  ```

  실행 권한 있는 스크립트 복사 후에는 `chmod +x`를 잊지 말 것.

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

먼저 upstream에 직접 push 시도:
```bash
cd "$MARKET"
git add -A
git commit -m "{확정된 메시지}"
git push origin main
```

**결과에 따라 분기**:

- **성공** → 8단계로 진행
- **권한 에러 (403 / "permission denied")** → **대체 흐름: Fork + PR**로 전환 (아래 참조). 현재 git 계정이 upstream에 write 권한이 없음을 의미.
- **push 충돌 (non-fast-forward)**:
  ```bash
  git pull --rebase origin main
  git push origin main
  ```
  marketplaces는 일반 git 저장소이므로 rebase 사용 가능. 충돌 해결 불가 시 사용자에게 안내 후 중단.

#### 대체 흐름: Fork + PR (push 권한 없을 때)

`git push origin main`이 `403` 또는 "permission denied"로 실패할 때 이 흐름으로 전환한다.

**원인 진단**:
- 로컬 git credential helper가 upstream에 write 권한이 없는 계정으로 인증됨
- 회사 계정으로 개인 저장소에 push 시도 (또는 그 반대)
- `gh` CLI 계정과 `git` credential 계정이 다름 (display name vs 실제 login)

##### F-1. gh CLI 계정 및 권한 확인
```bash
gh auth status
# Logged in to github.com account {GH_USER}

gh api repos/{upstream_owner}/{repo_name} --jq '.permissions' 2>&1
```

- `push: true` 이면 credential helper 갱신만 필요:
  ```bash
  gh auth setup-git   # gh의 토큰을 git credential helper로 등록
  git push origin main
  ```
- `push: false` 이면 fork 흐름 사용 (아래 F-2~F-6).

##### F-2. Fork 존재 확인 / 생성
gh CLI의 display name이 실제 GitHub username과 다를 수 있으므로 실제 username부터 확인:
```bash
GH_USER=$(gh api user --jq '.login')
gh api repos/$GH_USER/{repo_name} --jq '.fork // false' 2>/dev/null
```

- **이미 fork 있음** → 다음 단계
- **fork 없음**:
  ```bash
  gh repo fork {upstream_owner}/{repo_name} --remote-name=fork --clone=false
  ```

fork remote가 로컬에 없으면 수동 추가:
```bash
git remote add fork https://github.com/$GH_USER/{repo_name}.git
```

(`gh repo fork`가 "already exists"를 보고하는 경우에도 remote는 추가 안 될 수 있으니 `git remote -v`로 확인하고 수동 추가.)

##### F-3. Feature 브랜치로 push
**`main`을 직접 덮어쓰지 않는다.** 항상 별도 feature 브랜치 생성:
```bash
BRANCH="feat/{변경 요약-kebab-case}"
git push fork HEAD:$BRANCH
```

`HEAD:$BRANCH`는 현재 로컬 커밋을 fork 저장소의 새 브랜치로 push한다.
기존 fork의 main은 건드리지 않으므로 안전.

##### F-4. PR 생성
```bash
gh pr create --repo {upstream_owner}/{repo_name} \
  --base main \
  --head $GH_USER:$BRANCH \
  --title "{commit 제목}" \
  --body "$(cat <<'EOF'
## Summary
{변경 요약}

## Why
{근거}

## Version
{old} → {new}

## Test plan
- [ ] ...
EOF
)"
```

PR URL을 사용자에게 전달하고 **merge 요청**.

##### F-5. 사용자 merge 대기

사용자에게 안내:
> PR 링크: {PR_URL}
> 브라우저에서 검토 후 merge하시고, 완료되면 알려주세요.

사용자가 "merge 완료"를 알릴 때까지 작업 일시 정지.

##### F-6. merge 후 로컬 동기화 + 재설치
사용자가 merge 완료를 알리면:
```bash
cd "$MARKET"
git fetch origin
git merge --ff-only origin/main
```

`--ff-only`는 non-fast-forward를 거부하므로 안전. 로컬에 추가 커밋이 없다면 항상 성공.
divergent 상태면 사용자에게 수동 해결 안내 후 중단.

그 다음 8단계(재설치)로 진행.

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
| cache ↔ marketplaces 차이 존재 | 사용자에게 복사 방향 선택권 제시 (1단계) |
| 미커밋 변경 없음 + release | "릴리스할 변경이 없습니다" 안내 후 중단 |
| 존재하지 않는 스킬 edit | "스킬을 찾을 수 없습니다" 안내 |
| git 미설정 | "git init 먼저 실행하세요" 안내 |
| GitHub 미연결 | "git remote add origin 먼저 실행하세요" 안내 |
| **rsync 미설치** (Windows git-bash 등) | `cp` + `rm` 조합으로 대체 (1단계 "OS별 복사 명령" 참조) |
| **git push 권한 부족 (403)** | `대체 흐름: Fork + PR`로 자동 전환 (7단계 참조) |
| **gh CLI 계정과 upstream 소유자 불일치** | `gh api user --jq '.login'`로 실제 username 확인 후 fork 흐름 사용 |
| **기존 fork 존재** | `gh repo fork`가 "already exists" 알림 — remote가 자동 추가되지 않으므로 수동 `git remote add fork ...` 필요 |
| push 충돌 (non-fast-forward) | `git pull --rebase origin main` 후 재시도 |
| **`git reset --hard` 등 hook에 의해 차단** | `git merge --ff-only origin/main` 또는 `git checkout -B main origin/main`로 대체 |
| `claude plugin` 커맨드 실행 실패 | 사용자에게 수동 실행 안내 |

## 경계

**한다:**
- 스킬/커맨드/에이전트/rules/훅 파일 수정·추가
- plugin.json 버전 업데이트
- cache ↔ marketplaces 파일 동기화 (복구 경로)
- marketplaces에서 git commit + push
- **Fork + PR 흐름으로 대체 배포** (push 권한 없을 때)
- 플러그인 재설치 (cache 재구성)
- 플러그인 상태 확인

**안한다:**
- 플러그인 삭제/제거
- 다른 사람의 플러그인 수정
- GitHub 리포 생성 (이미 있어야 함)
- 마켓플레이스 등록 (수동으로 해야 함)
- cache 직접 편집 (예외: 복구 경로)
- fork의 main 직접 덮어쓰기 (항상 feature 브랜치 사용)
