#!/usr/bin/env bash
# ============================================================
# html-reports / init.sh
# プロジェクトに .claude/reports/ を bootstrap する
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="${1:-$(pwd)}"
REPORTS_DIR="$PROJECT_ROOT/.claude/reports"

# Color output
c_dim()   { printf "\033[2m%s\033[0m" "$1"; }
c_ok()    { printf "\033[32m%s\033[0m" "$1"; }
c_warn()  { printf "\033[33m%s\033[0m" "$1"; }
c_err()   { printf "\033[31m%s\033[0m" "$1"; }

echo "html-reports init"
echo "  skill   : $(c_dim "$SKILL_DIR")"
echo "  project : $(c_dim "$PROJECT_ROOT")"
echo "  output  : $(c_dim "$REPORTS_DIR")"
echo

# Idempotency check
if [ -f "$REPORTS_DIR/index.html" ]; then
  echo "$(c_warn "[skip]") $REPORTS_DIR/index.html already exists."
  echo "  既存をそのまま使うなら何もしません。"
  echo "  アセット更新が目的なら $SKILL_DIR/scripts/update-assets.sh を実行してください。"
  exit 0
fi

# Create directory tree
mkdir -p "$REPORTS_DIR"/{_assets,reviews,plans,audits,adr-analysis}
echo "$(c_ok "[mkdir]") $REPORTS_DIR/{_assets,reviews,plans,audits,adr-analysis}"

# Copy assets
cp "$SKILL_DIR/assets/theme.css"      "$REPORTS_DIR/_assets/theme.css"
cp "$SKILL_DIR/assets/components.css" "$REPORTS_DIR/_assets/components.css"
cp "$SKILL_DIR/assets/reports.js"     "$REPORTS_DIR/_assets/reports.js"
echo "$(c_ok "[copy]") _assets/{theme.css, components.css, reports.js}"

# Copy boilerplate
cp "$SKILL_DIR/boilerplate/index.html" "$REPORTS_DIR/index.html"
cp "$SKILL_DIR/boilerplate/_index.js"  "$REPORTS_DIR/_index.js"
cp "$SKILL_DIR/boilerplate/README.md"  "$REPORTS_DIR/README.md"
echo "$(c_ok "[copy]") index.html, _index.js, README.md"

# .gitignore hint
GITIGNORE="$PROJECT_ROOT/.gitignore"
if [ -f "$GITIGNORE" ] && ! grep -q "^\.claude/reports/" "$GITIGNORE" 2>/dev/null; then
  echo
  echo "$(c_warn "[hint]") .gitignore に以下を追記すると、生データ (sarif/json/txt) を除外できます:"
  cat <<'EOF'

  # .claude/reports/ : HTML レポートは tracked、生データは ignore
  .claude/reports/*.sarif
  .claude/reports/*.json
  .claude/reports/aed-bounds.txt
EOF
fi

echo
echo "$(c_ok "[done]") .claude/reports/ を初期化しました"
echo
echo "次のステップ:"

# mise.toml に report:* task があるか
if [ -f "$PROJECT_ROOT/mise.toml" ] && command -v mise >/dev/null 2>&1 && \
   mise tasks --no-header 2>/dev/null | grep -q "^report:new"; then
  echo "  - $(c_dim "mise run report:open") で一覧を確認"
  echo "  - $(c_dim "mise run report:new -- <type> <slug> [title]") で新規レポート作成"
  echo "    type: review | plan | audit | adr-analysis"
else
  echo "  - $(c_dim "open $REPORTS_DIR/index.html") で一覧を確認"
  echo "  - $(c_dim "$SKILL_DIR/scripts/new-report.sh <type> <slug>") で新規レポート作成"
  echo "    type: review | plan | audit | adr-analysis"
  echo
  echo "  $(c_dim "(ヒント) mise.toml に以下を追加すると \`mise run report:*\` で叩けるようになります:")"
  cat <<'EOF'

  [tasks."report:init"]
  description = "Initialize .claude/reports/"
  run = ".claude/skills/html-reports/scripts/init.sh"

  [tasks."report:new"]
  description = "Create new report. Usage: mise run report:new -- <type> <slug> [title]"
  run = ".claude/skills/html-reports/scripts/new-report.sh"

  [tasks."report:open"]
  description = "Open .claude/reports/index.html"
  run = "open .claude/reports/index.html"

  [tasks."report:update-assets"]
  description = "Sync html-reports assets"
  run = ".claude/skills/html-reports/scripts/update-assets.sh"
EOF
fi
