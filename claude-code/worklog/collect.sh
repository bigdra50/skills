#!/bin/bash
set -eu

# cc-worklog: Claude Code セッションログ収集スクリプト
# Usage: collect.sh [YYYY-MM-DD] [FILTER_PATTERN]
# bash 3.2+ 互換（macOSデフォルト対応）
# NOTE: pipefail は使わない（jq | head でSIGPIPEが発生するため）

# --- 依存チェック ---
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq が必要です。brew install jq でインストールしてください。" >&2
  exit 1
fi

# --- 日付・フィルタ処理 ---
DATE="${1:-$(date +%Y-%m-%d)}"
FILTER="${2:-${CC_WORKLOG_FILTER:-}}"
YEAR=$(echo "$DATE" | cut -d'-' -f1)
MONTH=$(echo "$DATE" | cut -d'-' -f2)
DAY=$(echo "$DATE" | cut -d'-' -f3)

# 翌日の計算（git log --until用）
if date -v+1d "+%Y" &>/dev/null 2>&1; then
  NEXT_DATE=$(date -j -f "%Y-%m-%d" "$DATE" -v+1d +%Y-%m-%d)
else
  NEXT_DATE=$(date -d "$DATE + 1 day" +%Y-%m-%d)
fi

# --- パス設定 ---
TMPDIR="${TMPDIR:-/tmp}"
OUTPUT_FILE="${TMPDIR}/cc-worklog-${DATE}.txt"
MARKER_FILE="${TMPDIR}/cc_worklog_marker_${DATE}"
WORK_DIR="${TMPDIR}/cc-worklog-work-$$"
mkdir -p "$WORK_DIR"
trap 'rm -rf "$WORK_DIR" "$MARKER_FILE"' EXIT

# 日付マーカー作成（find -newer 用）
touch -t "${YEAR}${MONTH}${DAY}0000" "$MARKER_FILE" 2>/dev/null || true

# --- セッションログ検索 ---
SEARCH_PATHS=(
  "$HOME/.claude/projects"
  "$HOME/claude-data/projects"
)

SESSION_FILES=()
for search_path in "${SEARCH_PATHS[@]}"; do
  if [ -d "$search_path" ]; then
    while IFS= read -r file; do
      SESSION_FILES+=("$file")
    done < <(find "$search_path" -name "*.jsonl" -newer "$MARKER_FILE" -not -path "*/subagents/*" 2>/dev/null || true)
  fi
done

