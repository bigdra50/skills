---
name: plan-loop
description: |
  設計プランを外部AIレビューで反復改善するループ。プラン作成→レビュー→FB反映→再レビューを収束まで繰り返す。
  --tool codex|copilot でレビューツールを選択。Copilot時は --model, --effort も使用可能。
  Use for: "plan-loop", "プラン精度上げて", "設計レビューループ", "反復レビュー"
user-invocable: true
---

# Plan Review Loop

設計プランを外部 AI agent (Codex or Copilot) にレビュー依頼し、フィードバックを反映して再レビューする反復ループ。
`--tool` でレビューツールを選択する。

## When NOT to use

- 単発レビューで十分なとき → `/codex-review` or `/copilot-review` (loop なし)
- 実装コードのレビュー対象 → `/review-loop` or `/copilot-review-loop`
- プランがまだ存在しない (作成は通常会話で進める)
- レビューを 1 ラウンドだけ回したい → 直接 codex/copilot agent を Task tool で呼ぶ

## Pitfalls (read first)

| Symptom | Cause | Fix |
|---|---|---|
| 同じ指摘が毎ラウンド出る | history が次ラウンド prompt に渡っていない | Step 2 のテンプレで `{previous_feedback_and_responses}` を埋めているか確認 |
| MUST が永遠にゼロにならない | reviewer が plan の最新版を読めていない | `plan_path` を絶対パスで渡す。agent への文脈渡しを見直す |
| 2 ラウンドで打ち切られる | `apply_feedback` が失敗してエラーで break | 例外を握りつぶさず、ユーザーに報告して中断するか継続するか判断を仰ぐ |
| 出力が日本語にならない (codex) | テンプレ末尾の「日本語で回答してください」が省略 | プロンプトテンプレを改変するときも言語指定は必ず残す |
| 出力が日本語にならない (copilot) | model によっては日本語指示が弱い | テンプレ末尾の言語指定を維持。それでも英語なら `--model` を変更 |
| 指摘の重大度分類が一貫しない | classify ルールが prompter ごとに揺れる | MUST/SHOULD/NICE の定義をテンプレ通りに渡す。独自解釈しない |
| `--model` を変えても結果が同じ (copilot) | argparse で model が agent に伝わっていない | Step 2 のテンプレで `{model}` を埋めているか確認 |
| `--effort high` で response が異常に遅い (copilot) | high は推論コストが大きい。レート制限に達することも | medium にフォールバック、または target を絞り込む |

## Usage

```
/plan-loop                                    # 会話中のプランを対象にループ開始 (codex)
/plan-loop path/to/plan.md                    # 指定ファイルを対象 (codex)
/plan-loop --tool copilot plan.md             # Copilot でレビュー
/plan-loop --tool copilot --model gpt-5       # Copilot + モデル指定
/plan-loop --tool copilot --effort high       # Copilot + 高推論レベル
```

### Parameters

| Param | Values | Default | Notes |
|---|---|---|---|
| `--tool` | `codex`, `copilot` | `codex` | レビューに使う外部 AI |
| `--model` | any model name | (tool default) | copilot 時のみ有効 |
| `--effort` | `low`, `medium`, `high` | (tool default) | copilot 時のみ有効 |

## Workflow

```python
plan = resolve_plan(args or conversation_context)
files = extract_related_files(plan)
tool = parse_tool_arg(args)       # "codex" (default) or "copilot"
model = parse_model_arg(args)     # copilot only; None if not specified
effort = parse_effort_arg(args)   # copilot only; None if not specified
round = 0
history = []

while True:
    round += 1
    if tool == "copilot":
        review = copilot_review(plan, files, history, model, effort)
    else:
        review = codex_review(plan, files, history)
    must, should, nice = classify(review)
    report_to_user(round, must, should, nice)

    if not must and not should:
        break
    if user_wants_to_stop():
        break

    approved = ask_user_which_to_address(must + should)
    apply_feedback(plan, approved)
    history.append((review, approved))

print_summary(history)
```

## Step 1: プラン準備

プランファイルを特定する。引数があればそのパスを使用。なければ会話コンテキストから直近のプランファイルパスを探す。

プランが存在しない場合はユーザーに確認してから作成を支援する。

## Step 2: レビュー依頼

`--tool` に応じた agent を `subagent_type: codex` または `subagent_type: copilot` で起動する。
プロンプトに含める内容:

1. プランファイルのパス（agent に読ませる）
2. レビュー対象の関連ソースファイル一覧
3. レビュー観点の指定
4. 前回のレビュー結果と対応内容（2回目以降）
5. `--model` が指定されていればモデル指定 (copilot のみ)
6. `--effort` が指定されていれば推論レベル指定 (copilot のみ)

