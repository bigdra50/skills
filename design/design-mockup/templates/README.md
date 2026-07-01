# templates/

design-mockup スキルの **骨格テンプレート**。「触らなくていい generic 基盤」を提供し、project 固有の view 関数・SAMPLE・flow data はプロジェクト側で書き換える前提。

## ファイル

- `overview.html` — フロー俯瞰 + States Matrix の骨格 (約 400 行)
- `index.html` — ハブページの骨格

`comparison.html` は templates から削除。デザイン案比較は project ごとにバリエーションが極端に異なるため、テンプレ化が困難。必要なときは overview.html の構造 (canvas/frame) を流用しつつ overview.html を base にスクラッチで作る。

## overview.html の構造

3 つのレイヤに分かれる:

### 1. generic 基盤 (絶対 touch しない)

`@layer canvas`、`drawEdges` / `anchor` / `curve` / `frameStates` / `viewport-controls` /
event delegation / ResizeObserver。

これらはどんな project でも同じ動作を提供する。コードを読む必要はない。

### 2. tokens (project の :root をここに上書き)

`@layer tokens` 内の `:root` ブロック。プロジェクトの `styles.css` / `tokens.uss` /
`globals.css` などから抽出した `--bg` / `--accent` / `--text` 等で上書きする。

なければデフォルト維持。テンプレが使うトークン (`--surface-2`, `--ok` 等) が source CSS に
ない場合は、テンプレ既定値で補う (rule を消さない)。

### 3. specific 部分 (project 固有、必ず書き換え)

| 箇所 | 何を書き換えるか |
|---|---|
| `<title>` / `.stage-head h1`/`p` | プロジェクト名と説明 |
| `SAMPLE` | プロジェクトのドメインデータ (商品/ユーザー/タスク/シナリオ等) |
| view 関数 (`genericCardView` など) | **完全に置換**。プロジェクトの画面ごとに `renderHomeView` / `renderEditorView` / `renderHudView` 等を作る |
| `renderState()` の switch | view 関数追加に合わせて case を追加 |
| `flowFrames` | プロジェクトの画面ノードに置換 |
| `matrixScreens` | 各画面の variants に置換 |
| `flowEdges` | プロジェクトの画面遷移に置換 |
| `defaultXxxState()` | 各画面の初期 state ファクトリ |
| `handleAction` の switch | プロジェクトの action (back / select / submit / etc) に追加 |

## ⚠️ 注意: examples/ の扱い

`examples/eveng2-reader-settings/` は **動作する完成例**だが、これを「真似すべき設計」として
模倣すると過適合する (eveng2-reader は記事リーダーで、view 関数も list/detail/reading/settings
構造に固有)。

**examples は generic 基盤と「state→HTML 純粋関数」パターンを学ぶための参考。
view 関数の具体構造・SAMPLE データ・画面名は絶対に流用しないこと。**

新しい project で生成するときは:
1. templates/overview.html を base にする (examples は base にしない)
2. プロジェクトの実装 (UXML, JSX, Vue SFC, etc) を Read して画面構造を把握
3. その構造に基づいて view 関数を **ゼロから書く**

## comparison ページが必要な場合

overview.html を base に、以下のような構造で作る (LLM が書き起こす):

```
<div class="compare-grid">
  <article class="design">
    <header>案 A: ○○</header>
    <div class="frame">[案 A の HTML]</div>
  </article>
  <article class="design">
    <header>案 B: ○○</header>
    <div class="frame">[案 B の HTML]</div>
  </article>
  ...
</div>
```

各案は overview の generic 基盤を使い回す (CSS @layer / viewport / frame 構造)。
案ごとの違い (tokens, layout, density 等) を強調する。
