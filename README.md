# FeatureCraft

Claude가 기존 코드를 참고하면서 피처 단위로 구조화된 개발을 하도록 만드는 플러그인.

## 해결하는 문제

> Claude는 기존에 만들어진 기능을 참고하지 않고 자기 방식으로 새로 만든다.
> 예: 바인딩 기능이 있는데도 그걸 사용하지 않고 UI를 새로 구현함.

FeatureCraft는 Feature.md 기반 의존성 체이닝으로 이 문제를 해결합니다.

## 설치

```bash
claude plugin marketplace add github:{owner}/featurecraft
claude plugin install featurecraft
```

## 빠른 시작

### 새 프로젝트
```
/ft:plan 인벤토리 시스템       → Feature.md 생성
/ft:build                     → 코드 구현 (기존 피처 API 자동 참조)
/review                       → 코드 리뷰
/git:push                     → 커밋 → PR → 머지
```

### 기존 프로젝트
```
/ft:scan                      → 프로젝트 분석 + 피처 분류 리포트
/ft:scan InGame/Inventory     → 해당 폴더를 피처로 등록 (Feature.md 역생성)
```

## 명령어 (8개)

### 피처 개발 (/ft:*)
| 명령 | 역할 |
|------|------|
| `/ft:plan` | 요구사항 정리 → Feature.md 생성 |
| `/ft:build` | Feature.md 의존성 체이닝 → 코드 구현 |
| `/ft:scan` | 프로젝트 분석 / 기존 폴더 피처 등록 |

### 코드 리뷰
| 명령 | 역할 |
|------|------|
| `/review` | 5관점 리뷰 (버그/보안/성능/구조/AI슬롭) |
| `/review --fix` | 리뷰 + 안전 항목 자동 수정 |

### Git (/git:*)
| 명령 | 역할 |
|------|------|
| `/git:push` | 커밋 → PR → 머지 한방 |
| `/git:pull` | 기본브랜치 최신 반영 |
| `/git:release` | dev → main 릴리스 |

### 플러그인 개발 (/fc:*)
| 명령 | 역할 |
|------|------|
| `/fc:dev status` | 플러그인 상태 확인 |
| `/fc:dev edit {스킬}` | 스킬 수정 |
| `/fc:dev add {스킬}` | 스킬 추가 |
| `/fc:dev release` | 버전 올리기 + 배포 |

## 핵심 개념

### Feature.md
피처 폴더 루트에 있는 마크다운 파일. Claude가 참고하는 "지도" 역할.

```markdown
# Inventory

## 상태
stable

## 용도
인게임 아이템 소지/관리

## 의존성
- ../Shop — 상점 연동

## 구조
- Scripts/InventoryService.cs — 핵심 로직

## API (외부 피처가 참조 가능)
- InventoryService.AddItem(itemId, count) → Scripts/InventoryService.cs

## 주의사항
- 수량 음수 불가
```

### 의존성 체이닝
`/ft:build` 실행 시 Feature.md의 의존성을 따라가며 관련 피처의 API를 자동으로 읽고 활용합니다. 기존 코드를 무시하고 새로 만드는 문제를 방지합니다.

### 자동 감지 (훅)
피처 폴더에서 작업하면 Feature.md 컨텍스트가 자동으로 표시됩니다. 명시적으로 `/ft:build`를 호출하지 않아도 피처 정보를 참고할 수 있습니다.

### 경험 학습
`/ft:build` 중 발견한 프로젝트 특유의 패턴을 `.featurecraft/learnings/`에 저장합니다. 다음 빌드 시 자동으로 참고합니다.

### 피처 인덱스
`.featurecraft/FEATURE_INDEX.md`에 전체 피처 목록이 3KB 이하로 압축됩니다. 세션 시작 시 빠르게 프로젝트 전체 구조를 파악할 수 있습니다.

## 프로젝트 구조 예시

```
MyProject/
├── InGame/
│   ├── Inventory/
│   │   ├── Feature.md          ← 피처 마커
│   │   └── Scripts/
│   ├── Shop/
│   │   ├── Feature.md
│   │   └── Scripts/
│   └── Combat/
│       ├── Feature.md          ← 상위 피처 (하위 목록 포함)
│       ├── Skill/
│       │   ├── Feature.md
│       │   └── Scripts/
│       └── Buff/
│           ├── Feature.md
│           └── Scripts/
└── .featurecraft/
    ├── FEATURE_INDEX.md        ← 자동 생성
    └── learnings/              ← 자동 생성
```

## 플래그

| 플래그 | 스킬 | 동작 |
|--------|------|------|
| `--fix` | `/review` | 안전 항목 자동 수정 |
| `--force` | `/ft:build` | Feature.md 없이 진행 |

## 설계 철학

SuperClaude와 OhMyClaude의 장점을 흡수하고 단점을 제거했습니다.

**흡수한 것:**
- 명령 체이닝, 경계 패턴, 자동수정 기준 (SuperClaude)
- 모호성 체크, 자연어 트리거, 검증 루프, 경험 학습 (OhMyClaude)

**제거한 것:**
- MCP 의존성 6개 → 제로
- 페르소나 11개, 에이전트 19개 → 없음
- 30+개 명령 → 8개

## 라이센스

MIT
