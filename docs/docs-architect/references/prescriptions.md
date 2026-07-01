# プロジェクト種別ごとの処方箋

処方は必ず 3 分類 (Create now / Defer until trigger / Intentionally omit) で出力する。
ここのリストは出発点であり、診断結果 (読者構成・運営体制) で増減させる。
「Defer」「Omit」を空にしない — 全部 Create になる処方は cargo-cult の兆候。

## 全種別共通の Phase 0 (init モードの基準)

Create now:

| ファイル | Owner | Validation |
|---|---|---|
| README.md | メンテナ | standard-readme 順序 (下記) に準拠。リンク切れ検査 |
| LICENSE | メンテナ | — (選定はユーザーに確認。業務 repo では Omit) |
| AGENTS.md | メンテナ | setup/build/test コマンドが実際に動くこと |
| CLAUDE.md | — | `@AGENTS.md` 1 行のみ (内容を持たせない) |
| .github/ISSUE_TEMPLATE/ (bug + feature) | メンテナ | config.yml で blank 無効化、質問は Discussions へ誘導 |
| .gitignore (言語標準) | メンテナ | ビルド・テスト副産物が untracked に現れないこと |

README のセクション順序 (standard-readme 準拠):
Title → Badges → 短い説明 (120 字以内) → ToC (100 行未満なら省略) → Background (任意) → Install → Usage → Contributing → License (必ず最後)。

owner・repo URL・著作権者など identity 系の値の導出規律 (init で remote 未設定のとき):
remote > リポジトリの namespace パス > git config の優先順で導出し、「推定値・初回 push 後に要確認」としてユーザーへの報告に明示する。プレースホルダのまま残さない。

Defer until trigger:

| ファイル | Trigger |
|---|---|
| CHANGELOG.md | 外部利用者がリリース差分を追い始めたら。それまで GitHub Releases で代替 |
| GUIDE.md / FAQ.md | README が ~20KB を超えたら (S1→S2) |
| CONTRIBUTING.md | 外部 PR が実際に来始めたら。最初は README の Contributing 節で足りる |
| docs/ ディレクトリ | トピック分割・学習順序が必要になったら (S2→S3) |
| RELEASE-CHECKLIST.md | リリース手順が 3 ステップを超えたら (属人化防止) |
| SECURITY.md | 脆弱性が成立する攻撃面を持ったら / org ポリシーが要求したら |

Intentionally omit (理由付き):

| ファイル | 理由 / 代替 |
|---|---|
| CODE_OF_CONDUCT.md | コミュニティが形成されるまで機能しない。org 共通 .github repo があればそちらに委譲 |
| GOVERNANCE.md | 個人運営では無意味。複数メンテナ体制になったら Defer に昇格 |
| 空の docs/tutorials/ 等 Diátaxis 箱 | 公式が禁じるアンチパターン。中身が 2 本以上溜まってから分類する |
| wiki | 正本が分散する。docs/ に一元化 |

メモ: GitHub community health files は org/個人の `.github` リポジトリで default 共有できる (README / LICENSE を除く)。複数 repo を持つなら個別配置せず共有を提案する。

## library (npm / crates / PyPI パッケージ)

共通 Phase 0 に加えて:

