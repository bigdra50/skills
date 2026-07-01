# README fragments (条件付き)

standard-readme のセクション順序に従って組み立てる。
各 fragment は条件付き — 条件を満たさないものは入れない。完成形の丸コピーをしない。
`{{...}}` は repo の実情報で埋める。埋められない場合はその fragment 自体を落とす。

## 順序 (standard-readme 準拠)

1. Title → 2. Badges → 3. Short Description → 4. ToC → 5. Background → 6. Install → 7. Usage → 8. Extra → 9. API → 10. Maintainers → 11. Contributing → 12. License (必ず最後)

---

## fragment: title + description (常に)

```markdown
# {{project-name}}

> {{120 字以内の一行説明。パッケージマネージャ / GitHub の description と一致させる}}
```

## fragment: badges (公開 repo かつ CI/パッケージが実在するときのみ)

```markdown
[![CI](https://github.com/{{owner}}/{{repo}}/actions/workflows/{{ci}}.yml/badge.svg)](...)
```

実在しないバッジ (coverage 未計測なのに coverage バッジ等) を置かない。
init モードの既定は省略 (新規 repo に CI / パッケージは実在しないため。CI 追加後に貼る)。

## fragment: ToC (README が 100 行を超えるときのみ)

H2 を 1 階層分リンクする。

## fragment: install + usage (常に。ただしドキュメント専用 repo では省略可)

```markdown
## Install

​```bash
{{実際に動くインストールコマンド 1 つ。選択肢の羅列をしない}}
​```

## Usage

​```bash
{{最小の動く例。出力例があると良い}}
​```
```

## fragment: API (library で公開 API が ~10 個までのとき。超えたら docs/ へ分割し、ここはリンクに)

```markdown
## API

### {{fn(args)}}

{{1-3 行}}
```

## fragment: ハブ化 (S2 以上に移行した repo の README)

詳細を分割先へ逃がし、README は読者別の入口に徹する:

```markdown
## Documentation

- 使い方ガイド: [GUIDE.md](GUIDE.md)
- よくある質問: [FAQ.md](FAQ.md)
- 開発に参加する: [contribute/](contribute/) ({{または CONTRIBUTING.md}})
```

## fragment: contributing (常に。最初は節で足り、CONTRIBUTING.md は外部 PR が来てから)

```markdown
## Contributing

Issue・PR を歓迎します。{{バグ修正 PR は直接 / 新機能は事前に issue で相談、等の方針 1-2 行}}
```

## fragment: license (公開 repo は常に最後。社内 repo では省略)

```markdown
## License

[{{SPDX 識別子}}](LICENSE) © {{owner}}
```
