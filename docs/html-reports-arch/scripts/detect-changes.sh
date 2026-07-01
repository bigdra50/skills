#!/usr/bin/env bash
# ============================================================
# html-reports-arch / detect-changes.sh
#
# 既存 architecture (あれば) の commit_hash 以降の変化を検出して
# 構造化サマリを stdout に出力する。
#
# 出力フォーマット (Claude が読む):
#   === Existing Architecture ===
#   id: ...
#   date: ...
#   detail: ...
#   commit_hash: ...   (なければ空)
#
#   === Change Summary ===
#   base_hash: <commit hash | INITIAL | HEAD~50>
#   head_hash: <現在の HEAD>
#   changed_files: <数>
#   commits: <数>
#
#   === Changed Files ===
#   <file path>
#   ...
#
#   === Directory Structure Changes ===
#   [+] new/dir/path
#   [-] removed/dir/path
#
#   === Manifest Changes ===
#   <file>: changed (+N -M)
#
#   === Recent Commit Messages ===
#   <hash> <subject>
#   ...
#
# このスクリプトは何も書き換えない。検出のみ。
# ============================================================
set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
REPORTS_DIR="$PROJECT_ROOT/.claude/reports"
INDEX_JS="$REPORTS_DIR/_index.js"

if [ ! -f "$INDEX_JS" ]; then
  echo "Error: $INDEX_JS not found. html-reports が未初期化です。" >&2
  exit 1
fi

cd "$PROJECT_ROOT"

# ------------------------------------------------------------
# Step 1: 既存 architecture の最新エントリを抽出
# ------------------------------------------------------------
# architecture-overview (常設ページ) の commit_hash を base にする。
# overview がなければ INITIAL シグナル。
# 他の module-* / flow-* ページは overview に追従するので、overview を基点にすれば十分。
extract_overview_arch() {
  awk '
    BEGIN { in_block=0; date=""; hash=""; is_arch=0; id=""; page=""; detail="" }
    /^[[:space:]]*\{[[:space:]]*$/ {
      in_block=1; date=""; hash=""; is_arch=0; id=""; page=""; detail=""
      next
    }
    in_block && /type:[[:space:]]*"architecture"/ { is_arch=1 }
    in_block && /^[[:space:]]*id:[[:space:]]*"/ {
      line=$0; sub(/.*id:[[:space:]]*"/, "", line); sub(/".*/, "", line); id=line
    }
    in_block && /^[[:space:]]*page:[[:space:]]*"/ {
      line=$0; sub(/.*page:[[:space:]]*"/, "", line); sub(/".*/, "", line); page=line
    }
    in_block && /^[[:space:]]*date:[[:space:]]*"/ {
      line=$0; sub(/.*date:[[:space:]]*"/, "", line); sub(/".*/, "", line); date=line
    }
    in_block && /^[[:space:]]*detail:[[:space:]]*"/ {
      line=$0; sub(/.*detail:[[:space:]]*"/, "", line); sub(/".*/, "", line); detail=line
    }
    in_block && /^[[:space:]]*commit_hash:[[:space:]]*"/ {
      line=$0; sub(/.*commit_hash:[[:space:]]*"/, "", line); sub(/".*/, "", line); hash=line
    }
    /^[[:space:]]*\},?[[:space:]]*$/ {
      # overview ページを特定 (id=architecture-overview か page=overview)
      if (is_arch && (id == "architecture-overview" || page == "overview")) {
        ov_id=id; ov_date=date; ov_detail=detail; ov_hash=hash
      }
      in_block=0
    }
    END {
      print ov_id "|" ov_date "|" ov_detail "|" ov_hash
    }
  ' "$INDEX_JS"
}

