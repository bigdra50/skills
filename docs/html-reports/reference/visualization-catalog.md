# 表現要素カタログ

`html-reports` skill で利用可能な可視化・構造化要素の一覧。
すべて `_assets/components.css` + `_assets/theme.css` + `_assets/reports.js` で動作する。

## レイアウト

### `.container` / `.container-wide`

ページ全体のラッパー。`-wide` は監査などデータ密度が高いレポート向け。

```html
<div class="container">...</div>
<div class="container container-wide">...</div>
```

### `header.report-header` + `.meta`

レポートタイトルとメタ情報行。

```html
<header class="report-header">
  <h1>レポートタイトル</h1>
  <div class="meta">
    <span>Type: Review</span>
    <span>Date: 2026-05-20</span>
  </div>
</header>
```

## 構造化指摘

### `.card` + `.priority-{1..5}`

優先度カラーバー付きカード。1=赤（最優先）→ 5=灰（低）。

```html
<div class="card priority-1">
  <div class="card-header">
    <div class="card-title">#1 <code>path/to/File.cs:42</code></div>
    <span class="badge badge-bad">High</span>
  </div>
  <div class="signals">
    <span class="signal">情報漏洩</span>
    <span class="signal">薄いラッパー</span>
  </div>
  <dl>
    <dt>判定理由</dt><dd>...</dd>
    <dt>推奨アクション</dt><dd>...</dd>
  </dl>
</div>
```

修飾子: `.priority-1` (赤) / `.priority-2` (黄) / `.priority-3` (橙) / `.priority-4` (青) / `.priority-5` (灰) / `.good` (緑) / `.info` (紫)

### `.badge-{bad|warn|info|good|mute|purple}`

インラインステータス表示。

```html
<span class="badge badge-bad">Critical</span>
<span class="badge badge-warn">Warning</span>
<span class="badge badge-good">OK</span>
```

### `.tag`

小さいタグ pill（タグ一覧などに）。

```html
<div class="tag-row">
  <span class="tag">shallow-class</span>
  <span class="tag">refactor</span>
</div>
```

### `.signal`

カード内の検出シグナルチップ（角張った controlled-vocabulary 風）。

```html
<div class="signals">
  <span class="signal">情報漏洩</span>
  <span class="signal">呼び出し連鎖</span>
</div>
```

## サマリ表示

### `.summary` + `<div>`

冒頭の要約ブロック。

```html
<h2>要約</h2>
<div class="summary">
  <p>3行以内で結論を述べる。</p>
</div>
```

### `.metrics` + `.metric` (KPI tile)

数値カード群。Delta 表示付き。

```html
<div class="metrics">
  <div class="metric">
    <div class="metric-label">CodeHealth</div>
    <div class="metric-value">8.42</div>
    <div class="metric-delta up">+0.21 vs 前回</div>
  </div>
</div>
```

修飾子: `.metric-delta.up` (緑) / `.metric-delta.down` (赤)

### `.verdict` + `.verdict-item.{go|wait|discuss|stop}`

判断サマリ4分割。

```html
<div class="verdict">
  <div class="verdict-item go">
    <h4>即着手</h4>
    <p>説明...</p>
  </div>
  <div class="verdict-item discuss">...</div>
  <div class="verdict-item wait">...</div>
  <div class="verdict-item stop">...</div>
</div>
```

ドット色: go=緑 / wait=黄 / discuss=青 / stop=赤

## テーブル

### `table.report-table`

共通テーブル（hover ハイライト付き）。

```html
<table class="report-table">
  <thead>
    <tr><th>列1</th><th>列2</th></tr>
  </thead>
  <tbody>
    <tr><td>...</td><td>...</td></tr>
  </tbody>
</table>
```

修飾子: `.sticky` — ヘッダー sticky 化（長いテーブル向け）

## コード参照

### `code` (inline)

インラインコード。

```html
<code>path/to/File.cs:42</code>
```

### `<pre><code class="language-csharp">...`

シンタックスハイライト付き（Prism.js が自動ロードされる）。

```html
<pre><code class="language-csharp">
public class Foo {
  public void Bar() {}
}
</code></pre>
```

対応言語: csharp, javascript, typescript, json, yaml, bash, markdown, html, css, sql 等

### `.code-ref`

ファイルパスヘッダー付きコードブロック。

```html
<div class="code-ref">
  <div class="code-ref-header">
    <span class="path">Assets/App/Scripts/Foo.cs:42-50</span>
    <span class="lang">C#</span>
  </div>
  <pre><code class="language-csharp">...</code></pre>
</div>
```

## Diff

### `.diff` + `.diff-add/del/ctx`

