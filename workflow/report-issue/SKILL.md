---
name: report-issue
description: |
  会話の文脈から GitHub issue (バグ/機能要望/タスク) を作成する。環境情報を自動収集し、既存issueの重複を検索し、作成前に確認する。
  Use for: "issue作って", "issue化して", "バグ報告", "これをissueに", "GitHubに報告", "/report-issue"
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, AskUserQuestion
---

# Report Issue

いま作業しているセッションの文脈から、GitHub issue を作る。
ユーザーが遭遇した問題・要望を、環境情報付きの構造化された issue に変換する。

設計の出自: Claude Code の `/feedback` を解析し、再利用価値のある部分（環境自動収集・本文テンプレ・ラベル規約・consent）を `gh issue create` 経路に移植したもの。

## 絶対ルール

- issue 本文・タイトルのどこにも Claude / AI / エージェント / アシスタントへの言及を入れない。
- `~/.claude/rules/writing-style.md` を適用する（修飾語濫用・定型句・誇張を避ける。1文30語以下、一文一行）。
- `~/.claude/rules/commit.md` の言語ポリシーと自動link回避を適用する（後述）。
- 作成は必ずユーザーの確認後（ステップ5）。勝手に作らない。

## ワークフロー

### 1. リポジトリと言語の判定

```bash
gh repo view --json nameWithOwner,visibility
```

`visibility` で本文・タイトルの言語を決める（`commit.md` 準拠）。

| visibility | 言語 |
| --- | --- |
| PUBLIC | 英語 |
| PRIVATE / INTERNAL | 日本語 |
| 判定不能（gh不可・remote未設定） | 日本語（フォールバック） |

ユーザーが言語を明示したらそれを優先する。
別リポジトリに出したい指示があれば `--repo <owner>/<name>` で送信先を切り替える（既定は現在のリポジトリ）。

### 2. 種別の判定

会話内容から bug / feature / task を判定する。曖昧ならステップ5の確認で選ばせる。

| 種別 | タイトル接頭辞 | 既定ラベル | 本文テンプレ |
| --- | --- | --- | --- |
| bug | `[Bug]` | `bug` | 概要 / 再現手順 / 期待・実際 / 環境 / 関連箇所 / ログ |
| feature | `[Feature]` | `enhancement` | 背景 / 提案 / 代替案 / 関連箇所 |
| task | （なし） | `task` | 目的 / やること / 完了条件 |

ラベルは存在するものだけ付ける（`gh label list` で照合し、無ければ付けない）。

### 3. 環境情報の自動収集

ユーザーに入力させない。以下を実行して埋める（`/feedback` の自動収集に相当）。

```bash
uname -srm                                  # Platform/OS
printf '%s / %s\n' "${TERM_PROGRAM:-unknown}" "${SHELL##*/}"  # Terminal
git rev-parse --abbrev-ref HEAD             # branch
git rev-parse --short HEAD                  # short SHA
git remote get-url origin                   # remote
git status --porcelain                      # 空なら clean、非空なら "has local changes"
git status -sb | head -1                    # upstream/ahead/behind → "not synced" 判定
```

注意:
- remote URL は userinfo（`user:pass@`）・クエリ・fragment を除去してから記載する（秘匿）。
- アプリ/プロジェクトの版数があれば拾う: `package.json` の `version`、`*.csproj`、`mise.toml`、`Cargo.toml` 等。
- git リポジトリでなければ git 行は省略する。

### 4. 本文の生成と重複検索

会話文脈から本文を生成する。bug の本文骨子（`/feedback` テンプレ準拠）:

```
## 概要
<1〜2行>

## 再現手順
1. ...

## 期待する挙動 / 実際の挙動

## 環境
- Platform: <uname>
- Terminal: <term>
- Version: <app version があれば>
- Git: <branch>, <short sha> @ <remote>, <not synced / has local changes があれば>

## 関連箇所
- `path/to/file.ext:123`

## ログ / エラー
（あれば。秘匿対象はマスクする。後述）
```

重複検索（同じバグの再報告を避ける）:

```bash
gh issue list --search "<本文から抽出したキーワード>" --state open --limit 10 \
  --json number,title,url
```

候補があればユーザーに提示し、新規作成か既存へのコメントかを選ばせる。

### 5. 確認（consent）

`AskUserQuestion` で作成前に確認する。最低限:

- タイトル（接頭辞込み）
- ラベル
- 送信先リポジトリ
- 種別（曖昧だった場合）

本文プレビューは応答テキストに出してから確認を取る。

### 6. 作成

確認が取れたら作成する。本文は単一引用符 HEREDOC で渡す（`commit.md` の HEREDOC ルール）。

```bash
gh issue create \
  --title "<title>" \
  --label "<labels>" \
  --body "$(cat <<'EOF'
<本文>
EOF
)"
```

`<<'EOF'` 内では `\`・`$`・バッククォートを一切エスケープしない（過剰エスケープでコードブロックが壊れる）。

### 7. 作成後の検証

`commit.md` の確認手順を必ず実行する。意図しない自動 link / mention / エスケープ残りを潰す。

```bash
N=<作成されたissue番号>
gh issue view "$N" --json body -q .body | rg -n '(^|[^a-zA-Z0-9])#[0-9]+' && echo "AUTO-LINK CANDIDATES"
gh issue view "$N" --json body -q .body | rg -n '(^|[^a-zA-Z0-9])@[a-zA-Z0-9_-]+' && echo "MENTION CANDIDATES"
gh issue view "$N" --json body -q .body | rg -n '\\`|\\\$' && echo "ESCAPED LITERALS REMAINING"
```

検出されたら `gh issue edit "$N" --body ...` で修正する（図の連番は `Diagram N`/`(N)`、`@name` はバッククォート等）。
最後に作成された issue の URL をユーザーに返す。

## ログ秘匿（ログ・エラーを本文に貼る場合）

本文に貼るログ・エラーは、貼る前に機密値をマスクする。`/feedback` の redact パターンに準拠:

- 汎用キー名: `api[_-]?key|secret|token|password|credential|bearer|authorization|cookie|client[_-]secret`
- ベンダ鍵: `sk-ant-` / `AKIA` / `AIza` / `ghp_` / `github_pat_` / `xoxb-` / `sk-...T3BlbkFJ...` / `-----BEGIN ... PRIVATE KEY` 等
- URL の `user:pass@` は除去

該当値は `[REDACTED]` に置換してから貼る。判断に迷う値は貼らない。

## 注意

- 1ファイル・数行の単純な作業はわざわざ issue 化しない。
- 既存の重複 issue があれば新規作成より既存へのコメントを優先する。
- このスキルでは push / commit / PR 作成はしない（issue 作成のみ）。
