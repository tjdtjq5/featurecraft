---
name: "ft:pkg-publish"
description: "UPM 패키지 배포 — 프로젝트의 패키지 코드를 unity-packages 모노레포에 복사하고, 구조 검증 + 버전 범프 + 태그 + push를 한 번에 실행한다. '패키지 배포', 'publish', '패키지 올려줘', 'UPM 배포' 같은 요청이 오면 이 커맨드를 사용한다."
---

# /ft:pkg-publish — UPM 패키지 배포

프로젝트의 패키지 코드를 unity-packages 모노레포에 복사하고,
구조 검증 → 버전 범프 → 커밋 → 태그 → push를 한 번에 실행한다.

## 왜 이 커맨드가 필요한가

UPM git 패키지를 배포하려면 여러 단계를 거쳐야 한다:
파일 복사 → package.json 확인 → 버전 올리기 → 커밋 → 태그 → push.
이걸 수동으로 하면 빠뜨리기 쉽고, 특히 태그 형식을 잘못 지으면 설치가 안 된다.

## 인자

```
/ft:pkg-publish {패키지명} [patch|minor|major]
```

- `패키지명`: 패키지 식별자 (예: addrx, suparun)
- 버전 범프 타입: patch(기본), minor, major

## 실행 흐름

### 0단계: 환경 확인

1. unity-packages 레포 위치 찾기:
   - 현재 프로젝트와 같은 레벨: `../unity-packages/`
   - 없으면 → 사용자에게 경로 질문
2. 패키지 소스 위치 찾기:
   - 현재 프로젝트 내 `Assets/{패키지명}/` 또는 `Packages/com.tjdtjq5.{패키지명}/`
   - 없으면 → 사용자에게 경로 질문

### 1단계: 구조 검증

unity-packages 레포의 대상 폴더를 검증한다.
처음 배포면 자동 생성한다.

**필수 파일 체크:**

| 파일 | 검증 내용 |
|------|----------|
| `package.json` | name, version, displayName, description, unity 필드 존재 |
| `Runtime/*.asmdef` | name이 package.json의 name과 일치 |
| `Editor/*.asmdef` | Editor 전용 플랫폼 설정 |
| `README.md` | 존재 여부 |
| `CHANGELOG.md` | 존재 여부 |
| `*.meta` | 모든 파일/폴더에 .meta 존재 |

**검증 실패 시:**
- 구체적인 원인 설명 + 수정 방법 안내
- 자동 수정 가능한 항목은 수정 제안 ("meta 파일 2개 누락. 생성할까요?")
- **배포 중단** — 검증 통과해야 다음 단계 진행

### 2단계: 파일 복사

소스 → unity-packages 대상 폴더로 복사.

```
프로젝트: Assets/AddrX/Runtime/  →  unity-packages/Packages/com.tjdtjq5.addrx/Runtime/
프로젝트: Assets/AddrX/Editor/   →  unity-packages/Packages/com.tjdtjq5.addrx/Editor/
프로젝트: Assets/AddrX/Debug/    →  unity-packages/Packages/com.tjdtjq5.addrx/Debug/
```

**복사 규칙:**
- .cs, .asmdef, .meta, .md, .json, .asset 파일만 복사
- .obsidian/, Feature.md는 제외 (개발용)
- 기존 파일은 덮어쓰기

### 3단계: 버전 범프

package.json의 version을 범프:
- `patch`: 0.1.0 → 0.1.1 (버그 수정, 작은 변경)
- `minor`: 0.1.0 → 0.2.0 (기능 추가)
- `major`: 0.1.0 → 1.0.0 (호환성 깨짐)

### 4단계: CHANGELOG 업데이트

CHANGELOG.md 상단에 새 버전 엔트리 추가:
- git log에서 마지막 태그 이후 커밋 메시지 수집
- 날짜 + 버전 + 변경 요약

### 5단계: 커밋 + 태그 + Push

```bash
cd unity-packages
git add Packages/com.tjdtjq5.{패키지명}/
git commit -m "feat({패키지명}): v{새버전} — {변경 요약}"
git tag {패키지명}/v{새버전}
git push origin main --tags
```

### 6단계: 결과 보고

```
배포 완료!
  패키지: com.tjdtjq5.addrx
  버전: v0.1.0
  태그: addrx/v0.1.0

  설치 URL:
  https://github.com/tjdtjq5/unity-packages.git?path=Packages/com.tjdtjq5.addrx#addrx/v0.1.0

  manifest.json에 추가:
  "com.tjdtjq5.addrx": "https://github.com/tjdtjq5/unity-packages.git?path=Packages/com.tjdtjq5.addrx#addrx/v0.1.0"
```

## 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| 처음 배포 | 대상 폴더 + package.json + README + CHANGELOG 자동 생성 |
| 검증 실패 | 원인 설명 + 중단 (--force 없음) |
| unity-packages 레포 없음 | 경로 질문 |
| 태그 이미 존재 | "이미 {태그}가 존재합니다. 버전을 올려주세요." |
| 미커밋 변경 있음 | unity-packages에 미커밋 변경이 있으면 경고 |

## 경계

**한다:** 파일 복사, 구조 검증, 버전 범프, CHANGELOG 갱신, 커밋, 태그, push
**안한다:** 소스 코드 수정, 프로젝트 manifest.json 변경, force push
