---
name: compact-prep
description: |
  Claude Code の /compact 実行前に、現セッションの作業状態を一時 state file へ保存する。
  MANDATORY TRIGGERS: /compact-prep, compact-prep, 圧縮準備, compact 準備, コンパクト準備, 圧縮前状態保存。
  DO NOT TRIGGER: compact 後の復旧、通常の進捗報告、plan 作成、context 使用率の雑談。
argument-hint: "[復旧メモ]"
allowed-tools: Read, Write, TaskList, Bash(~/.claude/scripts/get-session-id.sh:*), Bash(bash ~/.claude/scripts/get-session-id.sh:*), Bash(mkdir:*), Bash(date:*), Bash(pwd)
---

# compact-prep

Claude Code の `/compact` 前に、圧縮サマリーへ残りにくい作業状態を
`${TMPDIR:-/tmp}/claude-compact-state/${SESSION_ID}.md` へ保存する。

## Strict procedure profile

- Strictness: strict-procedure。圧縮前 state file の内容と保存完了報告が成果そのもの。
- Hard gates: session_id が取得できない場合は state file を推測名で作らず、取得不能として停止する。
- Forcing function: 保存先パスを固定し、保存後にファイルを読み返して必須項目の有無を確認する。
- Completion receipt: state file パス、保存した主要項目、未確認項目、次に実行する `/compact` 案内を報告する。

## 手順

1. session_id と保存先パスを取得する。
   - `~/.claude/scripts/get-session-id.sh --state-path` を実行すると保存先のフルパスが得られる。
   - 失敗した場合（exit 1、出力なし）は state file を推測名で作らず、session_id が取得できないため準備未完了と報告して停止する。
2. TaskList、active plan file、worker 体制、編集中ファイルを確認する。
   - active plan がある場合はその plan ファイルを読む。
   - tmux 等で worker を並走させていない場合は「未使用」と記録する。
3. 保存先の親ディレクトリを `mkdir -p` で作成し、state file に以下の見出しをこの順で保存する。
   - `# Compact Prep State`
   - `## Active Plan`
   - `## Current Phase`
   - `## TaskList Summary`
   - `## Session Decisions`
   - `## Constraints and Blockers`
   - `## Worker Topology`
   - `## Editing Files`
   - `## Recovery Notes`
4. 保存後に state file を読み直し、上記見出しがすべて存在することを確認する。
5. active plan file がある場合、`~/.claude/scripts/get-session-id.sh --plan-pointer-path` で得たパスに plan ファイルのフルパス 1 行を Write する。
   - 圧縮復旧 hook (userpromptsubmit-compaction-recovery.sh) がこの pointer を読んで plan の再読込を指示する。
   - active plan がない場合はこのステップを省略する。
6. ユーザーに「準備完了。`/compact` を実行してください。」と伝える。

## 保存内容

- active plan file パスと、現在のフェーズ/ステップ
- in-progress タスク一覧と補足
- session 中の判断、ユーザーの選択、不採用にした案の理由
- 制約、ブロッカー、未完了の検証
- worker 体制。並走 worker がいる場合は pane、role、担当を記録する
- 編集中のファイルと、未保存または未検証の注意点
- 圧縮後の自分への復旧メモ。引数 `[復旧メモ]` が与えられた場合は Recovery Notes へ含める

## Completion receipt

完了時は次を含める。

- state file パス
- 保存した主要項目
- 未確認項目と理由
- `準備完了。/compact を実行してください。`
