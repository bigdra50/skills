---
name: docs-architect
description: |
    リポジトリのドキュメント構成を診断し、雛形生成・増築・再編を行うスキル。
    約 50 OSS の構成調査 (survey-any: oss-documentation-structure-patterns) に基づき、
    「診断 → 処方 → 承認 → 適用 → 検証」のパイプラインで段階に合った構成を処方する。
    モード: audit (診断のみ) / init (新規雛形) / grow (増築) / restructure (構造再編)。
    Use when: ユーザーが「ドキュメント整備して」「docs の雛形作って」「README 整理したい」
    「ドキュメント構成を診断して」「docs が陳腐化してるので再編したい」「docs-architect」
    「ドキュメント構造を見直したい」「この repo に必要なドキュメントは?」と依頼したとき。
    新規 OSS リポジトリの立ち上げ、コードが動き始めた段階での docs 着手、
    既存 docs の大規模リストラクチャのいずれにも使う。
license: MIT
---

# docs-architect

リポジトリのドキュメント構成を診断し、プロジェクトの種別・段階に合った構成を処方・適用する。

設計原則 (全モード共通):

1. 責務分離 — 1 ファイル 1 責務。README に何でも書かない
2. 正本一元化 — 詳細の正本は 1 箇所、他は全部ポインタ。二重メンテを作らない
3. 読者軸 — user / contributor / maintainer / operator の誰向けかを常に明示する
4. 箱を先に作らない — 空の Diátaxis 4 分類や空ディレクトリの生成は禁止 (Diátaxis 公式の警告)
5. 持たないファイルも処方 — community files の機械的全部置きはアンチパターン。省略は理由付きで明示する

## モード判定 (2 軸分離)

「ユーザー意図 → モード」と「repo 状態 → 診断結果」は別物。
repo 状態からモードを自動決定しない。状態は提案材料に留め、モードはユーザー指示を優先する。

| モード | ユースケース | 書き込み |
|---|---|---|
| audit | 現状診断だけ欲しい / 他モードの入口 | なし (read-only) |
| init | 新規リポジトリの雛形生成 | 新規ファイルのみ |
| grow | コードが動き始めて docs を書き足す段階 | 追加 + 既存の軽微修正 |
| restructure | 陳腐化・構造劣化した docs の大規模再編 | 移動・統合・削除 (承認ゲート必須) |

引数なしで呼ばれたら: 診断を実行し、結果と推奨モードを提示して AskUserQuestion でモードを確認する。

## パイプライン

全モード共通で以下を順に実行する。
audit はステップ 1 (診断) の成果物 = 診断レポートで終了する。
処方テーブル (Create/Defer/Omit) は出さず、気付いた改善候補は「観察 + 発動トリガー」の形で診断レポートに含めてよい (それを実行するのは他モードの仕事)。

### 1. 診断 (事実収集 + 解釈)

```bash
python3 scripts/docs_inventory.py <repo-root>   # JSON で事実のみ出力
```

スクリプトは判定しない。出力された事実を読み、以下を確信度付きで解釈する:

- プロジェクト種別: library / CLI / Web アプリ・サービス / 業務システム (判定根拠を明示)
- 現在の配信トポロジー: S1〜S7 (`references/stages.md` 参照)
- 読者構成: user / contributor / maintainer / operator のどれが存在するか。非開発者を含むか
- 運営体制: 個人 / org / 企業 (ガバナンスファイルの要否に直結)
- 劣化シグナル: docs とコードの最終更新乖離、リンク切れ、正本の重複、孤立ファイル

スクリプト出力の解釈既定:

- `links.site_absolute_unverified` は broken ではない (ビルド時解決)。ジェネレータ設定 (Docusaurus の `onBrokenLinks` 等) を cross-check して健全性を判定する
- audit での既存構成の評価は「機能充足」で行う。このスキルの規範 (例: AGENTS.md 正本方向) との体裁差は欠陥でなく観察として報告する

