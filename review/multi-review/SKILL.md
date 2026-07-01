---
name: multi-review
description: >-
  Language-agnostic multi-tool code review. Dispatches Claude, Codex, or Copilot
  in parallel across 4 perspectives (security, performance, maintainability,
  architecture). For Unity/C# projects, prefer the unity-review system instead —
  it uses unilyze metrics and Unity-specific judgment criteria.
---

# Multi-Tool Multi-Perspective Review

4つの観点を並列実行し、統合レポートを生成。
`--tool` で実行エンジンを切り替える。

## Usage

```
/multi-review <target>
/multi-review --tool claude src/auth/
/multi-review --tool codex src/
/multi-review --tool copilot src/
/multi-review --tool copilot --models diverse --effort high src/
```

## Argument Parsing

1. `--tool <claude|codex|copilot>` を抽出（省略時: claude）
2. `--models <value>` を抽出（copilot専用、後述）
3. `--effort <level>` を抽出（copilot専用、省略時はフラグなし）
4. 残りの引数をターゲットパスとして使用

## CLI Existence Check

codex / copilot 選択時、実行前に存在確認する。
不在なら claude にフォールバックし、その旨をレポートに記載。

```bash
command -v codex   # --tool codex 時
command -v copilot # --tool copilot 時
```

## Tool-Specific Execution

### claude (default)

Task toolで4つの**Explore agent**を並列起動:

```
Task(subagent_type="Explore", prompt="[Security Review] <target>...")
Task(subagent_type="Explore", prompt="[Performance Review] <target>...")
Task(subagent_type="Explore", prompt="[Maintainability Review] <target>...")
Task(subagent_type="Explore", prompt="[Architecture Review] <target>...")
```

### codex

Bash toolで4つの`codex exec`を `run_in_background: true` で並列起動:

```bash
cd <target_dir> && codex exec "[Security Review] ..." --sandbox read-only 2>/dev/null
cd <target_dir> && codex exec "[Performance Review] ..." --sandbox read-only 2>/dev/null
cd <target_dir> && codex exec "[Maintainability Review] ..." --sandbox read-only 2>/dev/null
cd <target_dir> && codex exec "[Architecture Review] ..." --sandbox read-only 2>/dev/null
```

TaskOutputで全タスクの完了を待機（`timeout: 600000`, `block: true`）。

### copilot

Bash toolで4つの`copilot -p`を `run_in_background: true` で並列起動:

```bash
cd <target_dir> && copilot -p "[Security Review] ..." --model <security_model> [--effort <level>] --no-ask-user 2>/dev/null
cd <target_dir> && copilot -p "[Performance Review] ..." --model <perf_model> [--effort <level>] --no-ask-user 2>/dev/null
cd <target_dir> && copilot -p "[Maintainability Review] ..." --model <maint_model> [--effort <level>] --no-ask-user 2>/dev/null
cd <target_dir> && copilot -p "[Architecture Review] ..." --model <arch_model> [--effort <level>] --no-ask-user 2>/dev/null
```

TaskOutputで全タスクの完了を待機（`timeout: 600000`, `block: true`）。

## Copilot Model Mapping

### Default (GPT-5.4 メイン)

| 観点 | モデル | 理由 |
|------|--------|------|
| Security | gpt-5.4 | 最新GPT、論理推論・パターン認識 |
| Performance | gpt-5.4 | コード最適化・計算量分析 |
| Maintainability | gpt-5.4 | 構造分析・一貫性検出 |
| Architecture | claude-opus-4.6 | 深い設計判断、別視点の確保 |

### --models による上書き

カンマ区切りで4モデルを指定（順序: Security, Performance, Maintainability, Architecture）:

```
--models gpt-5,gpt-5,gemini-3.1-pro,claude-opus-4.6
```

プリセット:
- `--models all-gpt` → 全観点 gpt-5.4
- `--models diverse` → gpt-5.4, claude-opus-4.6, gpt-5.4, claude-sonnet-4.6
- `--models all-claude` → 全観点 claude-opus-4.6

## Review Prompts (共通)

4つのプロンプトは全ツール共通。`<target>` 部分を実際のターゲットに置換する。

**Security:**
```
[Security Review] <target>を以下の観点でレビュー:
- 機密情報の露出リスク（APIキー、認証情報等）
- SQLインジェクション、XSS、CSRF等の脆弱性
- 認証・認可の問題
- 入力検証の不備
具体的なファイル:行番号と修正案を提示。
```

**Performance:**
```
[Performance Review] <target>を以下の観点でレビュー:
- N+1クエリ、不要なループ、毎フレーム処理の最適化機会
- メモリリーク、リソース解放漏れ
- キャッシュ活用・GC Alloc削減の機会
- 計算量・アルゴリズム効率
具体的なファイル:行番号と改善案を提示。
```

**Maintainability:**
```
[Maintainability Review] <target>を以下の観点でレビュー:
- コードの可読性、複雑度
- 重複コード、DRY原則違反
- 命名規則、一貫性
- コメント・ドキュメントの適切さ
具体的なファイル:行番号とリファクタリング案を提示。
```

**Architecture:**
```
[Architecture Review] <target>を以下の観点でレビュー:
- 設計パターンの適切な使用
- 責務分離、単一責任原則
- 依存関係、結合度
- 拡張性、テスト容易性
具体的なファイル:行番号と改善案を提示。
```

## Output Format

```markdown
# <Tool> Multi-Perspective Review: <target>

## Tool / Model Configuration
使用ツール: <claude|codex|copilot>
（copilot時のみモデルテーブルを表示）

## Summary
| 優先度 | 件数 |
|--------|------|
| Critical/High | X件 |
| Medium | X件 |
| Low | X件 |

## Security
| 優先度 | 問題 | 箇所 |
|--------|------|------|
| High | ... | `file.cs:123` |

## Performance
[結果テーブル]

## Maintainability
[結果テーブル]

## Architecture
[結果テーブル]

## Cross-Tool Insights
（/dual-review 等で複数ツール比較時に記載）

## Recommended Actions (Top 10)
1. [Critical] ...
2. [High] ...
```

## Notes

- 全ツール読み取り専用（ファイル変更なし）
  - claude: Explore agent
  - codex: `--sandbox read-only`
  - copilot: `--no-ask-user`
- `2>/dev/null` でstderr（進捗ログ）を抑制（codex/copilot）
- 結果の重複があれば統合時にマージ
- /dual-review と組み合わせて複数AI視点を比較可能
