---
name: "ft:setup"
description: "Claude Code 필수 외부 도구 자동 셋업 — 도구 목록 표시, 설치 여부 체크, 미설치 도구 자동 설치. uloop-cli, context-mode, CWM.RoslynNavigator 3개를 검증한다."
---

# /ft:setup — Claude Code 필수 도구 자동 셋업

Claude Code 워크플로에 필수적인 외부 오픈소스 도구를 한 번에 검증하고 설치한다.

## 왜 이 커맨드가 필요한가

Claude Code의 가치를 제대로 끌어내려면 외부 도구가 필요하다:

- **uloop-cli** — Unity 에디터를 CLI로 제어 (컴파일/씬/플레이모드/테스트)
- **context-mode** — 세션 컨텍스트 자동 관리 (컴팩트/재시작 시 상태 복원)
- **CWM.RoslynNavigator** — Roslyn 기반 코드 탐색 MCP (메서드 호출자/타입 계층/안티패턴)

새 환경 셋업이나 도구 누락 시 매번 수동으로 체크/설치하면 빠뜨리기 쉽다. 이 커맨드가 한 번에 처리.

## 필수 도구 목록 (하드코드)

| 도구 | 설치 명령 | 체크 명령 | 전제조건 |
|------|-----------|-----------|----------|
| `uloop-cli` | `npm install -g uloop-cli` | `command -v uloop` | Node.js 22+ |
| `context-mode` | `npm install -g context-mode` | `command -v context-mode` | Node.js |
| `CWM.RoslynNavigator` | `dotnet tool install -g CWM.RoslynNavigator` | `dotnet tool list -g \| grep -i CWM.RoslynNavigator` | .NET 10 SDK |

> **갱신 방법**: 이 표를 직접 편집한 뒤 `/ft:dev release`로 배포. 도구가 자주 바뀌지 않으므로 하드코드로 충분.

## 실행 흐름

### 1단계: 전제조건 점검

```bash
node --version    # 22+ 필요
dotnet --version  # 10.0.203+ 필요 (.NET 10 SDK)
```

- Node.js < 22 → "Node.js 22+ 필요. https://nodejs.org/ 에서 설치 후 재실행" 안내 후 중단
- .NET 10 SDK 미설치 → "winget install Microsoft.DotNet.SDK.10 또는 https://dotnet.microsoft.com/download 설치 후 재실행" 안내 후 중단

전제조건은 **자동 설치하지 않는다** — 시스템 패키지 매니저 / OS별 차이가 커서 위험.

### 2단계: 도구별 설치 여부 체크

각 도구를 체크 명령으로 확인:

```bash
# uloop-cli
if command -v uloop >/dev/null 2>&1; then
  UVER=$(uloop --version 2>/dev/null || echo "unknown")
  echo "✓ uloop-cli ($UVER)"
else
  echo "✗ uloop-cli (미설치)"
fi

# context-mode
if command -v context-mode >/dev/null 2>&1; then
  echo "✓ context-mode"
else
  echo "✗ context-mode (미설치)"
fi

# CWM.RoslynNavigator (dotnet tool)
if dotnet tool list -g 2>/dev/null | grep -qi "cwm.roslynnavigator"; then
  CVER=$(dotnet tool list -g | grep -i "cwm.roslynnavigator" | awk '{print $2}')
  echo "✓ CWM.RoslynNavigator ($CVER)"
else
  echo "✗ CWM.RoslynNavigator (미설치)"
fi
```

### 3단계: 리포트 출력

```
## /ft:setup 결과

### 전제조건
✓ Node.js v22.10.0
✓ .NET 10 SDK 10.0.203

### 도구 상태
✓ uloop-cli (v1.2.3)
✗ context-mode (미설치)
✗ CWM.RoslynNavigator (미설치)

### 설치 후보: 2개
- context-mode → npm install -g context-mode
- CWM.RoslynNavigator → dotnet tool install -g CWM.RoslynNavigator
```

### 4단계: 사용자 승인

미설치 도구가 1개 이상이면:

```
2개 도구를 설치하시겠습니까?
(a) 전부 설치
(b) 골라서 설치 (도구별 y/n)
(c) 취소
```

승인된 도구만 설치 실행. **사용자 승인 없이는 절대 설치하지 않는다.**

### 5단계: 설치 실행

각 도구를 순서대로 설치:

```bash
npm install -g context-mode
dotnet tool install -g CWM.RoslynNavigator
```

각 설치 결과를 출력. 실패 시 에러 메시지 + 수동 설치 가이드.

### 6단계: 사후 안내

uloop-cli 설치된 경우 추가 안내:

```
ℹ️ uloop-cli는 Unity 에디터에서도 패키지 설치가 필요합니다:

Packages/manifest.json에 추가:
  "io.github.hatayama.uloopmcp": "https://github.com/hatayama/unity-cli-loop.git?path=/Packages/src"
```

CWM.RoslynNavigator 설치된 경우:

```
ℹ️ MCP 서버 등록은 ~/.claude/settings.json에 추가:

"mcpServers": {
  "cwm-roslyn-navigator": {
    "command": "CWM.RoslynNavigator",
    "args": []
  }
}

(이미 등록돼 있으면 무시)
```

context-mode 설치된 경우:

```
ℹ️ context-mode는 standalone MCP 모드로 작동합니다.
   ~/.claude/settings.json의 mcpServers 또는 enabledPlugins에 등록 (선택).

자세한 설정: https://github.com/mksglu/context-mode
```

## 인자 (옵션)

| 인자 | 동작 |
|------|------|
| 없음 | 전체 도구 체크 + 미설치 시 승인 받고 설치 |
| `--check-only` | 체크만, 설치 안 함 (CI용) |
| `--all` | 모든 미설치를 한 번에 설치 (대화 없이) |

## 엣지 케이스

| 케이스 | 처리 |
|--------|------|
| Node.js / .NET SDK 미설치 | 전제조건 단계에서 안내 후 중단 |
| 권한 부족 (`EACCES` 등) | 권한 에러 안내 + `sudo` 또는 `--prefix=$HOME/.npm-global` 안내 |
| 네트워크 오프라인 | npm/dotnet 설치 실패 → 오프라인 안내 |
| 이미 모두 설치됨 | "✓ 모든 도구 설치 완료. 추가 작업 없음." |
| `--check-only` + 미설치 있음 | exit code 1로 실패 (CI에서 활용) |

## 도구 목록 갱신 방법

이 커맨드의 도구 목록은 **하드코드** 방식이다. 갱신하려면:

1. `/ft:dev edit setup` 으로 이 파일 편집 모드 진입
2. "필수 도구 목록" 표에서 추가/수정/삭제
3. 같은 항목을 2단계 / 3단계 / 5단계 / 6단계의 안내에도 반영
4. `/ft:dev release` 로 새 버전 배포 (PATCH)

도구가 자주 바뀌지 않으므로 별도 데이터 파일 분리는 안 함 (단순함이 가치).

## 경계

**한다:**
- 필수 도구 3개의 설치 여부 체크
- 전제조건 (Node.js, .NET SDK) 점검
- 미설치 도구의 사용자 승인 후 자동 설치
- 사후 설정 안내 (Unity 패키지, MCP 서버 등록 등)

**안한다:**
- 전제조건 (Node.js, .NET SDK) 자동 설치 — OS별 차이가 커서 위험
- 사용자 승인 없는 설치
- 도구 업그레이드 / 다운그레이드 (`install`만, `update`는 별도 작업)
- MCP 서버 자동 등록 / Unity manifest.json 자동 편집 (안내만)
- 시스템 환경변수 / PATH 수정
