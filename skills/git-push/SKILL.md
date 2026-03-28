---
name: git-push
description: "Git 커밋+PR+머지 한방 — 작업을 마무리하고 기본브랜치에 반영한다. '커밋해줘', '푸시해줘', '올려줘', 'push', '머지해줘', '작업 끝' 같은 요청이 오면 이 스킬을 사용한다. 코드 변경 후 Git에 반영하고 싶은 모든 상황에서 사용."
---

# /git:push — 커밋 → PR → 머지

작업 단위를 마무리하고 기본브랜치에 반영하는 전체 Git 플로우.
커밋부터 머지까지 한 번에 실행한다.

## 왜 한 번에 하는가

커밋 → push → PR 생성 → 머지를 매번 따로 하면 귀찮고 빠뜨리기 쉽다.
이 스킬은 전체 흐름을 자동화하되, 충돌 같은 판단이 필요한 순간에만 사용자에게 묻는다.

## 실행 흐름

### 0단계: 기본브랜치 감지
1. `gh repo view --json defaultBranchRef -q '.defaultBranchRef.name'`
2. 실패 시 `git remote show origin | grep 'HEAD branch' | sed 's/.*: //'`

### 1단계: 상태 확인
- `git status`로 변경사항 확인
- 변경 없으면 → "커밋할 내용이 없습니다" 안내 후 종료

### 2단계: 커밋
- `git diff`로 변경 내용 분석
- 인자가 있으면 커밋 메시지로 사용
- 없으면 변경 내용을 분석해서 적절한 커밋 메시지 자동 생성
- `git add` → `git commit`
- 커밋 메시지 끝에 `Co-Authored-By: Claude <noreply@anthropic.com>` 추가

### 3단계: Push + PR + Merge
현재 브랜치가 기본브랜치가 아닌 경우에만:

1. `git push origin {브랜치명}`
2. `gh pr list --head {브랜치명}` → 기존 PR 확인
3. 없으면 `gh pr create` (커밋 메시지를 PR 타이틀로)
4. `gh pr merge {PR번호} --merge`

충돌 시:
- `git fetch origin {기본브랜치}` → `git merge origin/{기본브랜치}`
- 자동 해결 가능 (import 추가, 공백, .meta): 직접 해결 → 재커밋 → 재push → 재merge
- 판단 필요 (로직 충돌): 사용자에게 선택지 제시
- 해결 불가: `git merge --abort` 후 상황 안내

### 4단계: 동기화
- `git fetch origin {기본브랜치}`
- `git merge origin/{기본브랜치}`

### 현재 브랜치가 기본브랜치인 경우
- PR/머지 불필요 → 커밋 + `git push origin {기본브랜치}` 만 실행

### 5단계: 결과 보고
- 커밋 해시 + 메시지
- PR 번호 + URL (있으면)
- merge 성공/실패

## 안전 규칙
- force push 절대 금지
- 모든 git/gh 명령은 개별 Bash 호출 (체이닝 금지 — 권한 매칭 실패 방지)
- `gh auth status` 실패 시 → 안내 후 중단

## 경계

**한다:**
- 변경사항 커밋, push, PR 생성, 머지, 동기화
- 단순 충돌 자동 해결
- 커밋 메시지 자동 생성

**안한다:**
- force push
- 브랜치 삭제
- rebase
- 복잡한 충돌을 물어보지 않고 해결
