# restructure モードの手順

既存ドキュメントの大規模再編。最大リスクは「内容の喪失」と「リンク腐敗」。
以下の手順を省略しない。

## 1. 棚卸し (inventory)

docs_inventory.py の出力に加えて、全 doc ファイルについて以下を記録する:

- 役割 (user/contributor/maintainer/operator のどれ向けか。不明なら「不明」と記録)
- 正本か複製か (同じ内容が複数箇所にないか。重複は正本を 1 つ決める)
- 鮮度 (最終更新 vs 対応するコードの最終更新。生成物なら生成元)
- 被リンク (内部リンク・外部公開 URL・コード内からの参照。エラーメッセージ → docs 直リンク等)
- 生成物かどうか — 生成された docs を手編集しない境界を特定する。生成物は再編対象から除外し生成元を直す

## 2. 目標 IA の決定

prescriptions.md / stages.md に従い目標構成を決める。このとき:

- 現状の段階から隣接段階への移行のみ提案する (S2 の repo に S6 を提案しない)
- 既存文書の内容から構造を立ち上げる (Diátaxis 原則)。先に箱を決めて中身を割り付けない
- 読者軸での分割を最優先する (docs/ vs contribute/ の 2 ツリーが最小単位)

## 3. 移行台帳 (migration ledger) — 承認必須

全ての既存 doc ファイルを台帳に載せ、ユーザー承認を得てから動かす:

```markdown
| 旧パス | 処置 | 新パス / 行き先 | 内容の差分 |
|---|---|---|---|
| docs/setup.md | move | contribute/dev-setup.md | 変更なし (git mv) |
| docs/old-api.md | merge | docs/api.md §3 | 重複部を削除、固有部のみ移送 |
| docs/notes.md | hold | (保留リスト) | 行き先未定。削除しない |
| docs/roadmap-2023.md | archive | docs/archive/ | 陳腐化。履歴として保持 |
| README.md §API | extract | docs/api.md | README にはリンクを残す |
```

処置タイプと物理配置の定義 (1 対 1):

| 処置 | 物理配置 | 使う基準 |
|---|---|---|
| move | git mv で新パスへ | 内容は現役のまま場所だけ変える |
| merge / extract | 移送先に内容を足し、検証後に旧を git rm | 重複解消・README からの切り出し |
| archive | git mv で docs/archive/ へ + ARCHIVED 注記 + 後継ポインタ | 陳腐化したが履歴価値がある |
| hold | ファイルは元の場所に据え置く (移動も編集もしない) | 行き先・価値の判断がつかない。台帳とレポートに保留として列挙 |
| delete | git rm | 価値も履歴価値もないと承認されたもののみ |

ルール:

- hold が残ったまま完了としない (ユーザーに判断を委ねる)
- merge は「移送先に内容が存在すること」を検証してから旧ファイルを消す
- 移動は `git mv` (履歴保持)。コピー + 削除をしない
- 台帳にない削除を行わない

## 4. リンク・redirect の処理

- 移動した全ファイルについて、repo 内の被リンクを更新する (`rg -l '旧パス'` で参照元を全件検出)
- 公開 docs サイトがある場合は redirect を生成する: Docusaurus は plugin-client-redirects、Hugo は aliases、MkDocs/自前は frontmatter redirect_from (Metabase 型)
- コード内参照 (エラーメッセージの URL 等) も検索対象に含める

## 5. 段階適用

一括で動かさない。以下の単位でコミットを分け、各段階でリンク検査を通す:

1. 新構造のディレクトリ・ハブ (README のポインタ化) を作る
2. move / archive の「移動」だけ (git mv + 参照更新) — この段階では内容を 1 バイトも変えない
3. merge / extract と ARCHIVED 注記の追記 — 内容を変える操作。1 ファイルずつ
4. delete 群 — 最後。台帳承認済みのもののみ

move と内容編集を同一コミットに混ぜない。
混ぜると git の rename 検出 (類似度ベース) が壊れ、履歴追跡 (`git log --follow`) が切れる。
変更が小規模でも最低「移動コミット」と「編集コミット」の 2 つに分ける。
検証: 移動コミットの直後に `git diff HEAD~1 --find-renames --name-status` で全 move 行が `R` になっていることを確認してから編集に進む。

## 6. 検証

- 相対リンク切れゼロ (docs_inventory.py を再実行して broken_links を確認)
- 台帳の全行が完了 or hold で明示されている
- 旧パスへの参照が repo 内に残っていない
- checklists.md の検証チェックリストを通す
