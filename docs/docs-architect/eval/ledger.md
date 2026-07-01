# Failure pattern ledger (docs-architect)

empirical-prompt-tuning の累積失敗パターン台帳。修正を当てる前にここを必ず走査する。

## 結果サマリ

| iter | A | B | C | 新規 unclear | 適用した修正テーマ |
|---|---|---|---|---|---|
| 1 (baseline) | ○ 100% | ○ 92% | ○ 92% | 9 | — |
| 2 | ○ 100% | ○ 92% | ○ 100% | 4 (うち再発 0) | 手順の境界と処置定義の明確化 |
| 3 | ○ 100% | ○ 100% | ○ 100% | 6 (うち再発 4 = 未修正の deferred 項目) | 非対話環境フォールバック |
| 4 | ○ 100% | ○ 100% | ○ 100% | 4 (うち再発 2) | 既定値と判定基準の明文化 |
| 5 (修正のみ) | — | — | — | — | 入力値導出規律 + ツール出力の層別 (owner 導出 / コマンド検証 / symlink target / broken_by_top) |
| hold-out (grow) | — | ○ 100% | — | 2 (軽微) | — (overfit 検査: 直近平均から低下なし) |

検証済み効果:
- iter1→2: C の git mv 履歴保持 partial→○ (move-only コミットで R100)。audit 終了点曖昧も解消
- iter2→3: 非対話フォールバックが A/B/C 全てで参照され、裁量判断が「規定された degradation path の遵守」に変わった
- iter3→4: site_absolute 解釈・規範 vs 評価分離・hold/archive 分岐が executor に引用される。B が .gitignore を処方に含めるようになった
- hold-out (grow、未使用シナリオ): 5/5 ○。+3 行のみの追加編集で MARKER 保持・段階維持・コード実態に基づく gap 分析。overfit なし

収束判定 (2026-06-07): 実用収束として終了。
metrics は iter3/4 + hold-out で 3 ラウンド連続 100%。
「新規 unclear 0」の厳格条件は未達だが、iter4 以降の新規指摘は配置・文言の改善提案レベルに減衰しており、
deferred だった再発クラスタは iter5 で全て修正済み (修正の再検証は次回 skill 改修時の回帰テストで兼ねる)。

## パターン一覧

- **mode 終了ステップの inclusive/exclusive 曖昧**
  - Example: audit が「ステップ 2 で終了」と書かれ、処方テーブルを出すべきか executor が裁量判断 (iter1-A)
  - General Fix Rule: モードを停止ステップで定義するときは、そのステップの成果物を含むか含まないかを明記する
  - Seen in: iter1。Fixed in: iter2 (SKILL.md 「診断レポートで終了。処方テーブルは出さない」)。iter2 で再発なし

- **処置タイプの物理配置が未定義 (hold vs archive)**
  - Example: hold は据え置きか移動か不明で archive と混同 (iter1-C)
  - General Fix Rule: 各処置タイプに「ファイルを物理的にどこへ置くか」を 1 対 1 で定義する
  - Seen in: iter1。Fixed in: iter2 (restructure.md 処置×配置表)。iter2 で再発なし

- **move + edit 同一フェーズで rename 検出が壊れる**
  - Example: git mv 直後に ARCHIVED バナーを編集し類似度 40% 未満で D+A 表示 (iter1-C)
  - General Fix Rule: move フェーズと content-edit フェーズをコミット単位で分離し、move 直後に --find-renames で R を検証してから編集する
  - Seen in: iter1。Fixed in: iter2 (restructure.md §5)。iter2 は R100 達成

- **隣接段階ルールの方向 (下り) 未規定**
  - Example: 劣化 S3 → S1 への 2 段下げが裁量判断になった (iter1-C)
  - General Fix Rule: 移行ルールは上り/下りで別規定にする (上り=隣接のみ、下り=スキップ可・根拠と承認明示)
  - Seen in: iter1。Fixed in: iter2 (stages.md)。iter2-C は S↓ 規則を引用して判断

- **非対話環境での承認・確認ゲートのフォールバック未定義**
  - Example: AskUserQuestion 不可の subagent が承認ステップで裁量対応 (iter1-B, iter2-A, iter2-B — 3 回出現)
  - General Fix Rule: 対話的確認ステップには非対話時の degradation path (内容をレポートに明示 + 標準推奨で続行) を併記する
  - Seen in: iter1, iter2 ×2。Fixed in: iter3 (SKILL.md「非対話環境でのフォールバック」節)。iter3/4 の全シナリオで参照・遵守を確認。iter4 で critical 承認の扱いも追記

- **診断スクリプトが関係フラグのみで解決先を出さない**
  - Example: agents_md_is_symlink=true だが向き先不明で readlink が別途必要 (iter1-A)
  - General Fix Rule: is_symlink 等の関係フラグには resolved target を併記する
  - Seen in: iter1, iter4 (last_commit 経路差の変種)。Fixed in: iter5 (script が symlink_target を出力)

- **ツールで検証不能なリンク類の扱い指示欠落**
  - Example: site_absolute_unverified をどう扱うかが checklists に無い (iter1-A)
  - General Fix Rule: ツールが検証できないクラスは「unverifiable + フレームワーク設定の cross-check 指示」をセットで書く
  - Seen in: iter1, iter3。Fixed in: iter4 (SKILL 解釈既定) + iter5 (broken_by_top 層別)。iter4-A で正しく解釈されたことを確認

- **Validation コマンドの実行順序・呼び出し契約が未規定**
  - Example: pip install -e . 前に pytest を実行して偽陽性 / console-script を経由せず cli.py を直接実行 (iter1-B, iter2-B 類似)
  - General Fix Rule: AGENTS.md 検証は文書化された順 (Setup→Build→Test) と宣言済み entry point で行う。検証の副産物 (__pycache__ 等) は片付ける
  - Seen in: iter1, iter2, iter4 (.[test] 変種)。Fixed in: iter5 (agents-md.md に実行順検証 + 副産物片付けを明記)

- **remote 不在時の owner 推定手順欠落**
  - Example: Discussions URL / LICENSE 著作者を git config から推定 (iter1-B, iter2-B)
  - General Fix Rule: remote 依存の値は「derive + 要確認フラグ」として扱う手順を書く
  - Seen in: iter1, iter2, iter4。Fixed in: iter5 (prescriptions.md に導出優先順 + 要確認フラグ規律)

- **段階適用レシピが multi-tree 前提で collapse 時の no-op を未規定**
  - Example: S↓ collapse では「ハブ作成コミット」が no-op になるが明記なし (iter2-C)
  - General Fix Rule: 手順レシピには「この条件ではこのステップは no-op」を明記する
  - Seen in: iter2。未修正

- **S1 と読者軸原則の見かけ上の矛盾**
  - Example: S1 (README 完結) は読者混在が必然だが原則 3 が例外を持たない (iter2-C)
  - General Fix Rule: 原則には適用境界 (S1 では見出しで読者軸を表現) を書く
  - Seen in: iter2。未修正

- **参照ドキュメントの例示 repo と診断対象の自己参照**
  - Example: stages.md が pdfme を S4 例として名指し → 判定が例一致に寄りかかるリスク (iter2-A)
  - General Fix Rule: 判定は独立 signal から導き、例一致は補強に留める旨を明記
  - Seen in: iter2。未修正 (低優先)

## インフラ教訓 (skill でなく評価手順側)

- fixture を /tmp に置くとサンドボックスのセッション分離で消える → ~/.cache/docs-arch-eval に置く (setup-fixtures.sh)
- 評価は自己申告だけで採点しない。マーカー残存・R 検出・porcelain は必ず機械検証する
