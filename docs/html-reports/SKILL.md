---
name: html-reports
description: |
  プロジェクトの分析・計画・監査結果を構造化された HTML レポートとして管理するスキル。
  .claude/reports/ にプロジェクト毎のデータを出力し、4種類のテンプレート
  (review / plan / audit / adr-analysis) からスケルトン生成、index による横断管理を提供する。
  Use when: "レポート初期化", "新規レビュー作って", "実装計画ファイル作って",
            "品質監査レポート作成", "ADR分析作って", "html-reports init",
            "/reports-init", "/report-new", ".claude/reports をセットアップ"
---

# html-reports

HTML レポートの生成・管理スキル。コード参照・diff・Mermaid 図・Chart.js・優先度カード等の
リッチな表現を活用し、Markdown では表現しづらい分析結果や計画を構造化して残す。

## 何ができるか

| 種別 | 用途 | 主な可視化 |
|------|------|-----------|
| review | コードレビュー結果 | 指摘カード (優先度色) / Before-After diff / 判断サマリ |
| plan | 実装計画 | フェーズ別タスク / Gantt / 依存グラフ / 進捗バー |
| audit | 品質監査 | KPI / 推移チャート / Heatmap / 優先度マトリクス |
| adr-analysis | 設計判断分析 | 代替案カード / 決定マトリクス / トレードオフレーダー |

レポート同士は相互リンク可能。Review → ADR Analysis → Plan → Audit の一連の流れで追跡できる。

## ディレクトリ構造

```
.claude/skills/html-reports/         # このスキル（配布元）
├── SKILL.md                         # 本ファイル
├── templates/                       # HTML 雛形（4 種類）
├── assets/                          # CSS/JS 配布元 (theme/components/reports.js)
├── boilerplate/                     # init 時にコピーする (index.html, _index.js, README.md)
├── scripts/                         # シェルスクリプト
│   ├── init.sh                      # プロジェクト初期化
│   ├── new-report.sh                # 新規レポート生成
│   └── update-assets.sh             # アセット同期
└── reference/
    └── visualization-catalog.md     # 表現要素一覧

<project>/.claude/reports/           # プロジェクト側（出力先）
├── index.html                       # 検索・フィルタ付き一覧
├── _index.js                        # マニフェスト
├── _assets/                         # assets/ のコピー
├── reviews/  plans/  audits/  adr-analysis/
└── <type>/<YYYY-MM-DD>-<slug>.html
```

## 使い方

呼び出し経路は 3 通り。プロジェクトに `mise.toml` で task を定義すれば最短で叩ける。

| 操作 | mise (推奨) | slash command | 直接実行 |
|------|-------------|---------------|---------|
| 初期化 | `mise run report:init` | `/reports-init` | `.claude/skills/html-reports/scripts/init.sh` |
| 新規 | `mise run report:new -- <type> <slug> [title]` | `/report-new` | `.claude/skills/html-reports/scripts/new-report.sh <type> <slug> [title]` |
| 開く | `mise run report:open` | `/reports-open` | `open .claude/reports/index.html` |
| 更新 | `mise run report:update-assets` | `/reports-update-assets` | `.claude/skills/html-reports/scripts/update-assets.sh` |
| 一覧 | `mise run report:list` | — | `mise tasks \| grep ^report:` |

### 1. プロジェクト初期化

`.claude/reports/` が存在しないプロジェクトでは、最初に init を実行する。

```bash
mise run report:init
```

これで以下が作成される:
- `.claude/reports/` ディレクトリ
- `_assets/`, `reviews/`, `plans/`, `audits/`, `adr-analysis/` サブディレクトリ
- `index.html`, `_index.js`, `README.md`

### 2. 新規レポート作成

```bash
mise run report:new -- <type> <slug> [title]
# 例:
mise run report:new -- review shallow-class-issue68 "Issue#68 浅いクラスレビュー"
mise run report:new -- plan title-provider-refactor
```

- type: `review` | `plan` | `audit` | `adr-analysis`
- slug: kebab-case 推奨
- title: 省略時は slug をそのまま使用

