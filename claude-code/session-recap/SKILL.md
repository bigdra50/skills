---
name: session-recap
description: 過去のClaude Codeセッションを横断分析し、ユーザー入力・使用スキル・サブエージェント・ビルトインツール・外部CLIを時系列で抽出して共有用ワークフロードキュメントを生成する。Use when the user wants to analyze past sessions, document a feature implementation retrospectively, or share their development process with others. Triggers on "過去のセッションを分析", "ワークフローをまとめて", "ドキュメント化して共有", "参考例として記録", "振り返って", "session-recap".
allowed-tools: Bash(sessions:*), Read, Grep, AskUserQuestion
---

# Session Recap

過去のClaude Codeセッションから、他者に共有可能なワークフロー事例ドキュメントを生成する。

「何を書いたか」ではなく「**ユーザーが何を入力し、どのスキル・ツール・CLIが使われたか**」を時系列で再構成する点が特徴。

## 事前ヒアリング (必須)

起動直後に `AskUserQuestion` で**着目テーマ**を1つ選ばせる。ユーザー入力のスコープ指定が既に明確な場合 (例: "特定機能に偏らず"、"〇〇だけ") はスキップして可。

選択肢:

| ID | ラベル | 内容 |
|----|-------|------|
| overview | プロジェクト俯瞰 (デフォルト) | 特定機能に偏らず、複数テーマを並列で拾う |
| feature | 機能単位 | 1機能の要件〜実装〜レビューを深掘り |
| refactoring | リファクタ/品質改善 | quality-audit / refactor-loop 等の定量改善ループ |
| debug | バグ調査/修正 | 報告→調査→修正のデバッグフロー |
| architecture | 設計判断/アーキテクチャ | 技術選定・設計変更の意思決定過程 |
| tooling | ツール/環境整備 | CLI・MCP・Skill導入などの環境構築 |
| custom | その他 (自由入力) | ユーザーに自由記述させる |

デフォルトは `overview`。選択後、テーマに応じて詳細度・抽出観点を調整する。

## 想定入力

- トピック: "ナレーション機能", "DI導入"
- 期間: "昨日", "先週", "2026-04-16"
- プロジェクト / worktree: "demo/narration"
- スコープ指定: "本番フェーズだけ", "並行作業も含めて"

## 利用できるコマンド

`sessions` CLI (`pip install claude-session-index`) を使う。未インストール時はユーザーに案内する。

```bash
sessions "<query>" [-n N]              # 全文検索 (FTS5)
sessions recent [N]                    # 直近のセッション一覧
sessions find --project <name>         # プロジェクト指定
sessions find --client <name>          # クライアント指定
sessions find --week / --month         # 期間指定
sessions context <session_id>          # 全体像 (先頭10交換)
sessions context <session_id> "<kw>"   # キーワードでフィルタ抽出
sessions analytics [--week|--month]    # 使用統計
sessions synthesize "<topic>"          # 複数セッション横断の要約
```

進め方は任せる。対象セッション特定 → context 取得 → 分類抽出 → 整形、の流れを自分で組み立てる。

## 期待する出力テンプレート

コピペ共有できる形で Markdown を生成する。構造は以下に従う。

### セクション1: フェーズ別 ASCIIフロー図

UserInput をツールと同列のノードとして扱う。

```
### フェーズN: <タイトル> (`<短縮ID>`, 時刻 / N min / N exchanges)

UserInput: "<発話の要点を短く>" または /<skill-name>
    |
    v
<Skill / Agent / Builtin / CLI 呼び出し>
    +-- <ツール>: <アクション>
    +-- <ツール>: <アクション>
    |
    v
UserInput: "<次の発話>"
    |
    v
<次の処理>
```

複数 worktree や並行作業があれば、別フェーズとして併記。

### セクション2: 使用ツール・スキル一覧

分類して表で出す。

| 種別 | 名前 | 用途 |
|------|------|------|
| UserInput | 自然言語 | ... |
| UserInput | `/skill-name` | ... |
| UserInput | `@<path>` | ... |
| Skill | `/xxx:yyy` | ... |
| Agent | `<agent-name>` | ... |
| Builtin | `Read` / `Write` / `Edit` / `Glob` / `EnterPlanMode` / `TaskCreate` 等 | ... |
| CLI | `unilyze` / `gh` / `difit` / `u` / `ffmpeg` / `jb` 等 | ... |

### セクション3: ワークフロー特徴

箇条書きで「なぜそうしたか」「どんな価値があったか」を5〜10項目。

## 分類の指針

| 種別 | 何を拾うか |
|------|-----------|
| UserInput | `🧑` で始まる発話 / `<command-name>` タグ / `@<path>` 参照 |
| Skill | `Base directory for this skill: .../skills/<name>/` 行 |
| Agent | `[Agent]` / `[Task]` マーカー |
| Builtin | `[Read:` `[Write:` `[Edit:` `[EnterPlanMode]` 等 |
| CLI | `[Bash: <cmd> ...]` の先頭コマンド（意図のあるもののみ。単なる `ls` / `cat` / `pwd` は除く） |

## 出力時の原則

- コピペ利用前提。装飾は最小、コードフェンス内に ASCIIフローを配置
- UserInput の発話は引用符で短く抜粋（長文はカット）
- セッション短縮IDのみ記載（`claude --resume <full-id>` は共有時に無意味）
- ユーザーが対象範囲を指定したら従う（「本番だけ」「並行も含めて」等）

## 出力テンプレート

完全な雛形は `references/output-template.md` を参照。プレースホルダー `<...>` を置換して使う。