判定に迷う事実 (monorepo の package 毎差異、生成物か手書きか不明な docs 等) は推測せずユーザーに確認する。

### 2. 処方

`references/stages.md` と `references/prescriptions.md` に基づき、目標構成を提案する。
ファイル単位で必ず 3 分類する:

| 分類 | 意味 | 必須メタ |
|---|---|---|
| Create now | 今作る | Owner (誰が更新) / Validation (陳腐化をどう検出) |
| Defer until trigger | 条件成立まで作らない | Trigger (何が起きたら作るか) |
| Intentionally omit | 意図的に持たない | 理由 + 機能の代替先 |

S1〜S7 は成熟度ではなく配信トポロジー。上の段階ほど良いわけではない (ripgrep は 65k★ で S2 を維持)。
段階を飛ばす提案をしない。移行は隣接段階への移行トリガーが成立しているときのみ。

### 3. 承認

処方の差分 (作る / 作らない / 動かす) を提示し、AskUserQuestion で承認を得る。
restructure では移行台帳 (`references/restructure.md`) の承認を別途必須とする。

### 4. 適用

- テンプレートは `templates/` の条件付き fragment から組み立てる。完成形テンプレの丸コピーをしない
- fragment 内のプレースホルダは repo の実情報で必ず埋める。埋められない項目はファイルに残さず削る
- restructure の移動は `git mv` を使い履歴を保持する。削除は移行台帳で承認済みのもののみ

### 5. 検証

`references/checklists.md` の検証チェックリストを実行する。
最低限: 相対リンク切れゼロ / 各ファイルの責務が 1 つ / 正本と重複する記述がない / 空ファイル・空ディレクトリがない。

## 非対話環境でのフォールバック

subagent 実行など AskUserQuestion が使えない環境では:

- 承認・確認したい内容 (処方の差分、移行台帳、確認事項) を成果物レポートに必ず明示する
- その上で標準推奨 (このスキルの処方既定値) を承認済みとして続行してよい。段下げスキップや台帳承認などの critical な承認も同じ扱いでよい (ただしレポートで「承認扱いで適用した」と明示する)
- audit で確認したい点が出た場合は、レポート末尾に「ユーザー確認事項」として列挙し最尤解釈で続行する

## 安全ルール (厳守)

- restructure で既存内容を削除・統合する前に、必ず移行台帳 (旧パス → 新パス → 内容の行き先) を提示し承認を得る
- 内容の行き先が決まらない文書は削除せず保留リストに残す。分岐基準: 行き先・価値の判断がつかない → hold (据え置き) / 陳腐化したが履歴価値がある → archive (詳細は references/restructure.md の処置表)
- 公開 URL を持つ docs サイトの再編では redirect 設定の生成までをスコープに含める
- AGENTS.md / CLAUDE.md は AGENTS.md を正本にし、CLAUDE.md は `@AGENTS.md` 1 行 import (既存 CLAUDE.md があれば統合方針をユーザーに確認)

## References (必要時に読む)

| ファイル | 内容 | 読むタイミング |
|---|---|---|
| `references/stages.md` | S1〜S7 配信トポロジーと移行トリガー | 診断・処方時に必ず |
| `references/prescriptions.md` | 種別別 (library/CLI/Webアプリ/業務) の処方箋 | 処方時に必ず |
| `references/restructure.md` | 移行台帳・redirect・段階適用の手順 | restructure 時のみ |
| `references/checklists.md` | anti-cargo-cult チェック + 検証チェックリスト | 処方時と検証時 |
| `templates/*.md` | 条件付き fragment (README/AGENTS.md/ADR/業務文書) | 適用時のみ |

出典: 調査本文は survey-any の `topics/oss-documentation-structure-patterns/` (ghq 管理下にあれば `ghq list --full-path | grep survey-any` で解決可)。判断根拠を深掘りしたいときのみ参照する。
