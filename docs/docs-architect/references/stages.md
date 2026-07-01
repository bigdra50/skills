# S1〜S7: ドキュメント配置の配信トポロジー

7 段階は「成熟度ランキング」ではなく配信トポロジーの選択肢。
上の段階ほど良いわけではない。決定因子は star 数ではなく以下の 3 つ:

1. 機能複雑度 — 説明すべき概念の数 (chalk=README 12KB、ky=62KB は機能数の差)
2. 読者の種類 — 非開発者 (運用者・エンドユーザー) を含むか。含むと小規模でもサイト分離が必須化
3. 運営体制 — 個人 / org / 企業 / 財団。ガバナンス文書の要否を決める

## 段階定義と移行トリガー

| 段階 | 構成 | 代表例 | 次へ移行するトリガー |
|---|---|---|---|
| S1 | README 完結 | chalk (12KB), ky (62KB) | README が「入口」として機能しなくなる肥大化 (~20KB 目安、ただしテーマが単一なら 60KB でも維持可) |
| S2 | README + ルート MD 分割 (GUIDE/FAQ 等) | ripgrep (GUIDE 41KB + FAQ 42KB), fzf 本体 | 学習順序・トピック分割・体系的ナビが必要になる |
| S3 | README ハブ + in-repo docs/ (ジェネレータなし) | got (番号付き documentation/), commander | 検索・i18n・versioning のいずれかが必要になる |
| S4 | in-repo docs サイト (ジェネレータあり) | pdfme, vitest, trpc, fastapi, django | org 横断のサイト共有 / docs とコードのレビューフロー分離が必要になる |
| S5 | コンテンツ同梱 + レンダラー外出し | TanStack Query, svelte, next.js | docs の貢献者・所有者がコードと完全に分かれる |
| S6 | docs 完全別 repo | hono, react (react.dev), kubernetes/website | 読者層が複数あり各層が巨大 |
| S7 | 完全外部分散 (複数ドメイン/Wiki/自動生成) | blender (3 ドメイン), golang | — |

逆方向の移行もある: Discourse は別 repo だった developer-docs を core に併合した (docs とコードの共進化を優先)。

移行ルールの方向別の扱い:

- 上り (S↑): 隣接段階のみ。移行トリガーが実際に成立しているときだけ提案する
- 下り (S↓): 段階スキップ可 (例: 劣化した S3 を S1 に畳む)。ただし複数段下げる提案は「内容が現段階を支えていない」根拠を示し、承認ポイントとして明示する

## 段階を上げないという判断

- ripgrep (65k★) は S2 を維持。個人メンテで docs サイトの保守コストを払わない判断
- 番号プレフィックス (got の 1-promise.md、next.js の 01-app/) はジェネレータなしで学習順序・IA を表現する技法。S3→S4 の移行を遅延できる
- 早すぎる段階移行はコストだけ払う。移行トリガーが実際に発生してから動く

## S4 でのジェネレータ選定

| 条件 | 選択 |
|---|---|
| TS lib、軽さ優先 | VitePress (ビルトイン検索、単一バージョン) |
| versioning 必須 (複数メジャー並走) | Docusaurus (versioned_docs。ただし 10 版未満 + weeding 前提) |
| Python | MkDocs Material (+ mkdocstrings) または Sphinx (伝統・RTD 連携) |
| Rust | mdBook (+ docs.rs が API ref を自動ホスト) |
| 外部 SaaS (Algolia 等) を避けたい | Starlight (Pagefind) / mdBook (elasticlunr) / VitePress (minisearch) |
| book 型の通読教材 | mdBook (SUMMARY.md 単一目次) |

## versioning / i18n の導入閾値

- versioning: 複数メジャーバージョンが現役で並走し、旧版利用者が docs で迷子になり始めたら。それまで単一最新
  - 第一候補は Read the Docs ブランチ方式 (維持コスト低)。版間分岐が激しい場合のみ snapshot 方式 (Docusaurus)
  - Web アプリでは versioned docs でなく「版別 upgrade-guide ディレクトリ」(Grafana upgrade-vX.Y/) に読み替える
- i18n: 原文が安定し、翻訳の担い手 (コミュニティ or LLM パイプライン) が現れたら。原文流動期の導入は陳腐化負債のみ生む
  - 個人規模の最小解は「翻訳 README 並置」(bat の doc/README-ja.md)
  - 本格導入時は UI 文字列と本文の分離 + 陳腐化検出 (原文差分の機械検出 or LLM 再翻訳) をセットで設計

## 言語エコシステムの差し引き

処方の前に「言語インフラが何を肩代わりするか」を差し引く:

- Rust: docs.rs が publish 時に API ref を自動ホスト、doctest で例=テスト → repo 側の docs 責務が小さい
- Go: pkg.go.dev が同様。Testable Examples が doctest 相当
- JS/TS, Python: 肩代わりなし → repo 内に docs サイトと CI を抱える前提で処方する
- Web アプリの HTTP API: どの言語でもエコシステムに乗らない → OpenAPI 生成 + diff CI を自前で持つ (prescriptions.md 参照)
