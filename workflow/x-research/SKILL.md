---
name: x-research
description: X(Twitter)からWeb検索経由で情報収集を行うスキル。site:x.com検索でツイートを取得し、関連ブログ記事があればWebFetchで詳細を取得する。API不要・無料で即座に利用可能。特定トピックのトレンド調査、ユーザーの声収集、技術情報の収集に使用する。
---

# X Research

X(Twitter)からWeb検索経由で情報を収集する。公式APIを使わず、`site:x.com`検索で公開ツイートを取得する手法。

## 制約事項

- リアルタイム性なし（検索エンジンのインデックス遅延）
- スレッド全体・リプライ・引用RTは取得しにくい
- 画像・動画の内容は直接取得不可
- エンゲージメント数（いいね・RT）は不明

## ワークフロー

### Phase 1: 初期検索

複数のクエリバリエーションで並列検索を実行する。

```
基本パターン:
  site:x.com "キーワード1" "キーワード2"
  site:x.com キーワード1 キーワード2 関連語

日本語検索:
  site:x.com キーワード 日本語関連語

英語検索:
  site:x.com keyword1 keyword2
```

**注意**: `site:twitter.com`は結果が少ない。Xへのリブランド後、インデックスは`x.com`に移行している。

### Phase 2: 結果の分析

検索結果から以下を抽出する：

1. **ツイートURL**: `x.com/{username}/status/{id}` 形式
2. **投稿者**: @ハンドル名
3. **要約**: 検索結果に含まれるツイート本文の抜粋
4. **外部リンク**: ブログ記事、GitHub Issue、ドキュメントへのリンク

### Phase 3: 詳細情報の取得

ツイートが外部コンテンツを参照している場合、WebFetchで取得する。

```
優先度:
  1. Zenn/Qiita/dev.to などの技術ブログ
  2. GitHub Issues/Discussions
  3. 公式ドキュメント
  4. 個人ブログ
```

**X/Twitterページ直接取得の制限**: `WebFetch`でX.comのツイートページを直接取得しても、認証要求でブロックされる。関連ブログ記事経由で詳細を取得するアプローチを優先する。

### Phase 4: 結果の整理

収集した情報を以下の形式で整理する：

```markdown
## [トピック名] に関するX調査結果

### 主要な発見

- [@username](URL): "ツイート要約"
- [@username](URL): "ツイート要約"

### 詳細情報（外部ソース）

- [記事タイトル](URL): 内容の要約

### 制限事項

- 画像内容は未取得
- [その他の制限]
```

## クエリパターン集

詳細なクエリパターンは `references/search-patterns.md` を参照。

## 使用例

**入力**: "Claude Codeのauto compactについてXで調べて"

**実行手順**:
1. `site:x.com "claude code" "auto compact"` で検索
2. `site:x.com claude code compaction context window` で補完検索
3. 発見したZenn記事をWebFetchで取得
4. 結果をまとめて報告
