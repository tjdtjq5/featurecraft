---
name: "ft:pkg-dev"
description: "UPM 패키지 로컬 개발 모드 — manifest.json의 패키지 참조를 git URL에서 로컬 file: 경로로 전환하여 패키지를 직접 수정할 수 있게 한다. --off로 원격으로 복원. '패키지 수정', '로컬 개발', 'pkg dev', '패키지 편집모드' 같은 요청이 오면 이 커맨드를 사용한다."
---

# /ft:pkg-dev — UPM 패키지 로컬 개발 모드

manifest.json의 패키지 참조를 git URL ↔ 로컬 file: 경로로 전환한다.
패키지를 직접 수정하고 싶을 때 로컬 모드로 전환하고,
수정 완료 후 원격 모드로 복원한다.

## 왜 필요한가

UPM git 패키지는 `Library/PackageCache/`에 읽기 전용으로 설치된다.
패키지 코드를 수정하려면 manifest.json의 참조를 로컬 경로로 바꿔야 한다.
수동으로 하면 URL 복원을 잊거나, 경로를 잘못 적기 쉽다.

## 인자

```
/ft:pkg-dev {패키지명}        ← 로컬 개발 모드 ON
/ft:pkg-dev {패키지명} --off  ← 원격 모드로 복원
```

## 실행 흐름 — 로컬 모드 ON

### 1단계: 현재 상태 확인

`Packages/manifest.json`에서 대상 패키지를 찾는다.

```json
"com.tjdtjq5.addrx": "https://github.com/tjdtjq5/unity-packages.git?path=Packages/com.tjdtjq5.addrx#addrx/v0.1.0"
```

이미 `file:` 경로면 → "이미 로컬 개발 모드입니다." 안내 후 종료.

### 2단계: unity-packages 경로 확인

로컬 경로 후보를 탐색:
1. `../unity-packages/Packages/com.tjdtjq5.{패키지명}/`
2. 사용자에게 질문 (못 찾으면)

해당 폴더에 `package.json`이 있는지 확인.

### 3단계: manifest.json 변경

```json
// Before (git URL)
"com.tjdtjq5.addrx": "https://github.com/tjdtjq5/unity-packages.git?path=Packages/com.tjdtjq5.addrx#addrx/v0.1.0"

// After (로컬 경로)
"com.tjdtjq5.addrx": "file:../../unity-packages/Packages/com.tjdtjq5.addrx"
```

**원본 URL을 주석으로 보존** (복원용):
manifest.json은 JSON이라 주석 불가. 대신 별도 필드에 저장:

```json
"com.tjdtjq5.addrx": "file:../../unity-packages/Packages/com.tjdtjq5.addrx",
"com.tjdtjq5.addrx__remote": "https://github.com/tjdtjq5/unity-packages.git?path=Packages/com.tjdtjq5.addrx#addrx/v0.1.0"
```

### 4단계: 안내

```
로컬 개발 모드 활성화!
  패키지: com.tjdtjq5.addrx
  경로: ../../unity-packages/Packages/com.tjdtjq5.addrx

  이제 해당 경로에서 직접 코드를 수정할 수 있습니다.
  Unity가 자동으로 변경을 감지합니다.

  수정 완료 후:
  1. /ft:pkg-publish addrx patch  ← 새 버전 배포
  2. /ft:pkg-dev addrx --off      ← 원격 모드로 복원
```

## 실행 흐름 — 원격 모드 복원 (--off)

### 1단계: 현재 상태 확인

manifest.json에서 `file:` 경로인지 확인.
원격 URL이면 → "이미 원격 모드입니다." 안내 후 종료.

### 2단계: 원본 URL 복원

저장된 `__remote` 필드에서 복원:

```json
// Before
"com.tjdtjq5.addrx": "file:../../unity-packages/Packages/com.tjdtjq5.addrx",
"com.tjdtjq5.addrx__remote": "https://github.com/...#addrx/v0.1.0"

// After
"com.tjdtjq5.addrx": "https://github.com/...#addrx/v0.1.0"
// __remote 필드 제거
```

### 3단계: 최신 버전 확인

`/ft:pkg-list`와 동일하게 최신 태그를 조회.
새 버전이 있으면 자동으로 최신 태그로 업데이트:

```json
// 복원 시 최신 버전 반영
"com.tjdtjq5.addrx": "https://github.com/...#addrx/v0.2.0"
```

### 4단계: 안내

```
원격 모드로 복원되었습니다.
  패키지: com.tjdtjq5.addrx
  버전: v0.2.0 (최신)

  Unity에서 Resolve Packages를 실행하면 반영됩니다.
```

## 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| manifest.json 없음 | "Unity 프로젝트가 아닙니다" |
| 패키지가 manifest에 없음 | "해당 패키지가 설치되어 있지 않습니다" |
| unity-packages 로컬 경로 없음 | 사용자에게 경로 질문 |
| `__remote` 필드 없이 --off | git 태그에서 최신 URL 자동 생성 |
| 이미 로컬/원격 모드 | "이미 {모드}입니다" 안내 |

## 경계

**한다:** manifest.json 읽기/수정, 로컬 경로 확인, 원본 URL 보존/복원
**안한다:** 패키지 코드 수정, git 작업, 패키지 설치/삭제