挙動:
1. templates/<type>.html を `.claude/reports/<type-plural>/YYYY-MM-DD-<slug>.html` にコピー
2. `<title>` と `<meta name="report:date">` を更新
3. `_index.js` の `REPORTS_INDEX` にエントリを追加 (status=draft)
4. パスを stdout に出力

### 3. index を開く

```bash
mise run report:open
```

### 4. アセット更新

スキル側 (`.claude/skills/html-reports/assets/`) を改善したら、各プロジェクトで同期:

```bash
mise run report:update-assets
```

差分を表示してから上書き確認する。

## Claude の動作指針

ユーザーが「レポート作って」「新規レビュー」「実装計画ファイル」等と依頼したとき:

1. プロジェクトに `.claude/reports/` があるか確認
   - なければ `mise run report:init` で bootstrap
   - mise が無いプロジェクトの判定: `[ -f mise.toml ] && command -v mise && mise tasks 2>/dev/null | grep -q '^report:'` が偽 → `scripts/init.sh` 直接
2. ユーザーの意図から `type` を判定:
   - "レビュー" / "コードレビュー" → review
   - "実装計画" / "plan" / "TODO リスト" → plan
   - "品質監査" / "audit" / "メトリクス分析" → audit
   - "ADR" / "設計判断" / "代替案比較" → adr-analysis
3. `slug` を決定 (下記いずれか):
   - ユーザーが明示指定 → そのまま採用
   - ユーザーに尋ねられる対話コンテキスト → `AskUserQuestion` で 2-3 候補を提示
   - **非対話コンテキスト (自動化・サブエージェント呼び出し)** → 依頼の要点を kebab-case 化して即採用
     - 例: 「VContainer DI 設計レビュー」→ `vcontainer-di-design`
     - 例: 「SettingsImportExport 実装計画」→ `settings-import-export`
     - **人名フィールドの扱い**: `Reviewer: 名前` / `Owner: 担当者` / `author: ""` 等は **span ごと削除 or 空のまま**。担当者不明の人名を捏造しない。
4. `mise run report:new -- <type> <slug> "<title>"` を実行 (step 1 と同じ判定で mise 不可なら `scripts/new-report.sh` 直接)
5. 生成された HTML を Edit ツールで埋めていく (**下記「テンプレートの解釈ルール」参照**)
6. `_index.js` の新規エントリを補完:
   - `tags`: 3-5 個 (kebab-case、内容を表す関連キーワード)
   - `summary`: 1〜2 行の本文要約
   - `status`: 初版完成時に `draft` → `done`
   - `author`: 担当者名 (省略可)
7. 必要なら `mise run report:open` で開く

## テンプレートの解釈ルール

テンプレートは「埋めるべき骨組み」であって「そのまま流用するサンプル」ではない。
ステップ 5 (HTML 編集) では以下を機械的に処理する。

### A. 繰り返し可能ブロック — 件数はコンテンツに合わせて増減してよい

| クラス | 1 件 = |
|--------|--------|
| `.card.priority-*` | 指摘 1 件 |
| `.task-item` | タスク 1 件 |
| `.metric` | 計測値 1 件 |
| `.verdict-item` | 判断 1 件 |
| `.phase-card` | フェーズ 1 件 |
| テーブルの `<tr>` | 行 1 件 |

**複製手順**: テンプレ内で最も完全な 1 件を **canonical sample** として選び、それを複製して並べる。
例: review なら `.card.priority-1` 全体をコピー → `priority-N` の N を変えて連続挿入 → 各カードの中身を新しい指摘で置換。

### B. プレースホルダ判定 — まず原則、迷ったら決定木

**原則**: テンプレート内のあらゆる **具体的データ** は placeholder。
残すのは **構造とカテゴリ名のみ**。

