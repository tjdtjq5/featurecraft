---
name: fc-dev
description: "플러그인 개발 — featurecraft 플러그인의 스킬/훅을 수정하고, 버전을 올리고, GitHub에 배포한다. '플러그인 수정', '스킬 수정', '버전 올려줘', '배포해줘', '업데이트 반영', 'fc:dev' 같은 요청이 오면 이 스킬을 사용한다."
---

# /fc:dev — 플러그인 개발/배포

featurecraft 플러그인의 스킬, 훅, 설정을 수정하고 배포하는 워크플로우.

## 왜 이 스킬이 필요한가

플러그인을 수정하려면 여러 단계를 거쳐야 한다:
파일 수정 → plugin.json 버전 올리기 → 커밋 → push → 사용자에게 업데이트 안내.
이걸 매번 수동으로 하면 빠뜨리기 쉽다. 특히 버전 올리기를 잊으면 사용자가 업데이트해도 반영이 안 된다.

## 실행 흐름

### 모드 1: 스킬 수정
```
/fc:dev edit ft-build
```

1. 플러그인 루트 찾기 (`.claude-plugin/plugin.json` 검색)
2. 해당 스킬의 SKILL.md 읽기
3. 사용자와 대화하며 수정할 내용 파악
4. SKILL.md 수정
5. 관련 command 파일도 함께 수정 (있으면)
6. "수정 완료. `/fc:dev release`로 배포하세요." 안내

### 모드 2: 스킬 추가
```
/fc:dev add 스킬명
```

1. 플러그인 루트 찾기
2. `skills/{스킬명}/SKILL.md` 생성 (프론트매터 + 기본 구조)
3. `commands/{네임스페이스}/{스킬명}.md` 생성
4. 사용자와 대화하며 스킬 내용 작성
5. "추가 완료. `/fc:dev release`로 배포하세요." 안내

### 모드 3: 릴리스
```
/fc:dev release
```

1. 플러그인 루트 찾기
2. 변경 내역 확인 (`git diff`, `git status`)
3. 현재 버전 읽기 (`plugin.json`의 version)
4. 버전 올리기 제안:
   - 스킬 내용 수정 → patch (0.1.0 → 0.1.1)
   - 스킬 추가/삭제 → minor (0.1.0 → 0.2.0)
   - 구조 변경 → major (0.1.0 → 1.0.0)
5. 사용자 확인 후 plugin.json 버전 업데이트
6. 커밋 + push
7. **marketplace.json SHA 업데이트** — 이 단계를 빠뜨리면 `plugin install`이 구 버전을 가져온다:
   - 마켓플레이스 로컬 캐시 찾기: `~/.claude/plugins/marketplaces/featurecraft/`
   - `git pull` 로 최신화
   - `.claude-plugin/marketplace.json`의 `"sha"` 필드를 방금 push한 커밋의 **전체 40자 SHA**로 업데이트 (`git rev-parse HEAD`). 짧은 SHA를 쓰면 `plugin install`이 실패한다.
   - 커밋 + push (메시지: `chore: update marketplace SHA to v{버전}`)
8. 안내: "배포 완료. 사용자는 `claude plugin update featurecraft` 로 업데이트할 수 있습니다."

> **왜 SHA 업데이트가 필수인가:**
> 플러그인 설치 시스템은 `marketplace.json`의 `sha` 필드에 고정된 커밋을 체크아웃한다.
> 이 SHA를 업데이트하지 않으면, 아무리 push해도 `plugin install`은 옛 커밋을 가져온다.
> plugin.json 버전 + marketplace.json SHA 두 곳을 모두 올려야 완전한 배포다.

### 모드 4: 상태 확인
```
/fc:dev status
```

1. 플러그인 루트 찾기
2. 현재 버전 출력
3. 스킬 목록 + 각 SKILL.md 줄 수
4. 훅 목록
5. 미커밋 변경 사항
6. 마지막 배포일 (git log에서)

## 플러그인 루트 찾기

1. 현재 디렉토리에서 상위로 `.claude-plugin/plugin.json` 검색
2. 못 찾으면 → "플러그인 루트를 찾을 수 없습니다. 플러그인 폴더에서 실행해주세요." 안내

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
- 스킬/훅/커맨드 파일 수정/추가
- plugin.json 버전 업데이트
- 커밋 + push (릴리스 모드)
- 플러그인 상태 확인

**안한다:**
- 플러그인 삭제/제거
- 다른 사람의 플러그인 수정
- GitHub 리포 생성 (이미 있어야 함)
- 마켓플레이스 등록 (수동으로 해야 함)