レビュープロンプトのテンプレート:

### 初回

```
以下の設計プランをレビューしてください。

## プランファイル
{plan_path} を読んでください。

## 関連ソースファイル
{file_list}

## レビュー観点
1. 設計: アーキテクチャの適切さ、責務分離
2. パフォーマンス: ホットパス、メモリ、計算量
3. スレッド安全性 / 並行性
4. 後方互換性: 既存の動作を壊さないか
5. テスト戦略: カバレッジの十分さ
6. エッジケース: 見落としている境界条件

## 出力形式
指摘を重大度で分類:
- [MUST] 対応しないとバグ・障害に直結
- [SHOULD] 対応すると品質が上がる
- [NICE] あると良いが必須ではない

日本語で回答してください。
```

### 2回目以降

```
前回の指摘への対応を反映したプランを再レビューしてください。

## プランファイル
{plan_path} を読んでください。

## 前回の指摘と対応状況
{previous_feedback_and_responses}

## レビュー依頼
1. 前回の指摘が適切に解消されているか確認
2. 対応により新たに生じた問題がないか確認
3. 残存する懸念点があれば指摘

同じ出力形式 ([MUST] / [SHOULD] / [NICE]) で回答してください。
日本語で回答してください。
```

## Step 3: FB 分類

Agent の回答から指摘を抽出し、重大度別に整理:

```
Round N レビュー結果:
  MUST:   X件 — {一覧}
  SHOULD: X件 — {一覧}
  NICE:   X件 — {一覧}
```

ユーザーに結果を報告し、対応方針を確認する。

## Step 4: プランに反映

ユーザーの承認を得た MUST + SHOULD 項目をプランに反映する。
各指摘に対して、プランのどの箇所をどう変更したかを追跡する。

## Step 5: 収束判定

以下のいずれかで終了:
- MUST と SHOULD が両方 0 件
- ユーザーが終了を指示

ラウンド数の上限は設けない。収束するまで繰り返す。

終了時、全ラウンドのレビュー結果サマリーを報告:

```
## Plan Review Summary (<tool>: <model if copilot>)

| Round | MUST | SHOULD | NICE |
|-------|------|--------|------|
| 1     | 3    | 5      | 2    |
| 2     | 2    | 3      | 1    |
| 3     | 0    | 1      | 0    |
| 4     | 0    | 0      | 0    |

対応済み: X件 / 未対応 (NICE): X件
```

## Anti-patterns

| 合理化 | 実像 |
|---|---|
| 「2 ラウンドで MUST が出なかったから収束」 | 評価軸が偏っている可能性。観点 6 つすべてカバーされたか確認 |
| 「ユーザー承認をスキップして自動反映」 | プランが意図せず歪む。承認は省略しない |
| 「NICE も全部反映する方が品質高い」 | NICE は subjective。反映で別の人の判断が混入 |
| 「ラウンド数の上限を 3 にしておけば安全」 | 3 ラウンドで MUST が残ったまま打ち切られる。上限を設けないのが本来の設計 |
| 「外部 AI に任せれば中立な評価が出る」 | Codex も Copilot も prompt 設計の影響を受ける。テンプレを改変したら評価軸が揺れる |
| 「`--model gpt-5` の方が常に良い」(copilot) | モデル特性で得意領域が違う。観点ごとに使い分ける |
| 「`--effort high` を毎回つける」(copilot) | コストとレイテンシが跳ねる。MUST 出尽くした後の確認用に温存 |

## Related skills

- `/review-loop` — 実装コードを Codex でループ (plan ではなく code 対象)
- `/copilot-review-loop` — 実装コードを Copilot でループ (plan ではなく code)
- `/refactor-loop` — メトリクス駆動の構造改善ループ (CodeHealth 系、別系統)
- `/codex-review` — 単発の 4 観点並列レビュー (Codex)
- `/copilot-review` — 単発レビュー (Copilot)
- `empirical-prompt-tuning` (mizchi) — このスキル自体の品質を bias-free に評価

## Notes

- Codex agent は `subagent_type: codex`、Copilot agent は `subagent_type: copilot` で起動する
- `--tool` 未指定時は codex にフォールバック（後方互換性）
- `--model`, `--effort` は `--tool copilot` 時のみ有効。codex 指定時にこれらを渡しても無視する
- プランの関連ファイル一覧は会話コンテキストまたはプラン内のファイルパスから自動抽出する
- 各ラウンドのレビュー結果は次ラウンドのプロンプトに含め、同じ指摘の繰り返しを防ぐ
- NICE 項目は対応を強制しない。ユーザー判断に委ねる