```
編集対象の要素は何か?
├── HTML 構造タグ (<div>, <table>, class名)        → そのまま
├── セクション見出し (h1/h2/h3 の汎用ラベル)       → そのまま
│   例: "## 要約", "Phase 1: 設計", "判定理由"
└── 具体的データ                                    → 置換 or 要素削除
    - ファイル名・パス・コード参照 (path/to/File.cs:42)
    - 日付・数値・割合・工数 (3/12, 2 days, 2h, 8.42, +0.21 vs W19)
    - 固有名詞・他レポートの本文 (ScenarioMetadataExtensions, AppStateMachine, etc.)
    - 人名・組織名 (名前, 担当者, チーム名)
    - リンク先 (../reviews/2026-05-20-...)
    - ステータス前提値 (Phase 2: active, "進行中"前提の done/in-progress)
    - 指示文言 ("具体的に何が問題かを書く", "...")
```

**判定ヒント**: 「テンプレに書かれている値が **そのままレポートに残ったら他の読者が困るか**」を自問する。
困るなら placeholder。困らない (= 構造/ラベル) ならそのまま。

### C. 任意セクション — 内容が無ければ section ごと削除してよい

- Gantt 図 / 依存関係グラフ (該当データが無い計画)
- 関連リンクのリスト (リンク先が無い)
- リスク表 (リスクが無い)
- Mermaid 図 (図解の意味がない短いレポート)

逆に **必須セクション** (削除不可):
- ヘッダー (`<header class="report-header">`)
- 要約 (`## 要約` + `.summary`)
- 本文に該当する繰り返しブロック (review: `.card`、plan: `.phase-card`、audit: KPI + メトリクス、adr-analysis: 代替案カード)

### D. priority-* の意味論 (review / verdict 系)

| クラス | 意味 |
|--------|------|
| `.priority-1` | High / Critical (起動失敗・データ破壊リスク) |
| `.priority-2` | High (機能不全) |
| `.priority-3` | Med (保守性悪化・要再評価) |
| `.priority-4` | Low (改善余地) |
| `.priority-5` | 情報 (記録のみ) |

判断に迷う指摘は `.priority-3` に置く。

### E. status の意味論 (`_index.js`)

| status | 意味 | 遷移条件 |
|--------|------|---------|
| `draft` | 着手前の骨組み (script デフォルト) | `new-report.sh` 実行直後 |
| `in-progress` | 作業中 (主に plan で進行中フェーズあり) | 一部タスクのみ完了 |
| `done` | 初版完成・閲覧可能 | 本文を埋め終えた時点 |
| `archived` | 古い / 参照のみ | 結論が覆った、または期限切れ |
| `template` | テンプレート参照用 (通常使わない) | — |

レビュー前/後を区別したい場合は `tags` に `reviewed` を追加するなど運用で対応 (status は追加しない)。

### F. 表現要素のカタログ参照

実装中に「この見た目どう書くんだっけ」と迷ったら `reference/visualization-catalog.md` を参照する。
- 各クラスの HTML 例
- CSS 変数 (色パレット)
- Mermaid / Chart.js の最小例

## 留意点

- アセットは **コピー方式**: init/update で `.claude/reports/_assets/` に複製される。
  レポートは自己完結し、メール添付や別環境でも表示できる。
- `_index.js` は JS で書く (file:// プロトコル制約のため JSON だと CORS で fetch 不可)。
- レポート内の Mermaid / Chart.js は CDN から動的ロード (`_assets/reports.js` が判定)。
  オフライン時は図表が表示されない。
- 静的解析の生データ (`*.sarif`, `*.json`) は `.gitignore` で除外推奨。
  HTML レポートのみ commit する運用を想定。
- **boilerplate ファイル** (`index.html` / `README.md`) は init で配置されるプロジェクト共通の枠組み。
  個別レポートの編集とは別物なので、init 直後に書き換える必要は無い。
  プロジェクト固有の説明を載せたい場合のみ `README.md` 末尾に追記する。

## 関連リファレンス

- `reference/visualization-catalog.md` — 利用可能な表現要素の一覧
- スキル配布元の例: 本プロジェクト `.claude/reports/reviews/2026-05-20-shallow-class.html`
