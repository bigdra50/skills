#!/usr/bin/env bash
# ============================================================
# html-reports / new-report.sh
# 新規レポートをスケルトン生成し、_index.js にエントリ追加する
# Usage: new-report.sh <type> <slug> [title]
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<EOF
Usage: $0 <type> <slug> [title]

  type   : review | plan | audit | adr-analysis
  slug   : kebab-case 推奨 (例: shallow-class-issue68)
  title  : 省略可 (デフォルトは slug をそのまま使用)

例:
  $0 review shallow-class-issue68 "Issue#68 浅いクラスレビュー"
  $0 plan title-provider-refactor
EOF
  exit 1
}

[ "$#" -ge 2 ] || usage

TYPE="$1"
SLUG="$2"
TITLE="${3:-$SLUG}"

# Validate type
case "$TYPE" in
  review|plan|audit|adr-analysis) ;;
  *)
    echo "Error: type は review | plan | audit | adr-analysis のいずれか (got: $TYPE)" >&2
    exit 1
    ;;
esac

# Plural directory mapping
case "$TYPE" in
  review)       SUBDIR="reviews" ;;
  plan)         SUBDIR="plans" ;;
  audit)        SUBDIR="audits" ;;
  adr-analysis) SUBDIR="adr-analysis" ;;
esac

# Locate .claude/reports/ relative to current working directory
PROJECT_ROOT="$(pwd)"
REPORTS_DIR="$PROJECT_ROOT/.claude/reports"

if [ ! -d "$REPORTS_DIR" ]; then
  echo "Error: $REPORTS_DIR が見つかりません" >&2
  echo "  先に $SKILL_DIR/scripts/init.sh を実行してください" >&2
  exit 1
fi

DATE="$(date +%Y-%m-%d)"
OUTPUT_REL="$SUBDIR/$DATE-$SLUG.html"
OUTPUT="$REPORTS_DIR/$OUTPUT_REL"

if [ -e "$OUTPUT" ]; then
  echo "Error: 既に存在します: $OUTPUT" >&2
  exit 1
fi

# Copy template
TEMPLATE="$SKILL_DIR/templates/$TYPE.html"
[ -f "$TEMPLATE" ] || { echo "Error: テンプレートなし: $TEMPLATE" >&2; exit 1; }

mkdir -p "$REPORTS_DIR/$SUBDIR"
cp "$TEMPLATE" "$OUTPUT"

# Replace placeholders (sed in-place, BSD/GNU compatible)
sed_inplace() {
  if sed --version >/dev/null 2>&1; then sed -i "$@"; else sed -i '' "$@"; fi
}

# 1. <title>
sed_inplace "s|<title>\[Template\][^<]*</title>|<title>$TITLE</title>|" "$OUTPUT"

# 2. <meta name="report:date">
sed_inplace "s|<meta name=\"report:date\" content=\"[^\"]*\">|<meta name=\"report:date\" content=\"$DATE\">|" "$OUTPUT"

# 3. <meta name="report:tags"> — keep "template" out
sed_inplace "s|<meta name=\"report:tags\" content=\"template,|<meta name=\"report:tags\" content=\"|" "$OUTPUT"

# 4. ヘッダーのタイトル h1 (テンプレ固有テキストを置換)
sed_inplace "s|<h1>.*テンプレート</h1>|<h1>$TITLE</h1>|" "$OUTPUT"

# Update _index.js: prepend new entry into REPORTS_INDEX array
INDEX_JS="$REPORTS_DIR/_index.js"
if [ -f "$INDEX_JS" ]; then
  # Generate the JS snippet for the new entry
  ENTRY_ID="$DATE-$SLUG"
  # Escape backslashes and quotes in title for JS string
  TITLE_JS="$(printf '%s' "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')"

  TMP="$(mktemp)"
  awk -v entry_id="$ENTRY_ID" \
      -v title="$TITLE_JS" \
      -v type="$TYPE" \
      -v date="$DATE" \
      -v path="$OUTPUT_REL" '
    /window\.REPORTS_INDEX = \[/ {
      print
      print "  {"
      print "    id: \"" entry_id "\","
      print "    title: \"" title "\","
      print "    type: \"" type "\","
      print "    date: \"" date "\","
      print "    path: \"" path "\","
      print "    tags: [],"
      print "    summary: \"\","
      print "    status: \"draft\","
      print "    author: \"\","
      print "  },"
      next
    }
    { print }
  ' "$INDEX_JS" > "$TMP" && mv "$TMP" "$INDEX_JS"
fi

# Output
c_ok()  { printf "\033[32m%s\033[0m" "$1"; }
c_dim() { printf "\033[2m%s\033[0m" "$1"; }

echo "$(c_ok "[created]") $OUTPUT"
echo
echo "次のステップ:"
echo "  1. レポートを編集: $(c_dim "$OUTPUT")"
echo "  2. _index.js のエントリ (tags / summary / status) を補完"
echo "  3. 完成後 status を \"draft\" → \"done\" に変更"
echo "  4. ブラウザで確認: $(c_dim "open $REPORTS_DIR/index.html")"

# Print just the path on the last line for easy capture
echo
echo "$OUTPUT"
