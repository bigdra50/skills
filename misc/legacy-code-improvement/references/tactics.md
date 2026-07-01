# 改善戦術の詳細

## Extract戦術

既存コードからロジックを抽出してテスト可能にする。

### 適用条件

- 既存コードが理解可能
- 変更範囲が限定的
- テストで保護しながら進められる

### 手順

1. 抽出対象のロジックを特定
2. 特性化テスト（現状の動作を記録するテスト）を書く
3. ロジックを関数/クラスに抽出
4. テストが通ることを確認
5. 抽出したコードをリファクタリング

### 例：ランダム性の分離

```javascript
// Step 1: 元のコード
exports.handler = function(event, context) {
  const index = Math.floor(Math.random() * items.length);
  // ... index を使った処理
};

// Step 2: 関数を引数化
function createHandler(getIndex) {
  return function(event, context) {
    const index = getIndex();
    // ...
  };
}

// Step 3: テストでは固定値を渡す
const handler = createHandler(() => 0);
```

---

## Sprout戦術

新しいコードを別の場所で育て、最小限の接続点で既存コードと繋ぐ。

### 適用条件

- 既存コードが複雑すぎてテスト困難
- 新機能を追加する場合
- 既存コードの変更リスクが高い

### 手順

1. 新機能を独立したモジュールとして設計
2. TDDで新モジュールを実装
3. 既存コードとの接続点を最小化
4. 薄いアダプター層で接続

### 例：セッション管理の分離

```javascript
// 新しいモジュール（独立してテスト可能）
class Session {
  constructor() {
    this.score = 0;
    this.advance = 0;
  }

  start(item) { /* ... */ }
  receive(answer) { /* ... */ }
  dump() { /* 状態をシリアライズ */ }
}

// 既存コードとの接続（最小限）
const session = new Session();
this.attributes['dump'] = session.dump();
```

---

## 戦術の選択基準

```
既存コードをテストで十分保護できる？
    │
    ├─ Yes → Extract戦術
    │         ・段階的に抽出
    │         ・特性化テストで保護
    │
    └─ No  → Sprout戦術
              ・新コードを別で育てる
              ・接続点を最小化
```

---

## Humble Objectパターン

テスト困難なフレームワーク依存を分離する。

### 構造

```
┌─────────────────────────────────────────┐
│  Framework Layer (Humble Object)        │
│  - 入出力の変換のみ                      │
│  - ロジックを持たない                    │
└─────────────┬───────────────────────────┘
              │ 委譲
              ▼
┌─────────────────────────────────────────┐
│  Domain Layer (Plain Old Object)        │
│  - ビジネスロジック                      │
│  - フレームワーク非依存                  │
│  - 高速にテスト可能                      │
└─────────────────────────────────────────┘
```

### 例：Alexa Skill

```javascript
// Humble Object（テスト困難だが薄い）
QuizIntent: function() {
  const session = startSession({env});
  this.attributes['dump'] = session.dump();
  this.emit(':ask', session.message(), session.reprompt());
}

// Plain Old Object（テスト容易）
class Session {
  message() {
    return `簡単なクイズをしましょう。${this.advance}番。${this.item.q}`;
  }
}
```
