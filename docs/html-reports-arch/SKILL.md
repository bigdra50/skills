---
name: html-reports-arch
description: |
  html-reports の architecture レポート群をコードベース構造に対する写像として管理するスキル。
  分割統治パターンで偵察→動的タスク生成→Agent 委譲→統合→再計画→飽和判定を回し、
  特定言語/フレームワークに依存しないアーキテクチャ可視化を行う。
  ページは時系列ではなく構造に対応 (overview / module-* / flow-*)。
  Use when: "アーキ更新", "architecture refresh", "html-reports-arch",
            "アーキスナップショット", "コードベース図を更新", "コードベース可視化",
            "/arch-refresh", "loop /arch-refresh", "architecture 再生成",
            "ユースケース分析", "依存関係マップ"
---

# html-reports-arch

`html-reports` の `architecture` ページ群を「コードベースに対する写像」として管理する補助スキル。

## 設計思想

### 1. 時系列ではなく構造に基づく写像

architecture は他種別と異なり **日付 prefix を付けない**。
ファイル名はコードベース上の役割を直接表す:

```
.claude/reports/architectures/
├── overview.html              ← 全体像 (常設、必須)
├── module-<name>.html         ← 主要モジュール毎 (可変、コードベース依存)
├── flow-<name>.html           ← 横断ユースケース (可変)
└── _archived/                 ← 削除されたページ
```

更新時は既存ページを in-place 上書きする。

### 2. 分析手順は固定しない — 分割統治で動的に組み立てる

**重要原則**: コードベースは Unity だったり Next.js だったり Go monorepo だったりするので、
「asmdef を grep して...」のような固定チェックリストは持たない。

代わりに **orchestrator パターン**で動的に分析タスクを生成・委譲・統合・再計画する。
本スキルが明示するのは「メタな手順」(どう探索するか) であって、「具体的なコマンド」ではない。

## ページ種別と CLI

| slug 規則 | テンプレ | 用途 |
|-----------|---------|------|
| `overview` (固定) | `architecture-overview.html` | 全体像 (常設、必須) |
| `module-<name>` | `architecture-module.html` | 個別モジュール (内部構造 + Ports) |
| `flow-<name>` | `architecture-flow.html` | 横断ユースケース (シーケンス + コントラクト) |

```bash
mise run report:new -- architecture overview "コードベース全景"
mise run report:new -- architecture module-domain "Domain 層"
mise run report:new -- architecture flow-checkout "Checkout フロー"
```

ファイル名は日付 prefix なし。`new-report.sh` が slug prefix で page を自動判定し、
HEAD コミットハッシュを `<meta name="report:commit">` と `_index.js` の `commit_hash` に埋め込む。

## 可視化スタック (CDN ロード)

| ライブラリ | 用途 |
|-----------|------|
| Cytoscape.js + cytoscape-dagre | 依存グラフ (pan/zoom, クリック詳細, レイアウト切替) |
| ECharts | Treemap / Sankey |
| Mermaid | シーケンス図 |

テンプレ側は `<script id="arch-data" type="application/json">{...}</script>` と
コンテナ要素を提供。`_assets/arch-viz.js` が JSON を読んで描画。

**Claude は JSON データだけを埋める**。HTML 構造・CSS・JS は触らない。

## トリガー

自然言語: 「アーキ更新して」「architecture refresh」「html-reports-arch」「/arch-refresh」
定期実行: `/loop 1w /arch-refresh`

---

## 動作フロー (orchestrator パターン)

`orchestrator` スキルと同じ「計画→委譲→統合→再計画」のループを architecture 生成・更新に適用する。

### Phase 0: トリガー受付 + モード判定

```
.claude/skills/html-reports-arch/scripts/detect-changes.sh
```

出力の verdict で分岐:

| verdict | モード | 進む先 |
|---------|--------|--------|
| `INITIAL` | 初回作成 | Phase 1 → 2 → 3 → ... 全部 |
| `NO_CHANGE` | 変化なし | 何もしない (報告のみ) |
| `MINOR` | 軽微 (<10 files) | Phase 7.minor のみ (updated と commit_hash 更新) |
| `MODERATE` | 中程度 (10-49 files) | 影響モジュールを特定して Phase 3-7 をサブセット実行 |
| `MAJOR` | 大幅 (50+ files / 新規モジュール / 削除モジュール) | Phase 2 から再構成 |

