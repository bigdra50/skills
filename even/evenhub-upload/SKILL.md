---
name: evenhub-upload
description: >-
  Even Hub (hub.evenrealities.com) の Even Realities G2 アプリに、pack 済み .ehpk ビルドを
  アップロード (Add build) する個人スキル。公式 evenhub CLI に upload コマンドが無いため、Web UI と
  同等の非公式 API (POST /api/v1/versions/draft → /api/v1/versions/create) を直接呼ぶ。追加される
  ビルドは Private (公開=Private→Public 切替は別操作で、本スキルは行わない)。
  Use when 「Even Hub にアップロード」「ビルドをアップロード」「Add build」「ehpk を上げる/上げて」
  「ハブに上げて」「(Even G2 の) ビルドを公開準備」「upload to even hub」「add build to even hub」
  と言われたとき、または Even Realities G2 / Even Hub アプリの .ehpk をハブに登録したいとき。
  公式 everything-evenhub プラグインとは別の、個人用の補完スキル。
---

# Even Hub build upload (Add build)

`hub.evenrealities.com` の自分のアプリへ `.ehpk` を **Add build** するスキル。
公式 `evenhub` CLI は `login / init / pack / qr` のみで **upload が無い**ため、Web UI が叩く API を再現する。

このスキル同梱の `upload.mjs` が本体。プロジェクト固有の編集は不要 (app.json の `package_id` と cwd の `*.ehpk` を自動検出)。

## 前提

1. **一度だけ** 自分のターミナル (TTY) で `evenhub login` 済みであること。
   - 対話プロンプト (email→password) のため、`!` シェルや非 TTY では実行できない。未ログインなら、ユーザー自身に実行してもらう。
   - トークンは `~/.config/evenhub/credentials.yaml` に保存され、**アカウント単位**なので全プロジェクトで共有される。
2. アップロードするアプリが Even Hub に登録済みであること (`package_id` 一致)。
3. `.ehpk` が pack 済みであること (無ければ先に `npm run pack` 等)。

## ワークフロー

1. 未ログインなら、ユーザーに自分のターミナルで `evenhub login` を依頼 (こちらでは代行しない=パスワードを扱わない)。
2. `.ehpk` が無ければ pack する (例: `npm run pack`、または `evenhub pack app.json dist -o <name>.ehpk`)。
3. **Add build はサーバーへビルドを追加する操作なので、実行前にユーザーへ確認する** (changelog 文面も確認)。
4. プロジェクトルート (app.json と .ehpk がある場所) で実行:
   ```bash
   node ~/.claude/skills/evenhub-upload/upload.mjs -m "<changelog>"
   ```
   - 検証だけしたいとき (ビルドは追加しない): `--draft-only`
   - `.ehpk` 名や package を明示: `--file <name>.ehpk` / `--package <id>`
5. 成功すると応答に `version` / `is_private:true` / `file_size` 等が返る。ハブの Builds 一覧に Private で出る。

> **公開しない**: このスキルは Private 追加までしか行わない。公開 (Private→Public) はハブ UI で切り替えてもらう。

## 仕組み (API)

| 手順 | 通信 |
| --- | --- |
| ① ファイル選択相当 | `POST /api/v1/versions/draft?package_id=<pkg>`  FormData `ehpk`=.ehpk → `draft_id` |
| ② Add build 相当 | `POST /api/v1/versions/create?package_id=<pkg>` FormData `draft_id` + `changelog`(最大500字) |

- 認証ヘッダ: `X-Even-Authorization: <access_token>` (Bearer 接頭辞なし)。
- `access_token` は約10分で失効 → 401 時に `refresh_token` で自動更新し credentials.yaml に書き戻す (refresh_token は約7日)。
- レスポンスは `{code, message, data}` 包み。`code===0` が成功。

## プロジェクトへの常設 (任意)

毎回フルパスを打つ代わりに、各プロジェクトで `npm run upload` 化してもよい:

```jsonc
// package.json
"scripts": {
  "upload": "node ~/.claude/skills/evenhub-upload/upload.mjs"
}
```

## 注意 / トラブルシュート

- `認証情報が読めません` / 401 が続く: ユーザーに `evenhub login` 再実行を依頼。
- `カレントに .ehpk が見つかりません`: 先に pack。
- トークン値・パスワードは表示しない。credentials.yaml の中身を出力しない。
- 非公式 API のため、ハブ側仕様変更で壊れる可能性あり。壊れたら Web UI の「Upload a build → Add build」時の通信 (Network パネル) を再確認し、エンドポイント/フィールドを更新する。
