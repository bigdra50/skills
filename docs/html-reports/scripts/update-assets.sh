#!/usr/bin/env bash
# ============================================================
# html-reports / update-assets.sh
# プロジェクトの .claude/reports/_assets/ を skill 側の最新で同期
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(pwd)"
REPORTS_DIR="$PROJECT_ROOT/.claude/reports"
ASSETS_DIR="$REPORTS_DIR/_assets"

c_dim()  { printf "\033[2m%s\033[0m" "$1"; }
c_ok()   { printf "\033[32m%s\033[0m" "$1"; }
c_warn() { printf "\033[33m%s\033[0m" "$1"; }
c_err()  { printf "\033[31m%s\033[0m" "$1"; }

if [ ! -d "$ASSETS_DIR" ]; then
  echo "$(c_err "Error:") $ASSETS_DIR が見つかりません" >&2
  echo "  先に $SKILL_DIR/scripts/init.sh を実行してください" >&2
  exit 1
fi

# Show diffs first
FILES=(theme.css components.css reports.js)
HAS_DIFF=0

echo "diff 確認 (skill → project):"
echo
for f in "${FILES[@]}"; do
  src="$SKILL_DIR/assets/$f"
  dst="$ASSETS_DIR/$f"
  if [ ! -f "$dst" ]; then
    echo "$(c_warn "[new]")   $f (project 側に存在しません)"
    HAS_DIFF=1
    continue
  fi
  if ! cmp -s "$src" "$dst"; then
    echo "$(c_warn "[diff]")  $f"
    HAS_DIFF=1
    if command -v delta >/dev/null 2>&1; then
      delta "$dst" "$src" || true
    else
      diff -u "$dst" "$src" | head -20 || true
      echo "$(c_dim "  ... (省略)")"
    fi
    echo
  else
    echo "$(c_ok   "[same]")  $f"
  fi
done

if [ "$HAS_DIFF" -eq 0 ]; then
  echo
  echo "$(c_ok "[done]") 同期不要 (差分なし)"
  exit 0
fi

# Confirm
echo
read -p "上記を $(c_warn "上書き") しますか? [y/N] " yn
case "$yn" in
  y|Y|yes)
    for f in "${FILES[@]}"; do
      cp "$SKILL_DIR/assets/$f" "$ASSETS_DIR/$f"
      echo "$(c_ok "[updated]") $f"
    done
    echo
    echo "$(c_ok "[done]") アセットを同期しました"
    ;;
  *)
    echo "$(c_dim "[cancel]") 中断しました"
    exit 0
    ;;
esac
