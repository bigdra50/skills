# .claude/reports/

HTML レポート（review / plan / audit / adr-analysis）のカタログ。
`html-reports` skill (`.claude/skills/html-reports/`) が配布元。

`index.html` から検索・フィルタ付き一覧でアクセスする。

## 使い方

呼び出し経路は 3 通り。

| 操作 | mise (推奨) | slash command | 直接実行 |
|------|-------------|---------------|---------|
| 一覧を見る | `mise run report:open` | `/reports-open` | `open .claude/reports/index.html` |
| 新規作成 | `mise run report:new -- <type> <slug> [title]` | `/report-new` | `.claude/skills/html-reports/scripts/new-report.sh <type> <slug> [title]` |
| 初期化 (再) | `mise run report:init` | `/reports-init` | `.claude/skills/html-reports/scripts/init.sh` |
| アセット同期 | `mise run report:update-assets` | `/reports-update-assets` | `.claude/skills/html-reports/scripts/update-assets.sh` |

type: `review` | `plan` | `audit` | `adr-analysis`

### 例

```bash
# 新規レビュー
mise run report:new -- review issue-XXX "Issue#XXX 浅いクラスレビュー"

# 新規実装計画
mise run report:new -- plan refactor-foo

# 新規 ADR 分析
mise run report:new -- adr-analysis title-provider-design "Title Provider 設計判断"

# ブラウザで一覧確認
mise run report:open
```

生成後の流れ:
1. 出力された HTML を編集 (テンプレートのプレースホルダを実コンテンツに置換)
2. `_index.js` の新規エントリの `tags`, `summary` を補完
3. 仕上げに `status` を `draft` → `done` に変更

## ディレクトリ構成

```
.claude/reports/
├── index.html              # トップページ (検索 + フィルタ + 一覧)
├── _index.js               # マニフェスト (new-report.sh が自動更新)
├── README.md               # 本ファイル
├── _assets/                # アセット (skill からコピー、update-assets.sh で同期)
│   ├── theme.css
│   ├── components.css
│   └── reports.js
├── reviews/                # コードレビュー
├── plans/                  # 実装計画
├── audits/                 # 品質監査
├── adr-analysis/           # 設計判断分析
└── *.sarif, *.json         # 静的解析の生データ (gitignore推奨)
```

## レポート種別と表現要素

| 種別 | 用途 | 主な可視化要素 |
|------|------|----------------|
| review | コードレビュー結果 | 指摘カード (優先度色) / Before-After diff / 判断サマリ |
| plan | 実装計画 | フェーズ別タスク / Gantt / 依存グラフ / 進捗バー |
| audit | 品質監査 | KPI / 推移チャート / Heatmap / 優先度マトリクス |
| adr-analysis | 設計判断分析 | 代替案カード / 決定マトリクス / トレードオフレーダー |

利用可能なコンポーネント一覧: `.claude/skills/html-reports/reference/visualization-catalog.md`

## ライブラリ依存 (CDN)

`_assets/reports.js` が必要なときだけ動的に読み込む。

| 用途 | ライブラリ |
|------|-----------|
| 図解 (シーケンス/フロー/Gantt/クラス図) | Mermaid 11 |
| シンタックスハイライト | Prism 1.29 |
| チャート (line/radar/bar) | Chart.js 4.4 |

オフライン時は図表が表示されない。

## ステータス

| status | 意味 |
|--------|------|
| `done` | 完成・閲覧可能 |
| `draft` | 作成中 (new-report.sh のデフォルト) |
| `in-progress` | 実装計画で進行中のフェーズあり |
| `archived` | 古い・参照用 |
