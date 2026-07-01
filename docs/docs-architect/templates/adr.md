# 設計記録 templates

2 形式から repo に合う方を 1 つ選ぶ (両方は持たない — 正本一元化)。

## 形式 A: 連番 ADR (Nygard / MADR-lite) — 横断的な設計判断が多いチーム向け

配置: `docs/adr/NNNN-{{title-with-dashes}}.md`。連番は再利用しない。superseded も削除しない。

```markdown
# {{NNNN}}. {{短い名詞句のタイトル}}

- Status: {{proposed | accepted | deprecated | superseded by NNNN}}
- Date: {{YYYY-MM-DD}}
- Deciders: {{判断した人}}

## Context

{{判断を迫られた状況。技術的・組織的な制約を中立に。3-10 行}}

## Decision

We will {{能動態・完全文で決定内容}}.

## Consequences

{{適用後に起きること。良いことだけでなく悪いことも全部列挙}}

## Considered options (任意)

- {{案 A}}: {{捨てた理由}}
- {{案 B}}: {{捨てた理由}}
```

## 形式 B: specs/{feature}/ (Cal.com 型 ADR-lite) — フィーチャー単位で開発するチーム向け

配置: `specs/{{feature-slug}}/`

```
specs/{{feature}}/
├── design.md          # 何を作るか・なぜこの設計か
├── decisions.md       # この feature 内の設計判断ログ (ADR の簡略形を追記式で)
├── implementation.md  # 進捗 running note (完了 PR 番号等)
└── future-work.md     # 意図的にやらないこと・後回しの理由
```

decisions.md の 1 エントリ:

```markdown
## {{YYYY-MM-DD}}: {{判断の短いタイトル}}

- 決定: {{1-2 行}}
- 理由: {{1-3 行}}
- 捨てた案: {{あれば}}
```

## 選び方

| 条件 | 形式 |
|---|---|
| アーキテクチャ横断の判断が多い / 監査・引き継ぎ要件がある | A (連番 ADR) |
| フィーチャー単位の開発フロー / 判断がフィーチャーに閉じる | B (specs/) |
| 個人 OSS でロードマップと一体化したい | PLAN.md 1 枚の running note (pdfme 型) でも可 |
