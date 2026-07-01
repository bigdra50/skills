# AGENTS.md / CLAUDE.md templates

## AGENTS.md (正本)

実際に動くコマンドだけを書く。動かないコマンド・将来の予定を書かない。
書く前に各コマンドを文書化された順 (Setup → Build → Test) で実際に実行して検証する。慣習的な形 (`pip install -e ".[test]"` 等) を未検証のまま書かない。
検証で生じた副産物 (`__pycache__`, `.pytest_cache` 等) は片付け、.gitignore がカバーしていることを確認する。
各 fragment は該当するときのみ。

```markdown
# AGENTS.md

{{1-2 行: 何のプロジェクトか + アーキテクチャの要点}}

## Setup

​```bash
{{依存導入 + 起動までの実コマンド。Web アプリなら docker-compose up 等}}
​```

## Build & Test

​```bash
{{build コマンド}}
{{test コマンド (単体 / E2E が分かれるなら両方)}}
{{lint / format コマンド}}
​```

## Code style

{{実在する規約のみ。linter 設定があるならそれを正とし「`{{lint コマンド}}` に従う」で済ます}}

## 構造の要点

{{ディレクトリの責務 1 行ずつ。3-8 行程度。新規参加者 (人間/AI) が迷う箇所だけ}}

## PR / commit 規約

{{実在する規約のみ (例: conventional commits、PR サイズ上限)。無ければこの節ごと省略}}
```

肥大化したら分割: ルートは要点のみ残し、詳細をサブディレクトリの AGENTS.md にネストする (最近接優先の仕様を利用)。

## CLAUDE.md

```markdown
@AGENTS.md
```

1 行のみ。内容を持たせない (正本一元化)。
既存 CLAUDE.md に実内容がある場合: 内容を AGENTS.md へ移し、この形に置換する (ユーザー確認必須)。
symlink (`ln -s AGENTS.md CLAUDE.md`) でも等価だが、Windows 開発者がいる repo では import 形式を選ぶ。