- Create now: API ドキュメントの置き場方針 (README 内 `## API` 節から開始。肥大化したら分割)
- Defer: docs サイト (S4) — 検索 / i18n / versioning の要求が出たら。ジェネレータ選定は stages.md
- Defer: migration-guides/ — メジャーバージョン更新 or 競合からの乗り換え需要が出たら (got 型)
- monorepo の packages/*/README.md は「1-3 文 + 正本へのリンク」の極薄ポインタに統一 (pdfme 型)。厚い per-package README は二重メンテ
- Rust / Go は言語インフラ (docs.rs / pkg.go.dev / doctest) を前提に、手書き API ref を Omit にする

## CLI ツール

共通 Phase 0 に加えて:

- Create now: `--help` 出力と README の同期方針 (可能ならヘルプをコードから生成、またはスナップショットを repo に保存して diff 検査)
- Defer: GUIDE.md (チュートリアル) / FAQ.md — README 肥大化時 (ripgrep 型分割)
- Defer: man ページ — パッケージマネージャ配布を始めたら。手書きよりフラグ定義からの生成を優先
- Omit: docs サイト — 個人メンテ CLI は S2 で十分機能する (ripgrep 65k★ が実証)

## Web アプリ / SaaS (フルスタック)

ライブラリと質的に異なる。operator (運用者) が読者に加わる前提で処方する。

Create now (共通 Phase 0 に追加):

| 項目 | Owner | Validation |
|---|---|---|
| docker-compose.yml + .devcontainer/ | 開発チーム | 新メンバーが 1 コマンドで起動できること |
| .env.example | 開発チーム | 設定契約の文書化。実値を含まない (secret 検査) |
| docs/ と contribute/ の 2 ツリー分離 (Grafana 型) | 各チーム | 利用者向けと開発者向けが混在しないこと |
| API ドキュメント生成パイプライン | 開発チーム | OpenAPI をコードから生成 + oasdiff/openapi-diff を CI ゲート化 |

API ドキュメント生成の選択 (転用順位):

1. フレームワークに swagger 機構があるなら注釈駆動 (NestJS デコレータ → openapi.json コミット。Cal.com 型)
2. エンドポイント多数なら fragment-and-bundle (paths/ + components/ → bundle + diff CI。Sentry 型)
3. schema-first 設計なら spec 正本 (OpenAPI yaml からコード例・パラメータ表を docs に注入。Zulip 型)

Defer until trigger:

| 項目 | Trigger |
|---|---|
| デプロイ先別ページ (deployment matrix) | セルフホスト先 / デプロイ先が 2 つを超えたら 1 先 1 ページに分割 (Cal.com / Metabase 型) |
| upgrade-guide/upgrade-vX.Y/ (版別凍結) | 破壊的変更を含むリリースが出たら (Grafana 型。versioned docs サイトは作らない) |
| 開発環境の専用 CLI (devenv / GDK 型) | 依存サービスが増え docker-compose では診断 (doctor) が必要になったら |
| troubleshooting/ + errorCodes/ | サポート問い合わせの再発パターンが見えたら (Supabase 型) |

Intentionally omit:

- packages/*/README (npm 配布しないなら不要)
- versioned docs サイト — product docs は単一最新。版の概念は upgrade-guide 側へ
- 詳細な install 散文 — デプロイ成果物 (compose / Helm / install.sh) が文書を兼ねる (Mastodon 型 deployment-by-artifact)

## 業務システム (社内 / クローズド)

Web アプリの処方をベースに、OSS には無い 5 系統を追加する。

Create now:

| 項目 | Owner | Validation |
|---|---|---|
| docs/adr/NNNN-*.md (連番 ADR) | 設計判断をした人 | Status 遷移 (proposed/accepted/superseded)。削除せず履歴保持 |
| ONBOARDING.md | チーム | 新メンバーが初日に環境構築〜初コミットを完了できること |
| 権限対応表 (PERMISSIONS.md: 権限 → 実装 file:line) | 開発チーム | 認可実装とのトレーサビリティ (Cal.com 型) |

Defer until trigger:

| 項目 | Trigger |
|---|---|
| runbooks/ (アラート別対応手順) | 本番運用 / on-call が始まったら |
| postmortems/ + テンプレート | 最初のインシデントが起きる前に (blameless、Google SRE 型) |
| docs/architecture/ (arc42 or C4) + SLO 定義 | 監査・引き継ぎ・キャパシティ計画が要求されたら |
| threat-model (STRIDE + DFD) | 外部公開面 / 個人情報を扱い始めたら |
| catalog-info.yaml 相当 (所有者・依存メタ) | repo が複数になり発見性が問題になったら (Backstage TechDocs 型) |
| docs/schema/ (ER・データ辞書 + PII フラグ) | DB スキーマが安定したら。dbdocs / SchemaSpy / dbt docs で半自動生成 |

Intentionally omit:

- LICENSE / CODE_OF_CONDUCT / FUNDING — 社内 repo に不要
- フィーチャー単位の設計記録が合うチームは docs/adr/ の代わりに specs/{feature}/ (design.md + decisions.md + future-work.md、Cal.com 型) を選んでよい (両方は持たない — 正本一元化)

## AI エージェント向けファイル (全種別共通、2026 標準)

- AGENTS.md を正本にする (setup / build / test / 規約 / アーキテクチャ要点)
- CLAUDE.md は `@AGENTS.md` の 1 行 import (vitest 型)。symlink (pdfme 型) でも可だが import が最も明示的
- 既存の CLAUDE.md に実内容がある repo では、内容を AGENTS.md へ移して import に置換する提案をする (ユーザー確認必須)
- llms.txt は公開 docs サイトを持つ場合のみ Defer (サイト公開時に static/ へ)
- AI_POLICY.md (AI 生成貢献を受けるかのポリシー) は外部貢献を受ける OSS のみ Defer。AGENTS.md とは役割が別物
