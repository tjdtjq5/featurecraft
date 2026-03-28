#!/bin/bash
# FeatureCraft — Feature.md 자동 감지 + 컨텍스트 주입 훅
# UserPromptSubmit 시 실행
#
# 해결하는 문제들:
# 1. 스킬 트리거 충돌 → Feature.md 유무에 따라 plan/build 안내
# 2. 강제력 부족 → Feature.md 핵심 내용을 직접 출력
# 3. 자연어 트리거 → 스킬 명시 안 해도 컨텍스트 자동 주입

# 안전장치: 에러 시 원인 출력 후 정상 종료 (훅 시스템은 깨지지 않되, 디버깅은 가능)
trap 'echo "[FeatureCraft] hook error at line $LINENO: $BASH_COMMAND" >&2; exit 0' ERR
set +e

DIR="$(pwd 2>/dev/null || echo ".")"
MAX_DEPTH=3
DEPTH=0
FEATURE_PATH=""

# Feature.md 검색 (cwd → 상위 3단계)
while [ "$DEPTH" -lt "$MAX_DEPTH" ]; do
  if [ -f "$DIR/Feature.md" ]; then
    FEATURE_PATH="$DIR/Feature.md"
    break
  fi
  PARENT=$(dirname "$DIR")
  if [ "$PARENT" = "$DIR" ]; then
    break
  fi
  DIR="$PARENT"
  DEPTH=$((DEPTH + 1))
done

# Feature.md 없으면 종료 (오버헤드 제로)
if [ -z "$FEATURE_PATH" ]; then
  exit 0
fi

# Feature.md 핵심 내용 추출 + 직접 출력
FEATURE_NAME=$(head -1 "$FEATURE_PATH" | sed 's/^# //')

echo ""
echo "[FeatureCraft] 피처 컨텍스트 감지: $FEATURE_NAME"
echo "  경로: $FEATURE_PATH"

# 상태 추출
STATUS=$(grep -A1 "^## 상태" "$FEATURE_PATH" 2>/dev/null | tail -1 | tr -d '[:space:]')
if [ -n "$STATUS" ]; then
  echo "  상태: $STATUS"
fi

# 의존성 추출 (- 로 시작하는 줄, ## 의존성 섹션)
DEPS=$(sed -n '/^## 의존성/,/^## /p' "$FEATURE_PATH" 2>/dev/null | grep "^- " | head -5)
if [ -n "$DEPS" ]; then
  echo "  의존성:"
  echo "$DEPS" | while read -r line; do
    echo "    $line"
  done
fi

# API 추출 (- 로 시작하는 줄, ## API 섹션)
APIS=$(sed -n '/^## API/,/^## /p' "$FEATURE_PATH" 2>/dev/null | grep "^- " | head -5)
if [ -n "$APIS" ]; then
  echo "  API:"
  echo "$APIS" | while read -r line; do
    echo "    $line"
  done
fi

# 주의사항 추출
CAUTIONS=$(sed -n '/^## 주의사항/,/^## /p' "$FEATURE_PATH" 2>/dev/null | grep "^- " | head -3)
if [ -n "$CAUTIONS" ]; then
  echo "  주의사항:"
  echo "$CAUTIONS" | while read -r line; do
    echo "    $line"
  done
fi

# 스킬 안내 (Feature.md 유무 기반 — 트리거 충돌 해결)
echo ""
echo "  → 이 피처를 수정/확장하려면: /ft:build"
echo "  → 코드 리뷰: /review"
echo "  → 위 API와 주의사항을 반드시 참고하세요."

# .featurecraft/learnings/ 존재 시
PROJ_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$PROJ_ROOT" ] && [ -d "$PROJ_ROOT/.featurecraft/learnings" ]; then
  LEARNING_COUNT=$(find "$PROJ_ROOT/.featurecraft/learnings/" -name "*.md" 2>/dev/null | wc -l)
  if [ "$LEARNING_COUNT" -gt 0 ]; then
    echo "  → 경험 학습: ${LEARNING_COUNT}개 패턴 참고 가능 (.featurecraft/learnings/)"
  fi
fi

exit 0
