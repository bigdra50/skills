---
name: legacy-code-improvement
description: |
  レガシーコード改善のガイド。テストなし・ドキュメントなしのコードを安全に改善する手法を提供。
  Use for: "レガシーコード", "テストがない", "引き継いだコード", "リファクタリング", "技術的負債", "コード改善"
context: fork
agent: general-purpose
user-invocable: true
---

# レガシーコード改善ガイド

t_wadaの「実録レガシーコード改善」に基づく実践的アプローチ。

## 改善の3ステップ

```
1. 現状確認 → 2. 闘う準備を整える → 3. 段階的に改善
```

## Step 1: 現状確認

コードの状態を把握：

```
[ ] バージョン管理の有無
[ ] テストの有無
[ ] 自動化（CI/CD）の有無
[ ] 主要ロジックの特定
[ ] 外部依存の把握
```

## Step 2: 闘う準備を整える

開発の3本柱を確立（優先度順）：

1. **Version Control** - まずgit init
2. **Testing** - 最小限のテストから
3. **Automation** - CI/CDの導入

### 最初のテストを書く

「undefinedでなければ良い」程度の雑さで始める：

```javascript
it('returns something', () => {
  assert(result !== undefined);
});
```

## Step 3: 段階的に改善

### 戦術の選択

| 状況 | 戦術 | 説明 |
|------|------|------|
| 既存コードをテストで保護可能 | Extract | ロジックを抽出してテスト |
| 既存コードが複雑すぎる | Sprout | 新コードを別に育てる |

### TDDサイクル

1. 目標をリストアップ
2. テストを1つ書く
3. 失敗させる (Red)
4. 実装する
5. 成功させる (Green)
6. リファクタリング (Refactor)
7. 繰り返す

## 核となるテクニック

### 接合部（Seam）を見つける

外部依存やランダム性を関数引数として差し込み可能にする：

```javascript
// Before: テスト困難
function getNext() {
  return Math.random() * items.length;
}

// After: テスト可能
function createHandler(getNextIndex) {
  // getNextIndexを外から渡せる
}
```

### Humble Objectパターン

フレームワーク依存をPlain Oldオブジェクトから分離：

```
[Framework層] → [Plain Old モデル] ← [テスト]
```

Plain Oldオブジェクトは高速にテスト可能。

## 詳細リファレンス

- 戦術詳細: [tactics.md](references/tactics.md)
- チェックリスト: [checklist.md](references/checklist.md)

## 心得

- 仕様が固まらないからこそテストを書いて変化を支える
- クリーンアーキテクチャは最初から目指すのではなく、リファクタリングで近づく
- 事実をモデリングし、情報をそこから取り出す