### Phase 1: 偵察 (Reconnaissance) — 唯一の固定フェーズ

コードベース汎用の最小情報を集める。**言語/フレームワークに依存しない探索**だけを行う。

実行する偵察コマンドの種類 (具体的なコマンドはコードベース次第):

- 規模感: `git ls-files | wc -l`, `find . -maxdepth 3 -type d`
- ビルド境界 manifest: 環境にあるものを `fd` / `find`
  (例: `package.json`, `*.csproj`, `Cargo.toml`, `go.mod`, `pubspec.yaml`, `pom.xml`, `Gemfile`, `mix.exs`, `pyproject.toml`, `*.asmdef`, etc.)
- エントリポイント候補: `main.*`, `index.*`, `Program.cs`, `app.*`, `Bootstrap*`, `cmd/*/main.go`
- ドキュメント: `README*`, `ARCHITECTURE*`, `docs/`, `*ADR*`
- バージョン/ツール: `.tool-versions`, `mise.toml`, `package.json` の dependencies

偵察結果から内部的に把握すべきこと:

| 観点 | 何を判断するか |
|------|----------------|
| 言語 / フレームワーク | C# Unity / Next.js / Go / Python / Rust / 混在 |
| 規模 | ファイル数, トップレベルディレクトリ数 |
| ビルド境界 | asmdef / package / module の単位 |
| パラダイム | レイヤード / Clean / DDD / hexagonal / monorepo / microservice |
| 既存ドキュメント | どこに何が書いてあるか (重複分析を避けるため) |

**この phase 自体は subagent に出さない** (偵察結果は Phase 2 の判断に直結する起点なので、メイン Claude が握る)。

#### 1.x 既存の静的解析ツールを検出する (必須)

偵察の一環として、コードベースに **既に存在する静的解析ツール** を必ず検出する。
本スキルは特定ツールを要求しないが、**環境に既にあるものは Phase 3 で優先的に活用する**。

理由:
- 既存ツールは言語固有の依存関係を正確に抽出できる (grep より精度が高い)
- LOC / 複雑度 / 結合度などのメトリクスを取得済み
- JSON / SARIF / dot 等の機械可読出力 → arch-data に直接流し込める
- プロジェクト独自の規約 / 除外設定を既に反映している

検出する場所:

```bash
# 1. task ランナーに登録された解析タスク
mise tasks --no-header 2>/dev/null | grep -iE 'analy|inspect|metric|dep|graph|lint'
npm run 2>/dev/null | grep -iE 'analy|lint|check|dep'
make -qp 2>/dev/null | grep -E '^[a-z-]+:' | grep -iE 'analy|metric'

# 2. プロジェクト内の独自スクリプト
fd -t x . scripts/ tools/ bin/ 2>/dev/null | head -20

# 3. 言語ごとの典型ツール (manifest から検出)
#   package.json devDependencies / *.csproj PackageReference /
#   go.mod / Cargo.toml dev-dependencies / pyproject.toml

# 4. 利用可能な Claude Code skill 一覧から関連スキルを発見
#   (例: csharp-diagnose, quality-audit, unity-* 系)
```

検出した解析ツールを `tools_available` として内部的にメモし、Phase 3 のタスク生成で参照する。

#### CLI 存在 vs task wrapper 存在の分類 (重要)

検出時は **2 つを別カテゴリ**で記録する:

| カテゴリ | 例 | 扱い |
|----------|------|------|
| 1. **task wrapper として登録済** | `mise run analyze`, `npm run lint`, `make metrics` で起動できる | 第一選択。Phase 3 でそのまま Bash 経由で呼ぶ |
| 2. **CLI 単体は PATH にあるが wrapper 無し** | `unilyze` / `jb inspectcode` がインストール済だが `mise tasks` に未登録 | 第二選択。直接 CLI を Bash 呼びする。**同時に "tooling debt" として記録** |

カテゴリ 2 で発見した CLI は Phase 7 の生成物に反映する:

- overview ページの `notes` セクションに「Tooling debt: 以下の解析 CLI が手元にあるが mise タスクに登録されていない: `<list>`」と明示
- もしくは Phase 7 終了後にユーザーに別タスクとして提案: 「`unilyze` / `jb inspectcode` を `mise.toml` の `[tasks."analyze:*"]` に登録しますか?」

