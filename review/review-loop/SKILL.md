---
name: review-loop
description: |
  実装コードを外部AIレビューで反復改善するループ。/multi-review実行→FB分類→コード修正→再レビューを収束まで繰り返す。
  --tool codex|copilot でレビューツールを選択。Copilot時は --models, --effort も使用可能。
  Use for: "review-loop", "コード精度上げて", "レビューループ", "反復コードレビュー"
user-invocable: true
---

# Code Review Loop

実装済みコードに `/multi-review` を実行し、指摘を反映して再レビューする反復ループ。
`--tool` で Codex / Copilot を切り替え可能（デフォルト: codex）。

## When NOT to use

- 単発レビューで十分なとき → `/multi-review` (loop なし)
- 設計プランのレビュー対象 → `/plan-loop` or `/copilot-plan-loop`
- メトリクス駆動の構造改善 → `/refactor-loop`
- まだコードを書いていない → 通常会話で実装してから

## Parameters

| Param | Values | Default | Description |
|---|---|---|---|
| `--tool` | `codex` / `copilot` | `codex` | レビューに使う外部ツール |
| `--models` | モデル指定 | (copilot default mapping) | Copilot 時のみ有効。観点別モデル指定 |
| `--effort` | `low` / `medium` / `high` | (copilot default) | Copilot 時のみ有効。推論レベル |
| `--staged` | flag | — | git staged の変更を対象 |

`--models` と `--effort` は `--tool copilot` 時のみ有効。Codex 使用時に渡すと無視される。

## Pitfalls (read first)

| Symptom | Cause | Fix |
|---|---|---|
| 同じ指摘が毎ラウンド出る | 修正履歴が次ラウンドの reviewer に渡っていない | 各ラウンドの修正内容を要約し、次の `/multi-review` 引数に含める |
| 修正がテストを壊す | Step 4 のテスト実行をスキップしている | プロジェクトの test command を CLAUDE.md から特定し必ず実行 |
| `--staged` で対象が空 | git add していない / staging が古い | `git status` で確認、必要なら `git add` を促す |
| MUST が永遠にゼロにならない | 修正対象の判断ミスで別ファイルを直している | reviewer が指摘した `file:line` を厳格に追う |
| ラウンドが 1 回で収束する | reviewer が浅いレビューしかしていない | `/multi-review` の 4 観点 prompt が省略されていないか確認 |
| `--models all-gpt` で 1 モデルしか動かない (copilot) | argparse で models 配列が agent に伝わっていない | Step 2 で `--models` をそのまま渡しているか確認 |
| 観点ごとに別モデルを指定したい (copilot) | デフォルト mapping が固定 | `--models security=gpt-5,perf=claude-opus-4.6` のように観点指定 |
| `--effort high` でレートリミット (copilot) | 4 観点 x 高 effort はコスト大 | observability 不足箇所だけ effort high に絞る |

## Usage

```
/review-loop                                        # Codex で直近の変更を対象にループ開始
/review-loop src/relay/                             # 指定パスを対象
/review-loop --staged                               # git staged の変更を対象
/review-loop --tool copilot src/                    # Copilot で実施
/review-loop --tool copilot --models all-gpt src/   # Copilot 全観点GPT
/review-loop --tool copilot --effort high src/      # Copilot 高推論レベル
```

## Workflow

```python
target = resolve_target(args or recent_changes)
tool = parse_tool_arg(args, default="codex")
models_arg = parse_models_arg(args) if tool == "copilot" else None
effort_arg = parse_effort_arg(args) if tool == "copilot" else None
round = 0
history = []

while True:
    round += 1
    review = multi_review(target, tool, models_arg, effort_arg)  # /multi-review --tool <tool>
    must, should, nice = classify(review)
    report_to_user(round, must, should, nice)

    if not must and not should:
        break
    if user_wants_to_stop():
        break

    approved = ask_user_which_to_address(must + should)
    apply_fixes(target, approved)            # コードを修正
    run_tests_if_available()                 # テスト実行で壊れていないか確認
    history.append((review, approved))

print_summary(history)
```

## Step 1: 対象特定

レビュー対象を決定する:

