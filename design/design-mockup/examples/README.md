# examples/ — ⚠️ 過適合注意

## このディレクトリの位置づけ

各サブディレクトリは「過去のあるプロジェクトで生成された完成例」であり、**模倣対象ではない**。

設計の参考になるのは generic 基盤の使い方 (state→HTML 純粋関数 / event delegation /
flowFrames / matrixScreens / flowEdges のデータ構造) のみ。

## ⚠️ 過適合警告

新しいプロジェクトで mockup を生成する際、以下を **絶対に流用しない**:

| 流用 NG | 理由 |
|---|---|
| view 関数の構造 (例: `listView`, `detailView`, `readingView`) | 例のドメイン (Web 記事リーダー / 業務用 settings 等) に固有 |
| SAMPLE 配列のデータ形 (`{ id, title, byline, ... }`) | 例のドメインモデル |
| flowFrames の画面名 (`List View` / `Detail` / `Reading`) | 例のアプリ構造 |
| flowEdges のラベル (`click card` / `← back` / `read`) | 例のインタラクション |
| handleAction の switch case (`select-card` / `open-reading` / etc) | 例の action 名 |

## 流用してよいもの

| 流用 OK | 理由 |
|---|---|
| `@layer tokens / base / canvas` の構造 | 純粋に generic な基盤 |
| `drawEdges` / `anchor` / `curve` / `frameStates` / event delegation | generic ロジック |
| viewport プリセットの値 (320×568, 375×667, ...) | デバイス標準 |
| `data-action` / `data-frame-key` パターン | アーキテクチャ規約 |
| `state.kind` で view を switch する pattern | アーキテクチャ規約 |
| dropdown 即閉じ対策 (`if target.tagName === 'SELECT' return`) | 既知バグの回避策 |

## 推奨ワークフロー

新プロジェクトで mockup を作るときは:

1. `templates/overview.html` を base にする (**examples を base にしない**)
2. プロジェクトの実装 (UXML/JSX/Vue SFC/Swift View) を Read して画面構造を把握
3. その構造に基づいて view 関数を **ゼロから書く** (examples の view 関数を真似ない)
4. tokens は project の styles から取り込む (examples の tokens を流用しない)
5. SAMPLE データはプロジェクトのドメインで一新

## 既存例

| ディレクトリ | ドメイン | 教訓 |
|---|---|---|
| `eveng2-reader-settings/` | Web 記事リーダーの設定画面 | 4画面 (List/Detail/Reading/Settings) のフロー。view 関数は記事ドメインに固有 |

(過適合誘発を避けるため、example は意図的に少数に絞る方針)
