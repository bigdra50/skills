# docs-architect 回帰テスト計画

empirical-prompt-tuning 方式。シナリオ・チェックリストは固定 (変更しない)。
fixture は `bash setup-fixtures.sh` で再生成する (/tmp 不可 — サンドボックスのセッション毎に消える)。

## 実行手順

1. `bash eval/setup-fixtures.sh` で fixture を初期化
2. シナリオ A/B/C を blank-slate subagent (general-purpose) で並列実行
   - subagent には SKILL.md のパス + base directory + シナリオ + チェックリストを渡す
   - 採点キーは渡さない。AskUserQuestion 不可の旨と「標準推奨を承認済みとして続行」を明記
3. 自己申告と独立に、下の機械検証を実行して採点する

## シナリオ

| ID | モード | 対象 | 性格 |
|---|---|---|---|
| A | audit | pdfme ローカル clone (S4 TS monorepo lib) | median |
| B | init | fixture-b-cli (docs ゼロの新規 Python CLI、public 公開予定) | edge |
| C | restructure | fixture-c-messy (重複・陳腐化 docs + マーカー 8 個) | edge |
| hold-out | grow | README のみの repo にコードが育った状況 (収束判定時のみ新設) | overfit 検査 |

## 要件チェックリスト (subagent に渡す)

### A (audit)

1. [critical] 対象 repo への書き込みゼロ
2. [critical] 段階 (S1-S7) と種別の判定が根拠付きで一意
3. packages 配下 docs を repo 全体と区別 (monorepo を潰さない)
4. 上位段階への移行を無条件推奨しない
5. 診断スクリプトを実行し事実を解釈に使う
6. 確信度または根拠の明示

### B (init)

1. [critical] Create now / Defer / Intentionally omit の 3 分類、Omit 非空
2. [critical] 空ディレクトリ・空テンプレ・未記入プレースホルダを生成しない
3. 最小集合 (docs サイト・CONTRIBUTING・CoC・CHANGELOG を作らない)
4. README が standard-readme 順序
5. Create に Owner/Validation、Defer に Trigger
6. 適用前に処方提示 (承認ステップ)

### C (restructure)

1. [critical] 移行台帳が適用前に提示される
2. [critical] 既存文書の固有情報が失われない
3. git mv で履歴保持
4. 行き先未定文書は hold/archive (削除しない)
5. リンク切れが増えない
6. 重複の正本が 1 つに決まる

## 採点キー (subagent に渡さない)

- A: 正解 = S4 / library (TS monorepo) / packages README は極薄ポインタ型。pdf-lib fork のリンク切れ 41 件に言及があれば 5 は満点。実行後 `git -C <pdfme> status --porcelain` が空であること
- B: CLAUDE.md は `@AGENTS.md` 1 行。README の Usage が logsift の実フラグ (--level/--count) を反映。検証: `rg '\{\{|TODO' --type md` ゼロ、空ファイルゼロ、禁止物 (CONTRIBUTING 等) 不在
- C: MARKER-C1〜C8 が working tree に全残存 (C5/C8 は archive 先で可)。move コミットが独立し `git log --name-status --find-renames` で R100。`docs_inventory.py` で broken=0

## 機械検証コマンド

```bash
# A
git -C /Volumes/CrucialX9/dev/github.com/pdfme/pdfme status --porcelain   # 空であること
# B
cd ~/.cache/docs-arch-eval/fixture-b-cli
rg -l '\{\{|TODO' --type md .; cat CLAUDE.md; ls CONTRIBUTING.md docs 2>&1
# C
cd ~/.cache/docs-arch-eval/fixture-c-messy
for i in 1 2 3 4 5 6 7 8; do rg -l "MARKER-C$i" . ; done   # 8/8
git log --name-status --find-renames | rg '^R'              # move が R で検出されること
python3 <skill>/scripts/docs_inventory.py . | jq '.links.broken'   # []
```

## hold-out シナリオ D (grow) — 収束判定時のみ使用

fixture-d-grow の構成: fixture-b-cli と同じ logsift だが v0.3 に成長。
cli.py に `--format {jsonl,text}` と `--since ISO8601` を追加し、README は v0.1 のまま (新フラグ未記載)。
README に MARKER-D1 (固有の stdin tip) を含める。AGENTS.md なし。

チェックリスト:

1. [critical] 既存 README の固有内容 (MARKER-D1) が編集後も失われない
2. [critical] gap 分析がコードの実態に基づく (--format / --since が文書化される)
3. 段階を飛ばさない (docs サイト・大量 docs/ 新設をしない)
4. 処方が 3 分類 + Owner/Validation/Trigger
5. 空箱・placeholder を作らない

判定実績 (2026-06-07): 5/5 ○。+3 行のみの追加編集、段階維持、overfit なし。

## 成功判定

- 成功 = [critical] 全 ○ (自己申告と機械検証の両方)
- accuracy = ○:1 / partial:0.5 / ×:0 の加重平均
- 収束 = 2 ラウンド連続で「新規 unclear points 0 + accuracy 改善 +3pt 以下」→ hold-out (grow) で overfit 検査
