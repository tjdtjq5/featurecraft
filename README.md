# ft (FeatureCraft)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.18.0-blue.svg)](https://github.com/tjdtjq5/featurecraft/releases)

> Git · UPM 패키지 워크플로를 **1회 호출**로 처리하는 핀포인트 Claude Code 커맨드 모음.

## 해결하는 문제

매번 사용자가 워크플로(커밋 → PR → 머지, 패키지 배포 등)를 손으로 챙겨야 한다.
ft는 자주 반복되는 Git/패키지 절차를 정해진 순서대로 **한 번에** 실행한다.

> **0.18.0 변경**: 범용 코드 하네스(코드 작성/진단/감사/탐색 에이전트, 설계 대화, 룰·훅 관리, 스킬 생성, 도구 셋업)를 제거했다.
> 이 영역은 전용 오픈소스 하네스(wshobson/agents, context-mode, 공식 skill-creator 등)에 위임한다.
> ft는 **Git/패키지 핀포인트 + 플러그인 자체 유지보수**만 담당한다.

## 설치

```bash
# 마켓플레이스 등록
claude plugin marketplace add github:tjdtjq5/featurecraft

# ft 플러그인 설치
claude plugin install ft@featurecraft
```

## 커맨드

| 카테고리 | 명령 | 역할 |
|---------|------|------|
| **Git** | `/ft:push` | 커밋 → PR → 머지 한방 |
| | `/ft:pull` | 기본브랜치 최신 반영 |
| | `/ft:release` | dev → main 릴리스 |
| **패키지 (UPM)** | `/ft:pkg-dev` | UPM 로컬 개발 모드 ON/OFF |
| | `/ft:pkg-list` | 설치 패키지 + 업데이트 확인 |
| | `/ft:pkg-publish` | UPM 패키지 배포 (모노레포 복사 + 버전 범프 + 태그 + push) |
| **메타** | `/ft:dev` | ft 플러그인 자체 수정/배포 |

## 워크플로 예시

```
작업 완료
  ↓
/ft:push        # 커밋 + PR + 머지
  ↓
/ft:release     # dev → main
```

```
패키지 수정
  ↓
/ft:pkg-dev     # 로컬 file: 참조로 전환
  ↓ (수정)
/ft:pkg-publish # 모노레포 반영 + 버전 범프 + 배포
/ft:pkg-dev --off
```

## 이슈 / 기여

- **버그 리포트 / 기능 제안**: [github.com/tjdtjq5/featurecraft/issues](https://github.com/tjdtjq5/featurecraft/issues)
- **PR 환영**: 이슈에서 먼저 합의 후 PR 권장

## 라이센스

[MIT](LICENSE)