これにより「インストール済なのに毎回手で叩く」状況を可視化し、CI 化やドキュメント化の起点を提供する。

### Phase 2: 写像構成の決定 (Map Design)

偵察結果から、必要な architecture ページの構成を決める。

判断は **2 つの直交軸で別々に行う** (1 軸の単一表で束ねるとケース漏れが出るため):

#### 軸 1: `module-*` ページの数 (build boundaries 由来)

| build boundary 数 | `module-*` 構成 |
|-------------------|------------------|
| 1-2 | (`overview` に統合、独立 `module-*` 無し) |
| 3-7 (Layered) | 主要 boundary に 1 ページずつ (合計 3-7 件) |
| 8+ (大規模) | 重要度で 5-8 件に絞り、残りは `overview` 内のテーブルだけで触れる |
| DDD / Bounded Context | per Bounded Context (`module-<bc>`) |
| Microservice | per service (`module-<service>`) |
| Monorepo | per top-level package (`module-<package>`) |

#### 軸 2: `flow-*` ページの数 (cross-cutting use cases 由来)

| 3 モジュール以上を横断する主要 UC の数 | `flow-*` 構成 |
|-------------------------------------|---------------|
| 0-1 | (`overview` の「主要ユースケース」セクションに統合、独立 `flow-*` 無し) |
| 2-4 | 各 UC に 1 ページ (合計 2-4 件) |
| 5+ | 重要度上位 3-5 件に絞り、残りは将来 `architecture-usecases.html` 等の一覧ページに集約検討 |

**重要**: 軸 1 と軸 2 は **独立に判定する**。
例: 「5 modules + 2 cross-cutting UC」なら `module-*` 5 件 + `flow-*` 2 件 = `overview` + 7 子ページ。
逆に「8 modules でも cross-cutting UC が 1 件」なら flow ページは作らず overview 内のセクションで済ます。

**ユーザー確認**: 初回 + MAJOR モード時に必ず構成案を提示して承認を得る。

```
提案: 以下 N ページで構成します。
- overview            (全体像)
- module-domain      (... 責務サマリ)
- module-application (... 責務サマリ)
- flow-checkout      (主要ユースケース)

承認 / 修正 / その他?
```

#### ★ 完遂保証: `/goal` を発動してから Phase 3 へ

構成承認後、**Phase 3 開始前に `/goal` コマンドで完遂条件を設定する**。これにより以下が達成されるまで Claude が粘り強くターンを継続する。

```
/goal <条件文>
```

完遂条件テンプレート (構成に合わせて埋める):

```
/goal 以下が全て満たされている: (1) .claude/reports/architectures/ に
overview.html および計画した module-*.html / flow-*.html が全て存在する。
(2) 各 HTML の <script id="arch-data"> 内の nodes が overview なら 15 件以上、
module なら 10 件以上で、主要モジュールに responsibility と key_files が
埋まっている。 (3) _index.js の各 architecture エントリで scent.one_line /
scent.key_terms (3 件以上) / tags / related が補完されている。
(4) _index.js の各エントリの commit_hash が現在の HEAD と一致している。
```

`/goal` の動作:
- 各ターン終了後、Haiku 等の小型モデルが条件達成を yes/no 判定
- 未達ならメインモデル (Opus / Sonnet) で次ターン継続
- 達成で自動終了

これにより Phase 5 (再計画) の途中で「もう十分かな」と早めに切り上げる傾向を抑制し、**飽和まで本当に粘り強く回す**ことが担保される。

注意:
- 条件文は **Haiku が文章を読んで判定できる粒度** で書く (具体的すぎない数値羅列より、人間が読んで判定できる形)
- 4000 文字以内
- 途中でユーザーがキャンセルしたければ `/goal clear`
- 現在の goal を確認したければ引数なしで `/goal`

### Phase 3: 分析タスクの動的生成 (TaskCreate / TodoWrite)

決定した各 page に必要な分析を **動的にタスク化**する。
ハードコードしたチェックリストは使わず、偵察結果に応じて適切なタスクを組み立てる。

タスクの設計原則:

