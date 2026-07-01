# チェックリスト

## anti-cargo-cult チェック (処方時)

処方を出す前に自問する。1 つでも No なら処方を直す:

- [ ] Intentionally omit のリストが空でないか? (全部 Create の処方は思考停止の兆候)
- [ ] 各 Create now に Owner と Validation が付いているか?
- [ ] 各 Defer に具体的な Trigger が付いているか? (「いずれ必要」は Trigger ではない)
- [ ] 空ディレクトリ・空テンプレート・TODO だけのファイルを生成していないか?
- [ ] Diátaxis の 4 分類を「先に箱として」作っていないか? (中身 2 本未満のカテゴリは作らない)
- [ ] S1〜S7 を成熟度として扱っていないか? (段階を上げること自体を目的にしていない)
- [ ] 段階を飛ばす提案をしていないか?
- [ ] community files (CONTRIBUTING/CoC/SECURITY/GOVERNANCE) を体裁のために置いていないか? (実際に機能する体制があるか)
- [ ] org 共通 .github repo で共有できるものを個別 repo に置いていないか?
- [ ] テンプレートのプレースホルダが実情報で埋まっているか? 埋まらない項目を削ったか?
- [ ] library と Web アプリの処方を取り違えていないか? (アプリに versioned docs / packages README を出していないか)

## 構成原則の検証 (適用後)

- [ ] 責務分離: 各ファイルの責務を 1 文で言えるか。2 文必要なら分割候補
- [ ] 正本一元化: 同じ情報が 2 箇所に書かれていないか。`rg` で主要な手順 (install / setup コマンド等) の重複を検査
- [ ] 読者軸: ファイル冒頭 or 配置から「誰向けか」が判別できるか
- [ ] README はハブとして機能するか (各読者が 1 クリックで自分の文書に着けるか)
- [ ] ポインタの先が存在するか (相対リンク切れゼロ)
- [ ] AGENTS.md のコマンド (setup/build/test) が実際に動くか
- [ ] 生成物の docs に「手編集禁止 + 生成元」の注記があるか

## 機械検証 (適用後に実行)

```bash
# 相対リンク切れ (docs_inventory.py の broken_links を確認)
python3 scripts/docs_inventory.py . | jq '.links.broken'

# 旧パス参照の残存 (restructure 時)
rg -n '<旧パス>' --type md

# secret / 内部 URL の混入 (.env.example, docs 全般)
rg -in '(password|secret|token|api[_-]?key)\s*[=:]\s*[^<\s]' docs/ *.md
```

提案してよい docs CI (恒久化の選択肢として提示。勝手に導入しない):

- リンク検査: lychee (CI) — n8n-docs / TanStack が実例
- prose lint: Vale + スタイル規定 — Grafana / n8n が実例
- spell check: typos / cspell
- コード例の同期: 言語の doctest 機構 > サンプル分離 + テスト実行 (fastapi docs_src/ 型) > リンク検査のみ
- per-PR docs プレビュー: Cloudflare Pages / Netlify (fastapi 型、無料枠で可)
- OpenAPI diff: oasdiff / openapi-diff (Web アプリの API docs 必須ゲート)

## 診断の解釈で迷ったら

- monorepo は repo 単位で 1 つの段階に潰さない。package 群と docs の関係 (極薄ポインタ型か、独立 docs か) を個別に見る
- docs/ という名前を信用しない (調査では: コントリビュータ専用 / 成果物置き場 / API ref 専用 / 空殻、の実例あり)。中身と読者で判定する
- 「docs が古い」の判定は最終更新日だけでなく、対応するコード・設定値との整合 (コマンド名、オプション、パス) を抜き取り検査する
- 機械検出した欠陥 (リンク切れ等) は「どのサブツリー由来か」で層別してから解釈する。vendored fork / generated / 内部メモ由来は一次 docs の欠陥と別カテゴリで集計する (スクリプトの broken_by_top を使う)
- 確信度が低い解釈は低いと明示し、ユーザーに確認する。推測で処方しない