# 全 architecture ページの一覧を取得 (id, page, commit_hash)
list_all_arch_pages() {
  awk '
    BEGIN { in_block=0 }
    /^[[:space:]]*\{[[:space:]]*$/ { in_block=1; id=""; page=""; hash=""; is_arch=0; next }
    in_block && /type:[[:space:]]*"architecture"/ { is_arch=1 }
    in_block && /^[[:space:]]*id:[[:space:]]*"/ { line=$0; sub(/.*id:[[:space:]]*"/, "", line); sub(/".*/, "", line); id=line }
    in_block && /^[[:space:]]*page:[[:space:]]*"/ { line=$0; sub(/.*page:[[:space:]]*"/, "", line); sub(/".*/, "", line); page=line }
    in_block && /^[[:space:]]*commit_hash:[[:space:]]*"/ { line=$0; sub(/.*commit_hash:[[:space:]]*"/, "", line); sub(/".*/, "", line); hash=line }
    /^[[:space:]]*\},?[[:space:]]*$/ {
      if (is_arch) printf "  - %s (page=%s, commit=%s)\n", id, page, substr(hash, 1, 8)
      in_block=0
    }
  ' "$INDEX_JS"
}

extract_latest_arch() { extract_overview_arch; }

LATEST="$(extract_latest_arch)"
ARCH_ID="$(printf '%s' "$LATEST" | cut -d'|' -f1)"
ARCH_DATE="$(printf '%s' "$LATEST" | cut -d'|' -f2)"
ARCH_DETAIL="$(printf '%s' "$LATEST" | cut -d'|' -f3)"
ARCH_HASH="$(printf '%s' "$LATEST" | cut -d'|' -f4)"

# ------------------------------------------------------------
# Step 2: 出力ヘッダ
# ------------------------------------------------------------
echo "=== Existing Architecture ==="
if [ -n "$ARCH_ID" ]; then
  echo "id: $ARCH_ID"
  echo "date: $ARCH_DATE"
  echo "detail: $ARCH_DETAIL"
  echo "commit_hash: ${ARCH_HASH:-<empty>}"
else
  echo "(none — initial creation)"
fi
echo

# ------------------------------------------------------------
# Step 3: git 利用可能性チェックと base_hash 決定
# ------------------------------------------------------------
HAVE_GIT=0
HEAD_HASH=""
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  HAVE_GIT=1
  HEAD_HASH="$(git rev-parse HEAD 2>/dev/null || true)"
fi

if [ "$HAVE_GIT" -eq 0 ]; then
  echo "=== Change Summary ==="
  echo "git_repo: no (差分検出スキップ)"
  echo
  echo "=== Directory Structure ==="
  find . -maxdepth 3 -type d -not -path '*/\.*' -not -path '*/node_modules*' 2>/dev/null | sort | head -50
  exit 0
fi

# base_hash を決定
BASE_HASH=""
BASE_LABEL=""
if [ -n "$ARCH_HASH" ] && git cat-file -e "$ARCH_HASH^{commit}" 2>/dev/null; then
  BASE_HASH="$ARCH_HASH"
  BASE_LABEL="$ARCH_HASH (from previous architecture)"
elif [ -z "$ARCH_ID" ]; then
  BASE_LABEL="INITIAL (no previous architecture)"
else
  # commit_hash があったが既に消えている、または空 → HEAD~50 をフォールバック
  if FALLBACK="$(git rev-parse HEAD~50 2>/dev/null)"; then
    BASE_HASH="$FALLBACK"
    BASE_LABEL="$FALLBACK (fallback: HEAD~50, previous hash was missing or empty)"
  else
    BASE_LABEL="INITIAL (history shorter than 50 commits)"
  fi
fi

# ------------------------------------------------------------
# Step 4: Change Summary
# ------------------------------------------------------------
echo "=== Change Summary ==="
echo "base_hash: $BASE_LABEL"
echo "head_hash: $HEAD_HASH"
if [ -n "$BASE_HASH" ]; then
  COMMITS="$(git rev-list --count "$BASE_HASH..HEAD" 2>/dev/null || echo "0")"
  CHANGED_FILES="$(git diff --name-only "$BASE_HASH..HEAD" 2>/dev/null | wc -l | tr -d ' ')"
  ADDITIONS="$(git diff --shortstat "$BASE_HASH..HEAD" 2>/dev/null | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")"
  DELETIONS="$(git diff --shortstat "$BASE_HASH..HEAD" 2>/dev/null | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")"
  echo "commits: $COMMITS"
  echo "changed_files: $CHANGED_FILES"
  echo "additions: $ADDITIONS"
  echo "deletions: $DELETIONS"
else
  echo "commits: (initial)"
  echo "changed_files: (initial)"
