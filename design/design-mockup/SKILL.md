---
name: design-mockup
description: |
  Figma Prototype 相当の操作可能 HTML モックアップを生成する。
  画面遷移俯瞰図 + States Matrix + viewport プリセット (実機 CSS px W×H) +
  auto-layout 検証を1ファイルにまとめる。プロジェクトの既存 CSS トークンを自動取り込み。
  Use when: ユーザーが「モックアップ作って」「画面遷移図」「Figma 風プロトタイプ」
  「flow mockup」「画面比較ページ」「デザイン案を並べて」「states matrix」
  「auto-layout 確認」「画面遷移を可視化」と依頼したとき。
  単独画面のスタイル提案だけなら frontend-design 系を使う。本スキルは
  「複数画面 + 遷移 + 状態網羅」を1ページで俯瞰したいときに使う。
user-invocable: true
---

# design-mockup

複数画面の遷移と状態を1ページで俯瞰できる、操作可能な HTML モックアップを生成する。

## skill 同梱ファイルへのアクセス (重要)

本文中の `templates/...` `examples/...` `README.md` 等の相対パスは、**SKILL.md と同じディレクトリ** を基点とする。

**ただし Read tool は呼び出し元 cwd で path 解決する** (skill ディレクトリは自動補完されない)。Read 呼び出し時は skill ディレクトリの絶対パスに展開すること:

- 個人 global: `~/.claude/skills/design-mockup/...`
- プロジェクト同梱: `<project>/.claude/skills/design-mockup/...`
- plugin: `~/.claude/plugins/cache/<plugin>/skills/design-mockup/...`

**手順**: 最初に `~/.claude/skills/design-mockup/SKILL.md` を Read し、ヒットしたディレクトリを skill ベースとして以降の相対パス展開に使い回す。1 つ目で外したら次の候補を試す。

## 何を作るか

| ファイル | 提供形態 |
|---|---|
| `overview.html` | テンプレ骨格 (~400 行) を base に project 固有部分を書き換える |
| `comparison.html` | テンプレなし。overview を base に LLM がスクラッチ生成 |
| `index.html` | テンプレ骨格を base に簡単な書き換え |

## ⚠️ 過適合 anti-pattern (最重要)

`examples/` の完成例 (eveng2-reader-settings 等) を **絶対に「真似すべき設計」として参照しない**。examples は generic 基盤の動作確認用であり、view 関数・SAMPLE データ・画面名は固有のドメインに密着している。

**模倣禁止リスト** (詳細は `examples/README.md`):
- view 関数の構造 (`listView` / `detailView` / `readingView` 等の名前と中身)
- SAMPLE 配列のデータ形 (例の `{ id, title, byline, ... }` 構造)
- flowFrames / flowEdges の画面名・ラベル
- handleAction の switch case 名

**正しい使い方**: `templates/overview.html` の骨格を base にし、プロジェクトの実装 (UXML/JSX/Vue SFC/Swift View) を Read して画面構造を把握 → view 関数を **ゼロから書く**。

## 設計原則 (このスキルの核心)

1. **frame の外形 = viewport CSS px (W×H)**
   `width: var(--viewport-px)` / `height: var(--viewport-h-px)`。`transform: scale()` は使わない (実機と同じ auto-layout 挙動を確保)。
2. **flex-wrap で並びを再計算**
   grid ではなく flex-wrap。viewport が変わると frame の物理サイズが変わり、並びも自動的に再評価される。
3. **状態は frame ごと独立 (Map<frameKey, state>)**
   フロー図の各 node も Matrix の各 frame も、それぞれ独自 state を持つ。Figma の Frames Matrix 相当。
4. **render(state) → HTML の純粋関数**
   各画面は state を引数に取り HTML 文字列を返す。再描画は単純に `node.innerHTML = renderState(state)`。
5. **イベントは delegation (data-action / data-frame-key)**
   `document.addEventListener('click', ...)` 1個で全 frame を捌く。ただし `select` の click は無視 (change で処理) — dropdown を即閉じさせないため。
6. **edges は SVG path bezier + ResizeObserver**
   `getBoundingClientRect` でアンカー計算、bezier curve で接続。リサイズに追従。
7. **既存プロジェクトの CSS トークンを取り込む**
   `src/styles.css` などから `:root` の CSS 変数 (`--bg`, `--accent`, `--font-sans`, etc) を抽出し、テンプレートの `@layer tokens` に注入。

## 実行手順

### 1. プロジェクトの状況把握 (recon フェーズ)

