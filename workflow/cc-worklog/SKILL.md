---
name: worklog
description: 今日のClaude Codeセッションログからマークダウン形式の作業記録を自動生成する
model: sonnet
---

# cc-worklog

Claude Codeのセッションログとgit logから、検索可能なMarkdown形式の日次作業記録を生成する。

## トリガー

- `/worklog` で今日の作業記録を生成
- `/worklog 2026-04-08` で指定日の作業記録を生成
- `/worklog 2026-04-08 upfrontier` で指定日 + プロジェクトフィルタ
- `/worklog --flipbook` でFlipBook HTML形式で生成
- 「日報作って」「今日の作業まとめて」「振り返り本作って」等

## 処理フロー

### Step 1: 出力先の決定

以下の優先順位で出力ディレクトリを決定する:

```bash
# 優先順位
WORKLOG_DIR="${CC_WORKLOG_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/cc-worklog}"
```

日付に応じたディレクトリを作成:

```bash
mkdir -p "$WORKLOG_DIR/reports/YYYY/MM"
```

### Step 2: セッションデータの収集

collect.sh を実行してセッションログとgit logを収集する:

```bash
bash ~/.claude/skills/cc-worklog/collect.sh [YYYY-MM-DD] [FILTER_PATTERN]
```

- 第1引数: 日付（省略で今日）
- 第2引数: プロジェクトパスのフィルタパターン（grepパターン）
- 環境変数 `CC_WORKLOG_FILTER` でデフォルトフィルタを設定可能（第2引数が優先）
- 出力先: `$TMPDIR/cc-worklog-YYYY-MM-DD.txt`
- `NO_SESSIONS` が返されたら「セッションが見つかりません」と伝えて終了

フィルタ例:
- `upfrontier` → `github.com/upfrontier/` 配下のプロジェクトのみ
- `bigdra50` → `github.com/bigdra50/` 配下のプロジェクトのみ
- 未指定 → 全プロジェクト

### Step 3: 収集データの分析

`$TMPDIR/cc-worklog-YYYY-MM-DD.txt` をReadツールで読み取る。

ファイルは以下の構造:

```
=== PROJECT: org/repo ===
PATH: /full/path
SESSIONS: N
DURATION: HH:MM - HH:MM (UTC)

--- USER MESSAGES ---
[HH:MM] ユーザーの依頼内容...

--- TOOL ACTIVITY ---
Edit: path/to/file (Nx)
Bash[git]: git commit -m "..."

--- ASSISTANT SUMMARY ---
[HH:MM] Claudeの応答要約...

--- GIT LOG ---
hash commit message
===
```

分析のポイント:

- USER MESSAGESから「何をしようとしたか（意図）」を読み取る
- TOOL ACTIVITYから「何を変更したか（事実）」を把握する
- ASSISTANT SUMMARYから「どう判断したか」を補完する
- GIT LOGから「何が完了したか（成果）」を確認する
- DURATIONのタイムスタンプはUTC。日本時間（JST = UTC+9）に変換して記載する

### Step 4: Markdown日報の生成

以下のフォーマットで日報を生成する:

```markdown
# YYYY-MM-DD (曜日)

## やったこと
- [プロジェクト名] 作業内容の要約
  - 具体的な変更点や判断
  - 関連ファイル: path/to/file.ts
- [プロジェクト名] 別の作業...

## 成果
- 完了したもの、マージ・プッシュしたもの
- git commitメッセージがあればそれを活用

## 課題・気づき
- ハマったこと、未解決の問題、学び
- エラーや再試行が多かった箇所

## 明日やること（推定）
- セッション内容から推測できる次のアクション
- 未完了のタスクや言及されたTODO
```

### Step 5: ファイルの書き出し

生成した日報を以下のパスに書き出す:

```bash
$WORKLOG_DIR/reports/YYYY/MM/DD.md
```

書き出し後、ファイルパスをユーザーに表示する。

## 生成ルール

- 日本語で書く
- APIキー、パスワード、トークン等の機密情報は絶対に含めない
- 個人名・ユーザー名（GitHubアカウント名、Slackメンション等）は日報に含めない
- 意図（why）を重視し、ツール呼び出しの羅列は避ける
- 同じファイルへの複数回の編集は最終的な結果でまとめる
- git commitメッセージがあればそれを成果の記述に活用する
- プロジェクト名は `[org/repo]` の形式で記載（検索用）
- 関連ファイルパスを残す（後で「あのとき何触ったか」を追える）
- 分量の目安: 50-150行のMarkdown
- セッション数が多い場合は重要度で傾斜配分し、全プロジェクトに言及する

## 出力例

```markdown
# 2026-04-09 (水)

## やったこと
- [org/some-tool] Windows対応のサーバー修正
  - シグナルハンドリングをWin32 API対応に変更
  - テスト追加: logging, signal_handler
  - 関連ファイル: server.py, tests/test_logging.py
- [org/worklog] 日報自動生成スキルの設計・実装
  - 既存ツールのアーキテクチャを分析し、Markdown出力版を設計
  - collect.sh, SKILL.md を作成

## 成果
- some-tool: PR "feat: Windows signal handling" をマージ
- worklog: v0.1のスキル定義完了

## 課題・気づき
- JONSLのタイムスタンプがUTCのため、日付境界の処理に注意が必要
- セッション数が10を超えるとcollect.shの出力が大きくなる

## 明日やること（推定）
- worklog の動作検証と README 整備
- some-tool のCI修正
```

## FlipBook モード (`--flipbook`)

`--flipbook` を付けると、Markdown 日報の代わりにページめくり可能な HTML 本を生成する。

出力先: `/tmp/claude/daily-flipbook/YYYY-MM-DD.html`

### 構成ルール

| ページ | 内容 |
|--------|------|
| 表紙 | 日付 + タイトル（「YYYY年MM月DD日の記録」） |
| はじめに | 今日のサマリー（セッション数、主な成果） |
| 各章 | セッションごとの詳細（やったこと、コード、学び） |
| 最終ページ | 今日の振り返り + 明日へのアクション |

- 1セッションにつき1見開き（2ページ）
- 最大6章（12ページ）まで。それ以上は重要度で選別

### 使用可能なCSSクラス

`.page-title`, `.chapter-label`, `.page-body`, `.code-block`（`.comment`, `.keyword`, `.string`, `.property`）, `.quote`, `.tip-box`（`.tip-title` + `<ul>`）, `.comparison`（`.col.good` / `.col.bad`）, `.divider`, `.dropcap`

### 生成後

```bash
open /tmp/claude/daily-flipbook/YYYY-MM-DD.html
```

## 注意事項

- セッションログが見つからない場合は「セッションが見つかりません」と伝える
- collect.sh が存在しない場合はインストール手順を案内する
- 既に同日の日報が存在する場合は上書きしてよいか確認する