if [ ${#SESSION_FILES[@]} -eq 0 ]; then
  echo "NO_SESSIONS"
  exit 0
fi

# --- Phase 1: 各セッションのプロジェクトパスを特定 ---
SESSION_MAP="${WORK_DIR}/session_map.txt"
: > "$SESSION_MAP"

for logfile in "${SESSION_FILES[@]}"; do
  cwd=$(jq -r 'select(.type == "user" and .cwd != null) | .cwd' "$logfile" 2>/dev/null | head -1)
  if [ -z "$cwd" ] || [ "$cwd" = "null" ]; then
    cwd="unknown"
  fi

  project_path="$cwd"
  if [ "$cwd" != "unknown" ] && [ -d "$cwd" ]; then
    git_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "")
    if [ -n "$git_root" ]; then
      project_path="$git_root"
    fi
  fi

  # フィルタが指定されている場合、パスにマッチしないセッションをスキップ
  if [ -n "$FILTER" ] && ! echo "$project_path" | grep -q "$FILTER"; then
    continue
  fi

  printf '%s\t%s\n' "$project_path" "$logfile" >> "$SESSION_MAP"
done

# フィルタ後にセッションが0件かチェック
if [ ! -s "$SESSION_MAP" ]; then
  echo "NO_SESSIONS"
  exit 0
fi

# --- Phase 2: プロジェクト単位で出力 ---
: > "$OUTPUT_FILE"

# ユニークなプロジェクトパスを取得
cut -f1 "$SESSION_MAP" | sort -u | while IFS= read -r project_path; do
  # プロジェクト名を導出
  if echo "$project_path" | grep -q "github.com"; then
    project_name=$(echo "$project_path" | sed 's|.*/github\.com/||' | cut -d'/' -f1-2)
  else
    project_name=$(basename "$project_path")
  fi

  # このプロジェクトのセッションファイルを取得
  session_files_list="${WORK_DIR}/current_sessions.txt"
  grep "^${project_path}	" "$SESSION_MAP" | cut -f2 > "$session_files_list"
  session_count=$(wc -l < "$session_files_list" | tr -d ' ')

  # セッションの時間範囲を取得
  first_ts=""
  last_ts=""
  while IFS= read -r logfile; do
    ts=$(jq -r 'select(.timestamp != null) | .timestamp' "$logfile" 2>/dev/null | head -1)
    if [ -n "$ts" ] && [ "$ts" != "null" ]; then
      if [ -z "$first_ts" ] || [ "$ts" \< "$first_ts" ]; then
        first_ts="$ts"
      fi
    fi
    ts_last=$(jq -r 'select(.timestamp != null) | .timestamp' "$logfile" 2>/dev/null | tail -1)
    if [ -n "$ts_last" ] && [ "$ts_last" != "null" ]; then
      if [ -z "$last_ts" ] || [ "$ts_last" \> "$last_ts" ]; then
        last_ts="$ts_last"
      fi
    fi
  done < "$session_files_list"

  first_time=$(echo "$first_ts" | sed 's/.*T\([0-9]*:[0-9]*\).*/\1/' 2>/dev/null || echo "??:??")
  last_time=$(echo "$last_ts" | sed 's/.*T\([0-9]*:[0-9]*\).*/\1/' 2>/dev/null || echo "??:??")

  {
    echo "=== PROJECT: ${project_name} ==="
    echo "PATH: ${project_path}"
    echo "SESSIONS: ${session_count}"
    echo "DURATION: ${first_time} - ${last_time} (UTC)"
    echo ""
  } >> "$OUTPUT_FILE"

  # --- ユーザーメッセージ抽出 ---
  echo "--- USER MESSAGES ---" >> "$OUTPUT_FILE"

  while IFS= read -r logfile; do
    jq -r '
      select(.type == "user") |
      {
        ts: (.timestamp // "" | split("T") | if length > 1 then .[1][0:5] else "??:??" end),
        msg: (
          if (.message.content | type) == "array" then
            [.message.content[] | select(.type == "text") | .text] | join(" ")
          elif (.message.content | type) == "string" then
            .message.content
          elif (.message | type) == "string" then
            .message
          else
            ""
          end
        )
      } |
      select(.msg != "" and (.msg | startswith("<") | not)) |
      "[\(.ts)] \(.msg[0:500])"
    ' "$logfile" 2>/dev/null | head -50
  done < "$session_files_list" >> "$OUTPUT_FILE"

  echo "" >> "$OUTPUT_FILE"

  # --- ツール使用抽出 ---
  echo "--- TOOL ACTIVITY ---" >> "$OUTPUT_FILE"

  # Write/Edit: ファイルパスと回数
  while IFS= read -r logfile; do
    jq -r '
      select(.type == "assistant") |
      .message.content[]? |
      select(.type == "tool_use") |
      select(.name == "Write" or .name == "Edit" or .name == "write" or .name == "edit") |
      "\(.name): \(.input.file_path // "unknown")"
    ' "$logfile" 2>/dev/null
  done < "$session_files_list" | sort | uniq -c | sort -rn | while read -r count name; do
    if [ "$count" -gt 1 ]; then
      echo "${name} (${count}x)"
    else
      echo "${name}"
    fi
  done >> "$OUTPUT_FILE"

  # Bash: git/重要コマンド
  while IFS= read -r logfile; do
    jq -r '
      select(.type == "assistant") |
      .message.content[]? |
      select(.type == "tool_use" and .name == "Bash") |
      .input |
      if (.command // "") | test("git (commit|push|merge|tag|pr|release)") then
        "Bash[git]: \(.command[0:150])"
      elif (.command // "") | test("^(npm|yarn|pnpm|make|cargo|go |dotnet)") then
        "Bash[build]: \(.command[0:150])"
      elif (.description // "") != "" then
        "Bash: \(.description[0:150])"
      else
        empty
      end
    ' "$logfile" 2>/dev/null || true
  done < "$session_files_list" >> "$OUTPUT_FILE"

  # その他ツール: 名前と件数
  while IFS= read -r logfile; do
    jq -r '
      select(.type == "assistant") |
      .message.content[]? |
      select(.type == "tool_use") |
      select(.name != "Write" and .name != "Edit" and .name != "Bash" and
             .name != "write" and .name != "edit") |
      .name
    ' "$logfile" 2>/dev/null
  done < "$session_files_list" | sort | uniq -c | sort -rn | while read -r count name; do
    echo "${name}: ${count} calls"
  done >> "$OUTPUT_FILE"

  echo "" >> "$OUTPUT_FILE"

  # --- アシスタントテキスト抽出（要約用） ---
  echo "--- ASSISTANT SUMMARY ---" >> "$OUTPUT_FILE"

  while IFS= read -r logfile; do
    jq -r '
      select(.type == "assistant") |
      {
        ts: (.timestamp // "" | split("T") | if length > 1 then .[1][0:5] else "??:??" end),
        text: (
          [.message.content[]? | select(.type == "text") | .text[0:300]] | join(" ")
        )
      } |
      select(.text != "") |
      "[\(.ts)] \(.text)"
    ' "$logfile" 2>/dev/null | head -20
  done < "$session_files_list" >> "$OUTPUT_FILE"

  echo "" >> "$OUTPUT_FILE"

  # --- Git Log ---
  if [ "$project_path" != "unknown" ] && [ -d "$project_path" ]; then
    git_dir=$(git -C "$project_path" rev-parse --git-dir 2>/dev/null || echo "")
    if [ -n "$git_dir" ]; then
      commits=$(git -C "$project_path" log \
        --since="${DATE} 00:00:00" \
        --until="${NEXT_DATE} 00:00:00" \
        --oneline --no-merges \
        --format="%h %s" \
        --all 2>/dev/null || echo "")
      if [ -n "$commits" ]; then
        {
          echo "--- GIT LOG ---"
          echo "$commits"
          echo ""
        } >> "$OUTPUT_FILE"
        echo "$commits" | wc -l | tr -d ' ' >> "${WORK_DIR}/commit_counts.txt"
      fi
    fi
  fi

  echo "===" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  echo "$session_count" >> "${WORK_DIR}/session_counts.txt"
done

# --- サマリー行 ---
if [ -f "${WORK_DIR}/session_counts.txt" ]; then
  total_sessions=$(awk '{s+=$1} END {print s}' "${WORK_DIR}/session_counts.txt")
else
  total_sessions=0
fi
if [ -f "${WORK_DIR}/commit_counts.txt" ]; then
  total_commits=$(awk '{s+=$1} END {print s}' "${WORK_DIR}/commit_counts.txt")
else
  total_commits=0
fi
project_count=$(cut -f1 "$SESSION_MAP" | sort -u | wc -l | tr -d ' ')

echo "TOTAL: ${project_count} projects, ${total_sessions} sessions, ${total_commits} commits" >> "$OUTPUT_FILE"

# --- 出力サイズチェック ---
file_size=$(wc -c < "$OUTPUT_FILE" | tr -d ' ')
if [ "$file_size" -gt 102400 ]; then
  echo "WARNING: Output exceeds 100KB (${file_size} bytes)." >&2
fi

echo "$OUTPUT_FILE"
