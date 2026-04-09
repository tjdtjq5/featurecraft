#!/bin/bash
# ft — SessionStart 컨텍스트 주입 훅
# 역할: FEATURE_INDEX.md와 usage.md rules를 세션 시작 시 한 번에 주입
# 조건: .featurecraft/FEATURE_INDEX.md가 존재할 때만 발동 (ft 미사용 프로젝트엔 영향 없음)

set +e

# 프로젝트 루트 — Claude Code 공식 환경 변수 사용
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
export FEATURE_INDEX="$PROJECT_ROOT/.featurecraft/FEATURE_INDEX.md"
export RULES_FILE="${CLAUDE_PLUGIN_ROOT}/rules/usage.md"

# FEATURE_INDEX 없으면 ft 미사용 프로젝트 → 조용히 종료
if [ ! -f "$FEATURE_INDEX" ]; then
  exit 0
fi

# rules 파일 없으면 종료 (플러그인 손상)
if [ ! -f "$RULES_FILE" ]; then
  exit 0
fi

# 두 파일을 합쳐서 주입 (JSON hookSpecificOutput 형식)
if command -v python3 >/dev/null 2>&1; then
  python3 <<'PYEOF'
import os, json
rules = open(os.environ["RULES_FILE"], encoding="utf-8").read()
index = open(os.environ["FEATURE_INDEX"], encoding="utf-8").read()
combined = f"=== ft Plugin Rules ===\n\n{rules}\n\n=== FEATURE_INDEX ===\n\n{index}"
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": combined
    }
}))
PYEOF
else
  # python3 없으면 plain stdout 폴백 (SessionStart는 stdout도 자동 주입됨)
  echo "=== ft Plugin Rules ==="
  echo ""
  cat "$RULES_FILE"
  echo ""
  echo "=== FEATURE_INDEX ==="
  echo ""
  cat "$FEATURE_INDEX"
fi

exit 0