- `Glob '**/styles.css'` / `Glob '**/index.css'` / `Glob '**/globals.css'` などで CSS エントリを探す
- **ヒットあり** → 主要な CSS を Read してデザイントークン (`:root` の `--` 変数) を抽出
- **ヒットなし** (新規プロジェクト等) → テンプレ既定の `:root` トークンをそのまま採用する。出力 HTML の `@layer tokens` 直前に「<!-- project に styles.css がないためテンプレ既定値を流用。後で抽出して上書き -->」とコメントを残す。AskUserQuestion で「色だけ先に決めるか」確認は任意 (デフォルトはテンプレ既定で進める)
- 既存 view のレンダラ (例: `renderListView`, `renderDetailView`) があれば Read して画面構造を把握 (なければ skip)
- テンプレが使うトークン (`--surface-2`, `--ok`, `--err`, spacing/radius scale 等) が source CSS にない場合は、テンプレ既定値で補う (rule を消さない)

### 2. ユーザーから対象を聞く (AskUserQuestion)

- どの機能のモックを作るか (例: "settings", "auth flow", "checkout")
- 含めるモック種別 (overview / comparison / index、複数選択可)
- 出力先ディレクトリ (デフォルト: `docs/design-mockups/`)

### 3. 画面と遷移を対話で収集

- 画面リスト (例: List / Detail / Reading / Settings)
- 各画面の variants (例: filled / empty / loading / error)
- 遷移エッジ (from screen → to screen + label + trigger)
- viewport プリセット (デフォルトで標準セット — `README.md` の §2 「viewport プリセット」参照)

### 4. テンプレートを Read → 値を埋めて Write (authoring フェーズ)

skill 同梱ファイルへのアクセスは前述の通り絶対パス展開。

1. **必ず最初に** `templates/README.md` を Read。差し替えチェックリストと「触らない generic 基盤」の境界が書いてある。
2. `templates/overview.html` を Read (~400 行の骨格)。
3. README.md のチェックリストに従い、specific 箇所のみ差し替え:
   - `<title>` / `.stage-head h1`/`p` / `{{PROJECT_NAME}}` プレースホルダ
   - `:root` トークン (手順 1 で抽出した値で上書き)
   - `SAMPLE` 配列 (プロジェクトのドメインデータに置換)
   - **view 関数 (`genericCardView` / `genericDetailView`) を完全に置換**
     - プロジェクトの画面ごとに `renderHomeView` / `renderEditorView` / `renderHudView` 等
     - 元の view 関数の構造に引きずられない (eveng2-reader 過適合の主因)
   - `renderState()` の switch に kind を追加
   - `flowFrames` / `matrixScreens` / `flowEdges` をプロジェクトに合わせて再定義
   - `handleAction` の switch にプロジェクトの action を追加
4. `<project>/docs/design-mockups/<feature-name>-overview.html` に Write。
5. **comparison.html が必要なら** overview の generic 基盤 (CSS @layer / frame 構造) を流用しつつ、
   案ごとの違いを並列表示する HTML を **スクラッチで生成** (templates/comparison.html は存在しない)。
6. index.html を生成 (`templates/index.html` を base にプロジェクト名・リンク先だけ書き換え)。
7. **examples の参照は最終手段** — 参照する場合も view 関数の構造は絶対に流用しない (`examples/README.md` の過適合警告を参照)。

### 5. 動作確認

- `open docs/design-mockups/index.html` で Finder/ブラウザに表示
- 必要なら viewport を切替えて auto-layout が崩れないか確認

## 同梱ファイル (skill ディレクトリ基点・相対パス)

- `templates/README.md` — 差し替えチェックリスト (手順4で必ず Read)
- `templates/overview.html` — フロー俯瞰図 + States Matrix の骨格 (~400 行)
- `templates/index.html` — ハブページの骨格
- `examples/README.md` — ⚠️ 過適合警告 (流用 NG リスト)
- `examples/eveng2-reader-settings/` — 過去の生成例 (**模倣対象ではない**、generic 基盤の動作確認用)
- `README.md` — 詳細ガイド (viewport プリセット・Figma 対応表・dropdown 即閉じ対策など)

`templates/comparison.html` は削除済み (project 固有性が極端で骨格化困難なため)。

## 詳細ガイド

複雑な要件があるときは `README.md` を Read。以下を含む:
- viewport プリセットの実機マッピング (CSS px vs 物理 px)
- Figma との機能対応表 (Variants / Frames Matrix / Prototype)
- 状態遷移ルールの設計パターン
- エッジの side / offset 指定のコツ
- 既存プロジェクトのトークン抽出のテクニック
