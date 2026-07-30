# PR Brief テンプレート集

PR の性格に応じて章立てを調整する。ベース雛形: [../assets/skeleton.md](../assets/skeleton.md)

## 目次

- [機能追加 PR](#機能追加-pr)
- [リファクタ PR](#リファクタ-pr)
- [バグ修正 PR](#バグ修正-pr)
- [ドキュメント/設定 PR](#ドキュメント設定-pr)
- [章の書き方](#章の書き方)

---

## 機能追加 PR

章立て:

1. 変更サマリ (3 行 + メタデータ表)
2. 要件と背景 (なぜ必要か)
3. アーキテクチャ (ASCII 図 or 層構造)
4. 新規ファイル一覧 (表: パス / 責務 / 依存)
5. 変更された既存ファイル (表: パス / 変更要約)
6. 設計判断 (ADR 参照 / 試した選択肢 / Rejected options)
7. レビュー論点 (表: 箇所 / 観点 / 想定議論)
8. テスト (追加したテスト一覧 / カバーできない経路)
9. 試してほしいシナリオ (手動検証手順)
10. 関連ドキュメント

---

## リファクタ PR

章立て:

1. 変更サマリ (機能変更がないことを明示)
2. モチベーション (技術的負債 / パフォーマンス / 可読性)
3. Before / After 比較 (コード断片 or 構造図)
4. メトリクス差分 (unilyze, CodeHealth, CBO, CogCC 等)
5. 変更ファイル一覧 (表)
6. レビュー論点 (特に「振る舞いが変わっていないか」)
7. 回帰リスク (既存テストが守る範囲 / 手動検証が必要な箇所)
8. 関連ドキュメント

---

## バグ修正 PR

章立て:

1. 変更サマリ (症状 + 根本原因の 1 行)
2. 再現手順 (修正前の挙動)
3. 根本原因 (なぜ起きていたか)
4. 修正方針 (なぜこの修正か、他案との比較)
5. 変更ファイル一覧
6. テストで固定した振る舞い
7. 回帰リスク (周辺機能への影響)
8. 関連 Issue / ドキュメント

---

## ドキュメント/設定 PR

章立て:

1. 変更サマリ
2. 変更ファイル一覧
3. 主要な変更点 (設定値の意図 / 更新理由)
4. 影響範囲 (ビルド / CI / 他プロジェクト)

---

## 章の書き方

### 変更サマリ

3 行程度で「何を・なぜ・影響範囲」を伝える。メタデータは表で並べる:

```markdown
| 項目 | 値 |
|---|---|
| ブランチ | feature/xxx |
| Base | main |
| コミット数 | N |
| 変更行数 | +XXX / -YYY |
| 変更ファイル数 | N |
| レビュー時間目安 | 15-30 分 |
```

### 変更ファイル一覧

カテゴリでグルーピングし、役割を 1 行で説明する:

```markdown
| カテゴリ | ファイル | 変更 | 役割 |
|---|---|---|---|
| 新機能 | `Assets/App/Scripts/Application/Voice/IVoicePlayer.cs` | +10 | 音声再生の抽象 |
| 新機能 | `Assets/App/Scripts/Application/Voice/StepVoiceNarrator.cs` | +80 | ステップ音声の制御 |
| テスト | `.../SpyVoicePlayer.cs` | +26 | テストダブル |
| 変更 | `Assets/App/Scripts/Application/TrainingSession.cs` | +3/-0 | CurrentScenario 追加 |
```

### レビュー論点表

`file:line` 参照を入れ、議論ポイントを具体的に:

```markdown
| # | 箇所 | 観点 | 議論ポイント |
|---|---|---|---|
| 1 | `StepVoiceNarrator.cs:42` | 並行性 | CTS cancel 後の再生成タイミング |
| 2 | `AudioClipVoicePlayer.cs:35` | 性能 | 同期 Resources.Load のフレームヒッチ |
| 3 | `SceneLifetimeScope.cs:93-99` | 設計 | Voice 関連 DI の位置・スコープ |
```

### アーキテクチャ図 (ASCII)

層や依存関係を図示。巨大な図は避け、要点に絞る:

```
[TrainingSession]
    | OnStepEntered
    v
[StepVoiceNarrator] ── IVoicePlayer ──> [AudioClipVoicePlayer]
                                              |
                                              v
                                       [VoiceClipResolver]
                                              |
                                              v
                                       Resources/Audio/Voice/...
```

### 試してほしいシナリオ

手動検証のステップを番号付きで:

```markdown
1. `u play` で Editor 起動
2. シナリオ `D-C-SF-11` を選択
3. ステップ 0 へ遷移 → Instruction 音声が再生されることを確認
4. 再生中に Bumper → 次ステップへ遷移 → 前音声が停止し次が再生されること
5. Menu で一時停止 → 音声停止を確認 → Resume → ステップ頭から再生
```

### 漏れやすい箇所 / リスク

実装時に見落としがちな観点を箇条書き:

- シナリオ切り替え直後の `Resources.Load` によるフレームヒッチ (`VoiceClipResolver.cs:10`)
- AudioSource が Destroy 済みの状態で Play を呼ぶ経路 (`AudioClipVoicePlayer.cs:38`)
- `?` 未確認: シーン遷移時に `_host` GameObject がどう扱われるか