1. **1 タスク = 1 つの subagent で完結する単位**
2. **並列実行可能なものは同時に複数発行** (Agent ツールの並列呼び出し)
3. **言語固有の探索は Explore に委譲** (メイン Claude の context 節約)
4. **構造化された出力**を要求 (JSON 推奨、後で arch-data に流し込みやすい形)
5. **Phase 1.x で検出した `tools_available` を最優先**、無ければ grep / fd フォールバック
6. **環境にあるツールを暗黙的に活用**、無いものは要求しない (本スキルは特定ツール依存ゼロ)

#### ツール活用パターン (環境にあるものから選ぶ)

| 分析カテゴリ | ツール例 (環境にあれば) | 出力形式 | arch-data への流し込み |
|--------------|------------------------|---------|------------------------|
| LOC / ファイル数 | `tokei --output json` / `scc --format json` / `cloc --json` | JSON | nodes の `loc`, `files` |
| 依存関係 (.NET) | `jb inspectcode --format=Json` / `unilyze` / `dotnet list package --include-transitive` | JSON / SARIF | edges (kind=deps), modules |
| 依存関係 (JS/TS) | `madge --json` / `dependency-cruiser --output-type json` / `tsc --noEmit` | JSON | edges (kind=deps, impl) |
| 依存関係 (Go) | `go list -json -deps ./...` / `go-callvis -format json` | JSON | edges |
| 依存関係 (Rust) | `cargo modules generate tree --bin <name>` / `cargo metadata --format-version 1` | JSON / tree | edges |
| 依存関係 (Python) | `pydeps --show-deps --no-output` / `pyright --outputjson` | JSON | edges |
| AST 横断検索 (汎用) | `tree-sitter` / `ast-grep` / `semgrep --json` | JSON | nodes / edges / call sites |
| メトリクス / 複雑度 | プロジェクトの解析 task (`mise run analyze` 等) | 任意 | nodes の重み付け |
| Call graph | `go-callvis` / `pycallgraph` / `clang -emit-llvm` 系 | dot / JSON | edges (kind=data) |
| 既存スキル委譲 | `csharp-diagnose` / `quality-audit` / プロジェクト固有スキル | スキル依存 | nodes + modules |

#### ツール優先のフロー (推奨)

各分析タスクを subagent に出す前に、メイン Claude が以下の順で判断:

```
1. 同じ目的を達成する project-specific task はあるか?
     ├── あり → mise / npm script を Bash で実行、JSON を parse
     └── なし
2. 同じ目的の標準ツールが PATH にあるか?
     ├── あり → そのコマンドを Bash で実行
     └── なし
3. Claude Code skill で対応するものはあるか?
     ├── あり → Skill ツールでスキル発動
     └── なし
4. → subagent (Explore) に grep / fd ベースの探索を依頼
```

ツール出力 → arch-data 変換のためのプロンプト例:

```
Agent(
  subagent_type: "Explore",
  description: "tokei 出力を arch-data nodes に変換",
  prompt: "
    入力: $(tokei --output json src/) の出力 JSON。
    タスク: 各 top-level directory を 1 node として
            [{ id, label, layer, loc, files }] に変換。
            layer は heuristic で推定 (Domain / Application / ...)。
    出力: JSON 配列。
  "
)
```

#### ツール非依存原則 (再掲)

- ツールが**無くても本スキルは動く** (subagent + grep でフォールバック)
- ツールがあれば**より正確**になる、というだけ
- Phase 8 報告で「どのツールを使ったか」を必ず明示し、再現性を確保

タスクの種別 (例 = コードベース次第で増減):

| 種別 | 出すべき subagent | 期待出力 |
|------|-------------------|---------|
| 境界の LOC / file 数集計 | (簡易ならメイン Claude が直接 Bash) | `[{ id, files, loc }]` |
| 各境界内の public 型一覧 | Explore | `[{ id, label, kind, loc }]` |
| モジュール間の依存抽出 | Explore | `[{ from, to, kind }]` |
| 1 モジュールの責務サマリ | Explore (or Plan) | `responsibility` 文字列 |
| エントリポイントから N 階層下の呼び出し追跡 | Explore | call chain |
| ユースケース命名 (test ファイル名から) | Explore | `[{ name, files, description }]` |
| ユースケース実装パス追跡 | Explore | step-by-step (actor, target, action) |
| データ変換ポイント抽出 | Explore | `{ from_type, to_type, location }` |
| 用語抽出 (固有名詞) | Explore | `[{ term, definition_hint, location }]` |

TodoWrite で全タスクを可視化し、進捗をユーザーに見せる。

