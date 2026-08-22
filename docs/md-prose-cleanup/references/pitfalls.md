# textlint の落とし穴

実測で確認した挙動をまとめる。
どれも「設定は受理されたのに意図どおり動かない」型の失敗につながる。

## 設定と実行

`.textlintignore` は cwd からしか読まれない。
設定ファイルの隣に置いても無視されるため、`--ignore-path` で明示的に渡す。
これを外すと除外がまったく効かず、対象ファイル全件が検査される。

textlint は設定エラーでも exit 1 を返す。
lint 指摘と区別が付かないので、CI では空ファイルを sentinel として先に検査する。
健全なら必ず 0 件になるため、ここで落ちたら設定が壊れていると判断できる。

`--no-textlintrc` と `-c` を併用すると「No rules found」になり、何も検査しない。

不正なルール名を書いても textlint は警告を出さず静かに無視する。
設定変更は「受理されたか」ではなく「件数が想定どおり動いたか」で確認する。

`textlint --stdin --stdin-filename <name>.md` で標準入力を検査できる。
ファイルを作らずに Issue や PR の本文を検査する経路になる。

## ルール固有

`ai-tech-writing-guideline` だけは設定した severity を無視して必ず error を返す。
このルールが `RuleError` ではなく素のオブジェクトで報告するため、textlint が severity を注入しない。
warning に落として様子を見る運用が取れないので、採用か無効化かの二択になる。

`@textlint-ja/preset-ai-writing` は 1.7.0 で `no-ai-colon-continuation` が独立ルールになった。
1.4.0 では同じ観点が `ai-tech-writing-guideline` の中にあり、大量の指摘を生む。

`ja-no-mixed-period` は「箇条書きの文末に句点を付けない」という規範と正面衝突する。
両方を採る場合はこのルールを無効にする。

`period-in-list-item` の既定 `periodMark` は `.` を含み、英文の箇条書き項目を誤検知する。
`periodMarks: ["。", "．"]` に絞る。

`sentence-length` は英語の文にも効く。
英語で書く文書に当てるときは上限を実測してから決める。

## 検出の死角と当たり

bare URL の autolink は直後の全角閉じ括弧まで飲み込む。
`（https://example.com）` はリンク先が `https://example.com）` になる。
`no-unmatched-pair` がこれを拾うので、指摘が出たら誤検知と決めつけず実物を見る。

prh は箇条書き項目の中にネストした引用ブロックを拾わないことがある。

`no-unmatched-pair` は行をまたぐ括弧も指摘する。
開き括弧と閉じ括弧が別の行にあるだけなら、1 行にまとめれば解消する。

## Markdown の構造

HTML コメントを箇条書きの項目の間に挟むと、CommonMark はリストを 2 つに分割する。
`textlint-disable` で項目を囲むときは、リスト全体の外側に置く。

見出しに含まれる記号を書き換えるとアンカーが変わる。
改名の前に `](#...)` 形式の参照がリポジトリ全体に無いことを確認する。

## 較正の目安

個人の dotfiles（55 ファイル）で測った値を参考として残す。

| 設定 | 指摘 |
| --- | --- |
| ai-writing preset を全部有効 | 158 |
| 調整後・除外なし | 236 |
| 調整後・エージェント向け文書を除外 | 48 |

除外で 109 件の `no-ai-list-formatting` が丸ごと消える。
エージェント向け文書を対象に含めるかどうかが、実用に耐えるかを分ける。