インライン diff（unified 形式）。

```html
<div class="diff">
  <div class="diff-hunk">@@ -38,4 +38,3 @@</div>
  <span class="diff-line diff-ctx">public class Foo {</span>
  <span class="diff-line diff-del">    private int _x;</span>
  <span class="diff-line diff-add">    private int _x = 0;</span>
  <span class="diff-line diff-ctx">}</span>
</div>
```

### `.diff-side`

サイドバイサイド diff（Before/After 比較）。

```html
<div class="diff-side">
  <div>
    <div class="label">Before</div>
    <pre>...</pre>
  </div>
  <div>
    <div class="label">After</div>
    <pre>...</pre>
  </div>
</div>
```

## 進捗 / バー

### `.progress` + `.progress-bar`

```html
<div class="progress">
  <div class="progress-bar" style="width: 65%;"></div>
</div>
```

修飾子: `.progress-bar.good` (緑) / `.warn` (黄) / `.bad` (赤)

### タスクリスト

実装計画用。チェックボックス風表示。

```html
<ul class="task-list">
  <li class="task-item done">
    <span class="task-check"></span>
    <span class="task-label">調査完了</span>
    <span class="task-effort">2h</span>
  </li>
  <li class="task-item in-progress">...</li>
  <li class="task-item">...</li>
</ul>
```

状態: `.done` (完了) / `.in-progress` (進行中) / 無し (未着手)

## Heatmap

CSS Grid ベースの色階調マトリクス。

```html
<div class="heatmap" style="grid-template-columns: 140px repeat(5, 80px);">
  <div class="heatmap-cell">ラベル</div>
  <div class="heatmap-cell h-0">健全</div>
  <div class="heatmap-cell h-1">..</div>
  <div class="heatmap-cell h-2">..</div>
  <div class="heatmap-cell h-3">..</div>
  <div class="heatmap-cell h-4">注意</div>
</div>
```

色階調: `.h-0` (緑薄) → `.h-1` (緑濃) → `.h-2` (黄) → `.h-3` (橙) → `.h-4` (赤)

## 折りたたみ / Notes

### `details.collapsible`

開閉式コンテンツ。

```html
<details class="collapsible">
  <summary>詳細を見る</summary>
  <div class="body">
    本文...
  </div>
</details>
```

属性 `open` を付けると初期展開。

### `.note` (注釈)

```html
<div class="note">
  <strong>注:</strong> 説明...
</div>
<div class="note note-warn">...</div>
<div class="note note-bad">...</div>
<div class="note note-good">...</div>
```

## 図表

### Mermaid

`.mermaid-wrap` でラップすると caption 付きで表示される。
`reports.js` が自動的に Mermaid を CDN から読み込む。

```html
<figure class="mermaid-wrap">
  <div class="mermaid">
flowchart LR
  A[入力] --> B[処理]
  B --> C[出力]
  </div>
  <figcaption class="figcap">処理フロー</figcaption>
</figure>
```

対応ダイアグラム: flowchart, sequenceDiagram, classDiagram, stateDiagram, erDiagram, gantt, journey

### Chart.js (バー / 線 / レーダー)

HTML 末尾で `<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>` を追加し、canvas に描画。

```html
<div class="chart-wrap">
  <canvas id="my-chart" height="200"></canvas>
</div>

<script>
new Chart(document.getElementById("my-chart"), {
  type: "line", // 'line' | 'bar' | 'radar' | 'pie' | 'doughnut'
  data: { labels: [...], datasets: [{...}] },
  options: {...}
});
</script>
```

CSS変数で配色: `--accent` (#58a6ff), `--good` (#3fb950), `--warn` (#d29922), `--bad` (#f85149), `--info` (#a371f7)

## カラーパレット (CSS変数)

```
背景:      --bg (#0f1419), --bg-elev, --bg-card, --bg-code
テキスト:  --text (#e6edf3), --text-dim, --text-mute
境界:      --border, --border-soft
アクセント: --accent (青), --accent-warm (橙), --good (緑), --warn (黄), --bad (赤), --info (紫)
レポート種別:
  --type-review (青), --type-plan (緑), --type-audit (橙), --type-adr (紫)
```

すべて `theme.css` で定義。レポート内で直接参照可能。

## アンチパターン

- ASCII 図を使う必要はない。Mermaid または SVG が好ましい
- 多すぎる色: 1 レポート内で 4 色以上の優先度バッジを使わない
- ネストし過ぎたカード: `.card` 内に `.card` は基本避ける
- インラインスタイル乱用: 既存クラスで賄えるなら使う。微調整のみ inline で