### Phase 4: 委譲実行 (Agent.parallel)

タスクを Agent ツールで実行。**独立タスクは 1 メッセージ内で複数並列**呼び出し。

```
Agent(
  subagent_type: "Explore",
  description: "Domain 層の型抽出",
  prompt: "
    タスク: <path>/Domain/ 配下の public 型を列挙。
    各型について: id (FQN), label, kind (class/interface/record/struct), loc, files。
    出力: JSON 配列 [{ id, label, kind, loc, files }]
    制約: 環境にある grep/fd で済む範囲。
  "
)
```

サブタスク入力テンプレ (orchestrator 流):
- タスク: 具体的に何を抽出するか
- スコープ: 対象パス / 除外
- 期待出力: フォーマット (JSON が望ましい)

サブタスク完了レポートを受けたら次のフェーズへ。

### Phase 5: 統合 + 再計画 (Re-plan Loop)

各タスクの完了レポートを集めて arch-data JSON を構築する。

**重要**: ここで止まらない。**不足を発見したら Phase 3 に戻り新タスクを動的生成**する。

再計画のトリガー例:

| 発見 | 動的生成する次タスク |
|------|---------------------|
| ある module の Port が想定より多い | その module の Port を全て列挙する Explore |
| ユースケース X の実装パスが追えない | callsite を 1 階層深く追跡する Explore |
| 用語集が薄い (3 件以下) | Domain 層の固有名詞をさらに掘る Explore |
| Treemap が偏っている (1 モジュールが極端に大) | その module 内をさらに細分化 |
| ユーザーが特定領域に関心を示した | その領域を集中分析する Explore |

これを **飽和** まで繰り返す。

### Phase 6: 飽和判定

以下を複数満たしたら「これ以上の深掘りは ROI が低い」と判断:

- 連続 2 ラウンドで新タスクが生成されない
- arch-data nodes が overview で 15-50、各 module で 20-40 に達した
- 主要モジュールに responsibility / key_files / ports / depends_on が埋まった
- 主要 flow ページの 8 セクション (Trigger / Outcome / Path / Matrix / Data / Error / Test / Call sites) が埋まった

飽和に達するか、ユーザーが明示的に「もう十分」と言ったら Phase 7 へ。

### Phase 7: ページ生成

各 page を順に:

1. `new-report.sh architecture <slug>` でスケルトン生成
   - 既存があれば上書きせず Edit で更新
2. `<script id="arch-data">` の JSON を Write で埋める (統合した分析結果)
3. 自然言語部 (TL;DR / 用語集 / オンボーディングルート / 規約) を Edit で書く
4. `_index.js` の対応エントリを補完
   - `scent.one_line`, `scent.key_terms`, `scent.reading_minutes`
   - `tags` (3-5 個)
   - `related` (同 architecture 内の他ページ + 関連 decision/review)
   - 旧ページ置換時は `supersedes: [旧 id]`
5. `<meta name="report:updated">` を今日に、`<meta name="report:commit">` を HEAD に
6. **アーカイブ / supersede 操作の整合性確認** (削除や置き換えを行ったときの必須ステップ):
   - architecture page を `_archived/` に移した、または `_index.js` から entry を削除した場合、
     直後に **必ず** 以下のチェックを実行する:
     ```bash
     rg -n "supersedes|統合|archived|削除|旧" .claude/reports/_index.js
     ```
   - ヒット行が **現実の entry / archive 状態と一致**しているか目視確認
   - 一致しないコメント (例: 「旧 X は新方式 Y に統合済み」と書いてあるのに Y が存在しない) は更新または削除
   - 同じく `rg "<archived-id>" .claude/reports/` で他ファイルからの参照漏れも確認

#### Phase 7.minor (差分軽微時のショートカット)

`detect-changes.sh` verdict が MINOR のとき:
- HTML 本体は触らない
- `_index.js` の `updated` と `commit_hash` のみ書き換え
- ユーザーには「軽微な変化のみ、本文更新は不要」と報告

### Phase 8: 報告

ユーザーに簡潔に:
- 実行した analysis ラウンド数
- 生成した分析タスク総数 (subagent / 直接 Bash / 既存スキルの内訳)
- **活用した既存解析ツール一覧** (`tools_available` のうち実際に使ったもの。例: `tokei` / `madge` / `csharp-diagnose` skill / プロジェクトの `mise run analyze`)
  - 使えなかった理由があれば明記 (例: `unilyze` インストール済だが出力フォーマットが想定外)
