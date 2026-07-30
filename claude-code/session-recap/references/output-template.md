# Output Template

セッション横断ワークフロードキュメントの雛形。`<...>` の部分を具体的な値で置換する。

---

## <機能/タスク名> 実装ワークフロー (<YYYY-MM-DD>)

<対象スコープの一文概要。並行作業があれば「<worktree-A>（<役割>）と <worktree-B>（<役割>）を別 worktree で並行進行」のように明記>

### フェーズN: <フェーズ名> (`<短縮session-id>`, <HH:MM>–<HH:MM> / <N>min / <N> exchanges)

```
UserInput: "<発話の要点を短く抜粋。複数行なら \n で区切る>"
    |
    v
<Agent/Skill/Builtin 呼び出し> -> <結果の要約>
    |
    v
UserInput: <回答 / 追加指示 / 論点選択>
    |
    v
<Builtin: 主要な処理>
    +-- Write: <file_path>        (<補足>)
    +-- Write: <file_path>
    +-- Edit:  <file_path>        (<補足>)
    +-- Edit:  <file_path>
    |
    v
<CLI 実行> -> <生成物 / 成果の概要>
    |
    v
UserInput: "<バグ報告 or 追加要件>"
    |
    v
<対応の要約: 何をどう変更したか>
    |
    v
UserInput: /<slash-command>
    |
    v
<Skill 処理の結果: 検出件数・改善内容など>
    |
    v
UserInput: /<次の slash-command>  "<引数で渡した指示>"
    |
    +-- <対応項目1>: <変更概要>
    +-- <対応項目2>: <変更概要>
    |
    v
<検証結果: tests / metrics diff / 定量確認>
```

### フェーズN+1: <フェーズ名> (`<短縮session-id>`, <HH:MM>–<HH:MM> / <N>min / <N> exchanges)

```
UserInput: /<slash-command>
    |
    v
<成果物の生成: commit <sha> "<メッセージ>" など>
    |
    v
UserInput: /<slash-command> <引数>
    |
    +-- <CLI 呼び出し>: <用途>
    +-- <CLI 呼び出し>: <用途>
    +-- <付随する動作: ブラウザ起動・URLなど>
    |
    v
<検出事項> N件を特定:
  * <file>:<line> [<種別>] <内容の要点>
  * <file>:<line> [<種別>] <内容の要点>
  * ...
    |
    v
<対応結果>:
  * <修正1>
  * <修正2>
```

### 並行フェーズ: <並行作業名> (`<短縮session-id>`, <HH:MM>–<HH:MM> / <N>min / <N> exchanges)

<本線フェーズとの時間関係を一文で: 例「フェーズNと同時刻に別 worktree (<path>) で実施」>

```
UserInput: "@<参照ファイル>
            <要求内容>"
    |
    v
<既存資産の調査>
    +-- Read: <参考ファイル>
    +-- Read: <参考ファイル>
    +-- Glob: <探索パターン> で <照合対象> を確認
    |
    v
<成果物生成>
    +-- Write: <file_path>   (<内容の要約>)
    +-- Write: <file_path>   (<内容の要約>)
    |
    v
UserInput: "<追加指示>"
    |
    v
Edit: <更新対象ファイル>
    <差分の要約 (before → after)>
```

## 使用ツール・スキル一覧

| 種別 | 名前 | 用途 |
|------|------|------|
| UserInput | 自然言語 | <役割: 要件 / バグ報告 / 論点回答 等> |
| UserInput | `/<skill-name>` | <起動したスキルの役割> |
| UserInput | `@<path>` | <ファイル / PDF 参照添付の用途> |
| Skill | `/<plugin>:<name>` | <用途> |
| Skill | `/<name>` | <用途> |
| Agent | `<agent-name>` | <用途> |
| Builtin | `EnterPlanMode` / `ExitPlanMode` | <用途: 実装前の計画書き出し 等> |
| Builtin | `TaskCreate` / `TaskUpdate` | <用途: 進捗管理 等> |
| Builtin | `Read` / `Glob` / `Write` / `Edit` | <用途> |
| CLI | `<command>` | <用途> |
| CLI | `<command>` | <用途> |

## ワークフロー特徴

1. <特徴1: なぜその選択をしたか / どんな価値があったか>
2. <特徴2>
3. <特徴3>
4. ...

---

## 記入ガイド

- フェーズ数は案件に応じて増減。事前準備・本番実装・コミット&レビュー・並行作業 など
- `UserInput` は自然言語・スラッシュコマンド・`@<path>` 参照のすべてを同列に扱う
- 発話は要点のみ抜粋、長文は適宜省略（読み手が追える最小限）
- フロー図の分岐は `+--` で横並びに、時系列は `|` + `v` で縦方向に
- 「使用ツール」表は種別ごとにまとめ、同種は2〜3行で OK
- 「ワークフロー特徴」は「何をしたか」ではなく「なぜ / どう効いたか」を書く
