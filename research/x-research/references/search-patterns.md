# X Research クエリパターン集

## 基本構文

| パターン | 説明 | 例 |
|---------|------|-----|
| `site:x.com` | X.comに限定 | `site:x.com react` |
| `"完全一致"` | フレーズ検索 | `site:x.com "claude code"` |
| `OR` | いずれかを含む | `site:x.com (error OR bug)` |
| `-除外` | 特定語を除外 | `site:x.com react -native` |

## トピック別テンプレート

### 技術・ツール調査

```
site:x.com "{ツール名}" "{機能名}"
site:x.com {ツール名} {機能名} tips
site:x.com {ツール名} {機能名} 設定
site:x.com {tool_name} {feature_name} config
```

### バグ・問題調査

```
site:x.com "{ツール名}" (bug OR issue OR error)
site:x.com "{ツール名}" "{エラーメッセージの一部}"
site:x.com {ツール名} 動かない
site:x.com {ツール名} broken
```

### ユーザーの声・評判

```
site:x.com "{製品名}" (使ってみた OR 試した)
site:x.com "{製品名}" (良い OR 悪い OR 微妙)
site:x.com "{product_name}" (review OR thoughts OR experience)
```

### 比較調査

```
site:x.com "{製品A}" "{製品B}" (比較 OR vs)
site:x.com "{製品A}" OR "{製品B}" 乗り換え
site:x.com "{productA}" vs "{productB}"
```

### 設定・Tips

```
site:x.com "{ツール名}" (設定 OR config OR tips)
site:x.com "{ツール名}" おすすめ 設定
site:x.com "{tool_name}" workflow
site:x.com "{tool_name}" productivity
```

### 特定ユーザーの投稿

```
site:x.com from:{username} {キーワード}
site:x.com "@{username}" {キーワード}
```

## 日本語・英語の使い分け

| 目的 | 言語 | 理由 |
|-----|------|------|
| 日本人ユーザーの声 | 日本語 | 日本語圏のリアルな反応 |
| 技術的詳細 | 英語 | 開発者の一次情報が多い |
| 公式情報 | 英語 | 公式アカウントは英語が多い |
| Advent Calendar等 | 日本語 | 日本特有の文化 |

## 効果的な検索のコツ

1. **並列検索**: 複数のクエリを同時に実行して網羅性を確保
2. **段階的絞り込み**: 広いクエリ → 狭いクエリの順で実行
3. **外部リンク優先**: ツイート内で言及されたブログ・記事を優先的に取得
4. **日付指定**: 最新情報が必要な場合は年を含める（例: `2025`）

## 注意事項

- `site:twitter.com` より `site:x.com` を使う（インデックスの関係）
- 画像内テキストは検索できない
- 削除済みツイートはインデックスに残っている場合がある