- 採用した分岐 (新規 / 部分更新 / 軽微更新)
- 生成・更新したページ一覧
- `_index.js` の `commit_hash` 更新

---

## HTML を書くときの必須ルール

### Mermaid を必ず描画させる

末尾の reports.js / arch-viz.js 読み込みは **必ず `type="module"` を付けない**:

```html
<!-- 正 -->
<script src="../_assets/reports.js"></script>
<script src="../_assets/arch-viz.js"></script>

<!-- 誤 (file:// で CORS 失敗) -->
<script type="module" src="../_assets/reports.js"></script>
```

### arch-data JSON 以外は触らない

`<script id="arch-data" type="application/json">` 以外の HTML 構造・CSS・JS は触らない。
テンプレを信頼する。これを破ると Cytoscape / ECharts 描画が壊れる。

### arch-data JSON のスキーマ

```json
{
  "metadata": { "title", "commit", "layers": [...] },
  "nodes": [
    {
      "id": "domain.scenario.ScenarioData",   // 階層 id (.区切り)
      "label": "ScenarioData",
      "layer": "domain",                       // 色分け用
      "lod": 2,                                // 表示される最小 LOD (0-3)
      "loc": 280, "files": 3,                  // Treemap / サイズ計算
      "url": "module-domain.html",             // dbl-click 遷移先
      "parent": "domain.scenario",             // Cytoscape compound node
      "kind": "record"                         // shape 切替: class/interface/port/record/external
    }
  ],
  "edges": [
    {
      "from": "...", "to": "...",
      "kind": "deps|impl|data|domain",         // 線色・スタイル切替
      "lod": 1,
      "label": "string"                        // edge label
    }
  ],
  "modules": {
    "<node_id>": {
      "responsibility": "...",
      "key_files": [...], "ports": [...], "depends_on": [...],
      "related_reports": [{ path, title }]
    }
  }
}
```

### LOD の使い方

| LOD | 含めるノード | 典型ノード数 |
|-----|--------------|---------------|
| 0 | レイヤー (粗粒) | 3-7 |
| 1 | 主要モジュール | 10-25 |
| 2 | モジュール内の型 / コンポーネント | 30-60 |
| 3 | クラスメソッド / ファイル | 100+ (任意) |

`lod` フィールドは「このノードが表示される最小 LOD」。
L1 を見ているとき、L0/L1 ノードは表示、L2/L3 は非表示。

各モジュールのデータを arch-data に **明示的に階層展開** することで LOD slider が意味を持つ。
階層展開しない場合は L1=L2 になって slider の意味がなくなる (アンチパターン)。

### flow ページの 8 セクション

flow ページは以下を埋めることで「ユースケース分析」を漏れなく表現する:

1. Trigger Contract (起動条件 / 入力 / 認可)
2. Outcome Contract (成功時の状態変化 / 副作用 / 出力)
3. Implementation Path (UI → UseCase → Domain → Repo → DB のクラスチェーン)
4. Module Participation Matrix (モジュール × R/W/Notify)
5. Data Transformation (型変換: DTO → Domain → Persistence)
6. Error Landscape (失敗ポイント / 影響範囲 / 補償)
7. Test Coverage (既存テストの場所 + 何を保証するか)
8. Real Call Sites (file:line の実呼出箇所)

このうち何を埋められるかは Phase 3 の動的タスクで決まる。
Mermaid シーケンスだけで終わらせない。

---

## 失敗・例外

- `.claude/reports/` がない: `html-reports` の init を促す
- git リポジトリでない: 警告のみで処理続行 (commit_hash 不要)
- 既存 commit_hash が無効 (force-push 等): `HEAD~50` を基点
- `detect-changes.sh` が NO_CHANGE: 「変化なし、更新不要」と報告して終了
- Cytoscape / ECharts CDN ロード失敗: HTML 内に赤字エラー表示 (`arch-viz.js` が自動)

## 関連スキル

- `html-reports`: 本体スキル。architecture テンプレと `new-report.sh` を提供。
- `orchestrator`: 分割統治パターンの原型。本スキルは architecture 専用にカスタマイズ。
- `loop`: 定期実行する場合に組み合わせる (`/loop 1w /arch-refresh`)。
