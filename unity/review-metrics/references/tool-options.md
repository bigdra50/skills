# Tool Options Reference

## similarity-csharp

| Option | Default | Description |
|--------|---------|-------------|
| `-p, --paths` | null | 解析対象のファイル/ディレクトリ |
| `--threshold` | 0.87 | 類似度閾値 (0.0-1.0)。低いほど多くヒット |
| `--min-lines` | 5 | 解析対象の最小行数 |
| `--max-lines` | MAX | 解析対象の最大行数。巨大メソッドを除外する場合に使用 |
| `--min-tokens` | 0 | 解析対象の最小トークン数 |
| `--print` | off | メソッド詳細を出力 |
| `--print-all` | off | 重複グループ内の全メンバーを出力 |
| `--no-size-penalty` | off | サイズペナルティを無効化 |
| `--include-file-pattern` | null | ファイル名の正規表現フィルタ |
| `--include-method-pattern` | null | メソッド名の正規表現フィルタ |
| `-r, --rename-cost` | 0.3 | APTED アルゴリズムのリネームコスト |
| `-o, --output` | console | 結果のファイル出力先 |

### 閾値の目安

| 閾値 | 用途 |
|------|------|
| 0.90+ | ほぼコピペの検出 |
| 0.80-0.89 | 構造的に同一のパターン |
| 0.70-0.79 | 類似した処理フロー |
| 0.60-0.69 | 緩い類似（ノイズ多め） |

## jb inspectcode

| Option | Description |
|--------|-------------|
| `--no-build` | ビルドせずに解析（Unity必須） |
| `-s, --settings` | DotSettings ファイルパス |
| `--include` | 解析対象のワイルドカード |
| `--exclude` | 除外対象のワイルドカード |
| `-e, --severity` | 最小重要度: INFO, HINT, SUGGESTION, WARNING, ERROR |
| `-o, --output` | 出力ファイルパス（`-` で stdout） |
| `-f, --format` | 出力形式: Xml, Html, Text, Sarif |
| `--project` | 特定プロジェクトのみ解析 |

### SARIF 出力の jq パターン

```bash
# 件数
jq '.runs[0].results | length' results.sarif

# 一覧（ruleId + メッセージ + 場所）
jq '.runs[0].results[] | {ruleId, message: .message.text, uri: .locations[0].physicalLocation.artifactLocation.uri, line: .locations[0].physicalLocation.region.startLine}' results.sarif

# ruleId 別集計
jq '[.runs[0].results[].ruleId] | group_by(.) | map({rule: .[0], count: length}) | sort_by(-.count)' results.sarif

# 特定ルールのみ
jq '.runs[0].results[] | select(.ruleId == "RedundantUsingDirective")' results.sarif
```
