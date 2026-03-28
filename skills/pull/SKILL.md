---
name: pull
description: "기본브랜치 최신 반영 — 기본브랜치의 최신 변경을 현재 브랜치에 병합한다. 'pull', '최신화', '업데이트', '동기화', '기본브랜치 반영' 같은 요청이 오면 이 스킬을 사용한다."
---

# /ft:pull — 기본브랜치 최신 반영

기본브랜치의 최신 변경을 현재 브랜치에 병합한다.

## 실행 흐름

### 0단계: 기본브랜치 감지
1. `gh repo view --json defaultBranchRef -q '.defaultBranchRef.name'`
2. 실패 시 `git remote show origin | grep 'HEAD branch' | sed 's/.*: //'`

### 1단계: 미커밋 변경 보호
- `git status`로 미커밋 변경 확인
- 있으면 → `git stash`

### 2단계: Fetch + Merge
- `git fetch origin {기본브랜치}`
- `git merge origin/{기본브랜치}`

충돌 시:
- 자동 해결 가능: 직접 해결 → 커밋
- 판단 필요: 사용자에게 안내
- 해결 불가: `git merge --abort` 후 안내

### 3단계: Stash 복원
- stash 했었으면 → `git stash pop`
- stash 충돌 시 → 안내

### 4단계: 결과 보고
- 반영된 커밋 수
- 충돌 해결 내역 (있었다면)

## 안전 규칙
- rebase 하지 않음 (merge only)
- force pull 하지 않음
- 브랜치 변경하지 않음

## 경계

**한다:**
- fetch, merge, stash 관리, 단순 충돌 해결

**안한다:**
- rebase, force pull, 브랜치 변경
