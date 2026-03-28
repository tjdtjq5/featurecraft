---
name: "ft:pkg-list"
description: "UPM 패키지 목록 — 프로젝트에 설치된 패키지와 unity-packages 레포의 최신 버전을 비교하여 업데이트 필요 여부를 표시한다. '패키지 목록', '패키지 버전', '업데이트 확인', 'pkg list' 같은 요청이 오면 이 커맨드를 사용한다."
---

# /ft:pkg-list — UPM 패키지 목록

프로젝트에 설치된 자체 패키지의 현재 버전과 최신 버전을 비교한다.

## 실행 흐름

### 1단계: 프로젝트 패키지 수집

`Packages/manifest.json`에서 `com.tjdtjq5.*` 패키지를 찾는다.
URL에서 현재 설치 버전(태그)을 추출한다.

```json
"com.tjdtjq5.suparun": "https://github.com/tjdtjq5/unity-packages.git?path=Packages/com.tjdtjq5.suparun#suparun/v0.1.0"
```
→ 패키지: suparun, 현재 버전: v0.1.0

### 2단계: 최신 버전 확인

unity-packages 레포에서 각 패키지의 최신 태그를 조회한다.

```bash
git ls-remote --tags https://github.com/tjdtjq5/unity-packages.git | grep "{패키지명}/v"
```

가장 높은 시맨틱 버전을 최신으로 판단.

### 3단계: 비교 결과 출력

```
UPM 패키지 상태:

| 패키지 | 현재 | 최신 | 상태 |
|--------|------|------|------|
| suparun | v0.1.0 | v0.1.0 | ✅ 최신 |
| addrx | v0.1.0 | v0.2.0 | ⚠ 업데이트 가능 |
| editor-toolkit | v0.3.0 | v0.3.0 | ✅ 최신 |

업데이트가 필요한 패키지: 1개
  addrx: v0.1.0 → v0.2.0
  manifest.json 변경: #addrx/v0.1.0 → #addrx/v0.2.0
```

### 4단계: 업데이트 제안

업데이트 가능한 패키지가 있으면:
- manifest.json 변경 내용을 보여준다
- "업데이트할까요?" 질문
- 승인 시 manifest.json 수정

## 추가: 로컬 개발 모드 감지

manifest.json에 `file:` 경로가 있으면 로컬 개발 모드 표시:

```
| addrx | (로컬 개발) | v0.2.0 | 🔧 /ft:pkg-dev --off 로 복원 |
```

## 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| manifest.json 없음 | "Unity 프로젝트가 아닙니다" |
| 자체 패키지 없음 | "com.tjdtjq5.* 패키지가 설치되지 않았습니다" |
| 네트워크 오류 | "git ls-remote 실패. 오프라인 상태?" |
| 태그 없는 패키지 | "아직 배포되지 않은 패키지입니다" |

## 경계

**한다:** manifest.json 읽기, git 태그 조회, 버전 비교, 업데이트 제안
**안한다:** 패키지 코드 수정, 자동 업데이트 (승인 필요)
