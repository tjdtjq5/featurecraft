---
name: ft-scan
description: "프로젝트 분석 및 피처 등록 — 기존 프로젝트를 분석하여 피처 등록 가능한 폴더를 분류하거나, 특정 폴더를 피처로 등록(Feature.md 역생성)한다. '프로젝트 분석', '피처 등록', '스캔', 'scan', '구조 파악', '피처로 만들어줘' 같은 요청이 오면 이 스킬을 사용한다."
---

# /ft:scan — 프로젝트 분석 / 피처 등록

기존 프로젝트를 분석하여 피처화 가능한 폴더를 분류하거나,
특정 폴더를 피처로 등록하여 Feature.md를 역생성한다.

## 왜 이 스킬이 필요한가

새 프로젝트는 /ft:plan부터 시작하면 되지만,
이미 코드가 있는 프로젝트에 피처 구조를 도입하려면 기존 코드를 분석해야 한다.
이 스킬이 없으면 기존 프로젝트에서 FeatureCraft를 쓸 수 없다.

## 두 가지 모드

### 모드 1: 분석 모드 (인자 없음)
```
/ft:scan
```
프로젝트 전체를 분석하여 피처 등록 가능 여부를 분류한 리포트를 생성한다.

### 모드 2: 등록 모드 (인자 있음)
```
/ft:scan InGame/Inventory
```
지정된 폴더를 피처로 등록하고 Feature.md를 역생성한다.

---

## 모드 1: 분석 모드

### 실행 흐름

#### 1단계: 기존 피처 파악
- Glob으로 프로젝트 내 모든 `**/Feature.md` 검색
- 이미 피처로 등록된 폴더 목록 수집

#### 2단계: 프로젝트 구조 탐색
- 주요 폴더들의 구조 파악 (1~2단계 깊이)
- 각 폴더에 어떤 파일이 있는지 분석
  - 스크립트 파일 (.cs, .ts, .py 등)
  - 설정/데이터 파일
  - 이미 있는 문서

#### 3단계: 분류
각 폴더를 아래 4가지로 분류한다:

| 분류 | 기준 | 예시 |
|------|------|------|
| **등록됨** | Feature.md가 이미 존재 | InGame/Inventory (Feature.md ✅) |
| **등록 가능** | 독립적 기능 단위, 스크립트 3개 이상 | InGame/Shop (자체 로직 있음) |
| **등록 어려움** | 유틸리티, 확장 메서드, 설정 모음 | Common/Extensions |
| **판단 필요** | 여러 기능이 혼재, 분리 필요 | InGame/Core (여러 책임 혼재) |

#### 4단계: 리포트 출력
분류 결과를 사용자에게 보여준다:

```
## 피처 스캔 결과

### 등록됨 (3개)
- InGame/Inventory ✅
- InGame/Shop ✅
- Network/Realtime ✅

### 등록 가능 (5개)
- InGame/Combat — 전투 로직 (스크립트 8개)
- InGame/Quest — 퀘스트 시스템 (스크립트 5개)
- UI/HUD — HUD 관련 (스크립트 4개)
- UI/Popup — 팝업 시스템 (스크립트 6개)
- Audio/BGM — BGM 관리 (스크립트 3개)

### 등록 어려움 (2개)
- Common/Extensions — 유틸리티 모음, 독립 피처 아님
- Config/ — 설정 파일 모음

### 판단 필요 (1개)
- InGame/Core — PlayerManager, GameManager 등 혼재. 분리 검토 필요

→ 등록하려면: /ft:scan InGame/Combat
```

---

## 모드 2: 등록 모드

### 실행 흐름

#### 1단계: 대상 폴더 확인
- 지정된 경로에 폴더가 존재하는지 확인
- 이미 Feature.md가 있으면 → "이미 피처로 등록되어 있습니다. 업데이트하시겠습니까?" 질문

#### 2단계: 코드 분석
대상 폴더의 코드를 분석한다:

- **파일 목록**: 스크립트, 데이터, 설정 파일 수집
- **공개 API 추출**: public 클래스/메서드 중 외부에서 참조할 만한 것 식별
- **의존성 분석**: using/import 문을 분석하여 다른 폴더의 코드 참조 파악
  - 프로젝트 내 다른 Feature.md가 있는 폴더를 참조하면 → 의존성으로 기록
  - Feature.md가 없는 폴더를 참조하면 → 의존성에 적되 "(미등록)" 표시

#### 3단계: Feature.md 생성
분석 결과로 Feature.md를 역생성한다:

```markdown
# {폴더명}

## 상태
stable

## 용도
{코드 분석 기반 한 줄 설명}

## 의존성
- ../Currency — CurrencyService 참조
- ../../Network/Realtime (미등록) — RealtimeClient 참조

## 구조
- Scripts/InventoryService.cs — 핵심 로직
- Scripts/InventoryUI.cs — UI 바인딩
- Scripts/ItemData.cs — 아이템 데이터 클래스
- Data/ItemTable.asset — 아이템 테이블

## API (외부 피처가 참조 가능)
- InventoryService.AddItem(itemId, count) → Scripts/InventoryService.cs
- InventoryService.RemoveItem(itemId, count) → Scripts/InventoryService.cs
- InventoryService.GetItemCount(itemId) → Scripts/InventoryService.cs

## 주의사항
(사용자 확인 필요)
```

#### 4단계: 사용자 확인
- 생성된 Feature.md를 보여주고 확인받기
- 용도, 주의사항은 사용자가 보완하도록 안내
- 상위 폴더에 Feature.md가 있으면 하위 피처 목록에 추가

## 의존성 자동 파악 상세

### 분석 방법
1. 대상 폴더의 모든 스크립트 파일 읽기
2. using/import 문 수집
3. 프로젝트 내 네임스페이스 → 폴더 매핑
4. 외부 폴더 참조를 의존성으로 변환

### 의존성 경로 생성
- 대상 폴더 기준 상대 경로로 기록
- Feature.md가 있는 폴더 → 일반 의존성
- Feature.md가 없는 폴더 → "(미등록)" 표시

## 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| 빈 폴더 | "스크립트가 없어서 피처로 등록하기 어렵습니다" 안내 |
| 스크립트 1~2개뿐 | 등록은 하되, "소규모 피처입니다" 표시 |
| 이미 Feature.md 존재 | "업데이트하시겠습니까?" 질문 (덮어쓰기 방지) |
| 대상 경로 없음 | "폴더를 찾을 수 없습니다. 경로를 확인해주세요." |
| public API가 없음 | API 섹션을 "(외부 참조 없음)"으로 표기 |
| 순환 의존성 감지 | 경고 + 리포트에 표시 |

## 피처 인덱스 (.featurecraft/FEATURE_INDEX.md)

분석 모드(/ft:scan 인자 없음) 또는 등록 모드 완료 후,
프로젝트 루트의 `.featurecraft/FEATURE_INDEX.md`를 자동 갱신한다.
이 파일이 없으면 새로 생성한다.

피처 인덱스는 모든 Feature.md를 3KB 이하로 압축한 전체 피처 맵이다.
세션 시작 시 이것만 읽으면 전체 피처 구조를 파악할 수 있어서 토큰을 절감한다.

### 포맷
```markdown
# Feature Index

> 자동 생성 — /ft:scan 실행 시 갱신됨

| 경로 | 피처명 | 상태 | 주요 API |
|------|--------|------|----------|
| InGame/Inventory | Inventory | stable | AddItem, RemoveItem, GetItemCount |
| InGame/Shop | Shop | stable | BuyItem, SellItem |
| InGame/Combat | Combat | stable | StartBattle, Calculate |
| InGame/Combat/Skill | Skill | stable | UseSkill, GetSkillList |
| InGame/Combat/Buff | Buff | wip | ApplyBuff, RemoveBuff, GetActiveBuffs |
```

### 갱신 시점
- `/ft:scan` (인자 없음) 실행 후
- `/ft:scan {경로}` 로 피처 등록 완료 후
- `/ft:plan` 으로 새 Feature.md 생성 후
- `/ft:build` 완료 후 Feature.md가 업데이트되었을 때

### 갱신 방법
1. 프로젝트 내 모든 `**/Feature.md` 검색 (Glob)
2. 각 Feature.md에서 피처명, 상태, API 목록 추출
3. 테이블로 정리하여 `.featurecraft/FEATURE_INDEX.md`에 저장

## 경계

**한다:**
- 프로젝트 구조 분석 + 피처 분류 리포트
- 코드 분석 기반 Feature.md 역생성
- using/import 기반 의존성 자동 파악
- 상위 Feature.md 업데이트 (하위 피처 추가)
- 피처 인덱스 자동 갱신

**안한다:**
- 코드 수정 (분석만)
- 폴더 이동/재구조화
- 자동으로 Feature.md 일괄 생성 (하나씩 확인받기)
- 피처 삭제/제거