fi
echo

# ------------------------------------------------------------
# Step 5: Changed Files (最大 100 件)
# ------------------------------------------------------------
if [ -n "$BASE_HASH" ]; then
  echo "=== Changed Files (max 100) ==="
  git diff --name-only "$BASE_HASH..HEAD" 2>/dev/null | head -100
  echo

  # ------------------------------------------------------------
  # Step 6: Directory Structure Changes
  # ------------------------------------------------------------
  echo "=== Directory Structure Changes (tracked dirs only, max-depth 3) ==="
  # BASE と HEAD 両方 git ls-tree から生成 (find ベースだと空ディレクトリの扱いで偽陽性が出る)
  dir_set_from_tree() {
    git ls-tree -r --name-only "$1" 2>/dev/null \
      | awk -F'/' '{ if (NF >= 2) { p=$1; for (i=2; i<=NF-1 && i<=3; i++) p=p"/"$i; print p } }' \
      | sort -u
  }
  CURRENT_DIRS="$(mktemp)"; BASE_DIRS="$(mktemp)"
  dir_set_from_tree "HEAD"       > "$CURRENT_DIRS"
  dir_set_from_tree "$BASE_HASH" > "$BASE_DIRS"
  # diff は差分あれば exit 1、grep もマッチなしで exit 1 になるので `|| true` で吸収
  changes="$( { diff "$BASE_DIRS" "$CURRENT_DIRS" || true; } | { grep -E '^[<>]' || true; } | sed -e 's/^> /[+] /' -e 's/^< /[-] /')"
  if [ -z "$changes" ]; then
    echo "(no tracked directory added/removed)"
  else
    printf '%s\n' "$changes" | head -30
  fi
  rm -f "$CURRENT_DIRS" "$BASE_DIRS"
  echo

  # ------------------------------------------------------------
  # Step 7: Manifest Changes (パッケージマネージャ系)
  # ------------------------------------------------------------
  echo "=== Manifest Changes ==="
  MANIFESTS="package.json|package-lock.json|yarn.lock|pnpm-lock.yaml|Cargo.toml|Cargo.lock|go.mod|go.sum|requirements.txt|Pipfile|Pipfile.lock|pyproject.toml|poetry.lock|Gemfile|Gemfile.lock|composer.json|composer.lock|pubspec.yaml|pubspec.lock|build.gradle|build.gradle.kts|pom.xml|.+\\.csproj|.+\\.sln|mise.toml|.tool-versions"
  git diff --name-only "$BASE_HASH..HEAD" 2>/dev/null \
    | grep -E "(^|/)($MANIFESTS)\$" | while read -r f; do
      stats="$(git diff --shortstat "$BASE_HASH..HEAD" -- "$f" 2>/dev/null | sed 's/^ *//')"
      echo "$f: $stats"
    done | head -20
  echo

  # ------------------------------------------------------------
  # Step 8: Recent Commit Messages
  # ------------------------------------------------------------
  echo "=== Recent Commit Messages (max 30) ==="
  git log --oneline "$BASE_HASH..HEAD" 2>/dev/null | head -30
  echo
fi

# ------------------------------------------------------------
# Step 9: 規模判定ヒント
# ------------------------------------------------------------
echo "=== Scale Hint ==="
if [ -z "$ARCH_ID" ]; then
  echo "verdict: INITIAL (新規 architecture 作成を推奨)"
elif [ -z "$BASE_HASH" ]; then
  echo "verdict: UNKNOWN (base_hash 不明、人間が判断)"
else
  CF="${CHANGED_FILES:-0}"
  if [ "$CF" -eq 0 ]; then
    echo "verdict: NO_CHANGE (commit_hash と updated を進めるだけで OK)"
  elif [ "$CF" -lt 10 ]; then
    echo "verdict: MINOR ($CF files changed; updated フィールドのみ更新を推奨)"
  elif [ "$CF" -lt 50 ]; then
    echo "verdict: MODERATE ($CF files changed; 部分更新を推奨 — モジュール表と L1 図のみ)"
  else
    echo "verdict: MAJOR ($CF files changed; 新規 architecture + supersedes を推奨)"
  fi
fi