- 引数にパスがあればそのパス
- `--staged` なら `git diff --staged` の変更ファイル
- なければ会話コンテキストから直近の変更ファイルを特定
- それでもなければユーザーに確認

## Step 2: /multi-review 実行

Skill tool で `/multi-review --tool <tool>` を実行する。対象パスを引数として渡す。

- `--tool codex`: 4観点（セキュリティ、パフォーマンス、保守性、設計）の並列レビュー結果が返る。
- `--tool copilot`: `--models`, `--effort` も合わせて渡す。マルチモデル並列レビュー結果が返る。

## Step 3: FB 分類

レビュー結果の各指摘を重大度で再分類:

- [MUST] バグ、セキュリティ脆弱性、データ損失リスク
- [SHOULD] パフォーマンス改善、設計改善、可読性向上
- [NICE] スタイル、命名の好み、ドキュメント追加

```
Round N レビュー結果:
  MUST:   X件 — {一覧}
  SHOULD: X件 — {一覧}
  NICE:   X件 — {一覧}
```

ユーザーに報告し、対応方針を確認する。

## Step 4: コード修正

ユーザーの承認を得た MUST + SHOULD 項目に対してコードを修正する。

修正後、テストがあれば実行して既存の動作を壊していないか確認する。
テスト実行コマンドはプロジェクトの CLAUDE.md や設定から判断する。

## Step 5: 収束判定

以下のいずれかで終了:
- MUST と SHOULD が両方 0 件
- ユーザーが終了を指示

ラウンド数の上限は設けない。収束するまで繰り返す。

終了時、全ラウンドのサマリーを報告:

```
## Code Review Summary

| Round | Tool | MUST | SHOULD | NICE | 修正ファイル数 |
|-------|------|------|--------|------|----------------|
| 1     | codex | 2   | 4      | 3    | 5              |
| 2     | codex | 1   | 2      | 1    | 3              |
| 3     | codex | 0   | 0      | 1    | 0              |

対応済み: X件 / 未対応 (NICE): X件
```

## Anti-patterns

| 合理化 | 実像 |
|---|---|
| 「テスト失敗したけどレビュー結果は反映済みだから次へ」 | 修正で別の不具合を導入。テスト緑化前に次ラウンドへ進まない |
| 「NICE は無視してよい (時間ない)」 | NICE が積もると debt 化。ユーザーに判断を委ねる方が良い |
| 「`--staged` ならテスト不要 (commit 前なので)」 | staged の状態で壊れていれば commit してから困る。テストは必ず |
| 「reviewer が同じ指摘繰り返すから収束した」 | 指摘の伝達がうまくいっていないだけ。修正履歴を要約して渡す |
| 「reviewer の出力をそのまま applied=true にしてよい」 | reviewer は提案するだけ。承認はユーザー、適用は別ステップ |
| 「マルチモデルだから観点間で矛盾しない」(copilot) | 観点ごとに別モデルなら矛盾し得る。ユーザー判断で優先順位を決める |
| 「`--models all-gpt` で十分 (Claude 不要)」(copilot) | モデルファミリーで盲点が偏る。混合の方が見落としが減る |

## Related skills

- `/plan-loop` — 設計プランを Codex でループ (code ではなく plan 対象)
- `/copilot-plan-loop` — 設計プランを Copilot でループ
- `/refactor-loop` — メトリクス駆動の構造改善ループ (CodeHealth 系、別系統)
- `/multi-review` — このスキルが委譲する単発レビュー (Codex / Copilot 切替可能)
- `empirical-prompt-tuning` (mizchi) — このスキル自体の品質を bias-free に評価

## Notes

- レビューは `/multi-review` スキルに委譲する。直接 codex exec や copilot -p を呼ばない
- `--tool` 未指定時は codex を使う（後方互換性）
- `--models`, `--effort` は `--tool copilot` 時のみ `/multi-review` に渡す
- 各ラウンドの修正内容を次ラウンドのレビューに反映し、同じ指摘の繰り返しを防ぐ
- コード修正はユーザー承認後に実行する。自動修正はしない
- NICE 項目は対応を強制しない。ユーザー判断に委ねる
