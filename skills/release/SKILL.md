---
name: release
description: "릴리스 — dev(기본브랜치)에서 main으로 PR 생성 + 머지한다. '릴리스', 'release', 'main에 올려줘', '배포', 'main 머지' 같은 요청이 오면 이 스킬을 사용한다."
---

# /ft:release — dev → main 릴리스

기본브랜치(dev 등)의 변경사항을 main 브랜치로 PR 생성 + 머지한다.
릴리스/배포 시점에 사용한다.

## /ft:push와의 차이
| | /ft:push | /ft:release |
|---|---|---|
| 대상 | 현재 브랜치 → 기본브랜치 | 기본브랜치(dev) → main |
| 커밋 포함 | 자동 커밋 | 미커밋 있으면 중단 |
| 머지 방식 | 자동 (merge) | 사용자 선택 (merge/squash) |
| 용도 | 일상 작업 마무리 | 릴리스/배포 |

## 실행 흐름

### 1단계: 사전 확인
- 현재 브랜치 확인
- 미커밋 변경이 있으면 → "먼저 커밋하세요 (`/ft:push`)" 안내 후 중단
- main 브랜치 이름 확인 (`main` 또는 `master`)

### 2단계: Push
- `git push origin {현재브랜치}`

### 3단계: PR 확인/생성
- `gh pr list --base main --head {현재브랜치}` → 기존 PR 확인
- 있으면 → "기존 PR #{번호}를 사용하시겠습니까?" 질문
- 없으면 → `gh pr create --base main`

### 4단계: 머지 방식 선택
사용자에게 질문:
- merge (기본) — 모든 커밋 유지
- squash — 하나의 커밋으로 압축
- 취소

### 5단계: 머지 실행
- `gh pr merge {PR번호} --merge` 또는 `--squash`

### 6단계: 로컬 동기화
- `git fetch origin main`
- `git merge origin/main`

### 7단계: 결과 보고
- PR 번호 + URL
- 머지 방식
- 성공/실패

## 안전 규칙
- force push 절대 금지
- 미커밋 변경이 있으면 실행하지 않음
- 머지 방식은 사용자 선택

## 경계

**한다:**
- PR 생성, 머지 방식 선택, main 동기화

**안한다:**
- 자동 커밋 (미커밋 있으면 중단)
- 태그 생성, 릴리스 노트 작성
- force push
