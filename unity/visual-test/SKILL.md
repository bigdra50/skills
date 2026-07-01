---
name: visual-test
description: |
  FCU UXML (Figma正解値) と手書き UXML の resolvedStyle を機械的に比較し、デザイン差異を検出する。
  画像認識に頼らず、数値で border-radius, padding, font-size, text-align 等の乖離を漏れなく報告する。
  Use for: "ビジュアルテスト", "デザイン比較", "Figma比較", "見た目テスト", "visual test", "スタイル検証"
allowed-tools: Read, Glob, Grep, Bash, Agent
user-invocable: true
---

# Visual Test - resolvedStyle 自動比較

FCU UXML のインラインスタイル（= Figma デザイン値）と、Play Mode の resolvedStyle（= 実装値）を機械的に比較する。
Claude の画像認識ではなく数値比較で差異を検出するため、テキスト揃え・角丸・padding 等の微差も漏れなく検出できる。

## Usage

```
/visual-test timetable          # Timetable 画面を検証
/visual-test <screen-name>      # 指定画面を検証
```

## Execution

### Step 1: マッピング読み込み

プロジェクトルートから `.claude/reference/visual-test/{screen-name}.yaml` を Read で読む。

YAML の構造:
```yaml
screen: Timetable
fcu_uxml: "Assets/UITK Output/.../Timetable-2.uxml"
fcu_uss: "Assets/UITK Output/.../DroidKaigi2025Ap_Style_2.uss"
hand_uxml: "Assets/UI/Timetable/TimetableScreen.uxml"
hand_uss: "Assets/UI/Timetable/TimetableScreen.uss"
fcu_root_name: "Timetable List View FV 0912"
elements:
  - hand: "session-item"          # 手書き UXML の name 属性
    fcu: "Session_list_item"      # FCU UXML の name 属性
    fcu_css_class: "style-Session-list-item-1356314405"  # FCU USS クラス名 (任意)
    check: [border-radius, border-width, border-color, padding]
```

ファイルが見つからない場合はユーザーに作成を促す。

### Step 2: FCU 正解値の抽出

マッピングの各 element について、FCU UXML と FCU USS から正解値を取得する。

#### 2a. インラインスタイル抽出

FCU UXML から対象要素の `style="..."` 属性を抽出:

```bash
# FCU UXML で対象要素名を含む行を検索し、style= を抽出
grep -o 'name="Session_list_item"[^>]*style="[^"]*"' "$FCU_UXML" | head -1
```

抽出した CSS 文字列をプロパティごとに分割してメモする。

#### 2b. USS クラスプロパティ

`fcu_css_class` が指定されている場合、FCU USS ファイルから該当クラスのプロパティブロックを抽出:

```bash
# USS からクラス定義を抽出
sed -n '/\.style-Session-list-item-1356314405/,/}/p' "$FCU_USS"
```

インラインスタイルと USS クラスの両方のプロパティを統合する（インラインが優先）。

#### 2c. テンプレート内要素

要素が `<ui:Instance template="...">` で参照されている場合、テンプレート UXML ファイル内のルート要素のスタイルも確認する。
Resources/ ディレクトリ内のテンプレートファイルを Read し、内部要素のスタイルを抽出する。

### Step 3: resolvedStyle 取得

#### 3a. Play Mode 開始

```bash
u play
```

Play Mode になるまで `u state` でポーリング（2秒間隔、最大15秒）。

#### 3b. 要素の ref_id 特定

```bash
u uitree dump -p "GameView" -o json
```

JSON 出力から、マッピングの `hand` 名に一致する要素の `ref` ID を特定する。
要素が動的生成（CloneTree）の場合は `u uitree query -p "GameView" -n "{name}"` で検索する。

#### 3c. resolvedStyle 取得

各要素について:

```bash
u uitree inspect {ref_id} --style --json
```

`resolvedStyle` オブジェクトからチェック対象プロパティの値を抽出する。

#### 3d. Play Mode 終了

```bash
u stop
```

### Step 4: 比較 + レポート出力

#### プロパティ名変換

FCU (CSS形式) → resolvedStyle (camelCase) の変換:

| CSS (FCU) | resolvedStyle |
|-----------|---------------|
| padding-left | paddingLeft |
| padding-right | paddingRight |
| padding-top | paddingTop |
| padding-bottom | paddingBottom |
| margin-left | marginLeft |
| margin-right | marginRight |
| margin-top | marginTop |
| margin-bottom | marginBottom |
| border-radius | borderTopLeftRadius, borderTopRightRadius, borderBottomLeftRadius, borderBottomRightRadius |
| border-width | borderTopWidth, borderRightWidth, borderBottomWidth, borderLeftWidth |
| border-color | borderTopColor, borderRightColor, borderBottomColor, borderLeftColor |
| background-color | backgroundColor |
| font-size | fontSize |
| color | color |
| flex-direction | flexDirection |
| align-items | alignItems |
| justify-content | justifyContent |
| -unity-text-align | unityTextAlign |
| width | width |
| height | height |
| flex-wrap | flexWrap |
| white-space | whiteSpace |

shorthand プロパティ（padding, margin, border-radius, border-width）は4辺に展開して比較する。

#### 色値変換

FCU の CSS 色値を resolvedStyle の RGBA 形式に変換して比較:
- `rgb(63, 72, 73)` → `RGBA(0.247, 0.282, 0.286, 1.000)`
- 変換式: `R/255`, `G/255`, `B/255`
- 許容誤差: 各チャネル ±0.02

#### 数値比較

- 単位除去: `16px` → `16.0`
- 許容誤差: ±1.0
- 差がある場合: `MISMATCH` と差分値を報告

#### 未定義チェック

- FCU にプロパティがあるが resolvedStyle にデフォルト値 → `MISSING` (USS に未定義)
- 特に `-unity-text-align` がデフォルト (`upper-left`) のままの場合を検出

#### 画像アセット参照チェック

FCU UXML/テンプレート内で `background-image: url(...)` が設定されている要素について、手書き USS にも対応する `background-image` が設定されているか確認する。

手順:
1. FCU UXML の対象要素とそのテンプレート UXML を Read し、`background-image: url(...)` を含む要素を列挙
2. 対応する手書き USS のクラスに `background-image` プロパティがあるか Grep で確認
3. 未設定の場合は `MISSING_ASSET` として報告

画像参照が漏れると要素の描画サイズが 0 になり表示が崩れる（特にアイコン要素）。

#### 構造比較

resolvedStyle 比較に加えて、要素構造も確認:
- `childCount` の比較（FCU vs 手書き）
- `flexDirection` の比較（横並びが縦並びになっていないか）
- 要素の存在チェック（手書き側に要素がない場合）

#### レポートフォーマット

```markdown
# Visual Test Report: {screen-name}

## Summary
| 要素 | チェック数 | OK | NG | MISSING | MISSING_ASSET |
|------|----------|----|----|---------|---------------|
| session-item | 4 | 3 | 1 | 0 | 0 |
| nav-icon | 1 | 0 | 0 | 0 | 1 |
| ...  |   |    |    |         |               |
| Total | 30 | 25 | 3 | 1 | 1 |

## 差異詳細

### session-item
| プロパティ | Figma (FCU) | 実装 (resolvedStyle) | 差分 | 状態 |
|-----------|-------------|---------------------|------|------|
| borderTopLeftRadius | 24.0 | 24.0 | 0 | OK |
| paddingTop | 16.0 | 12.0 | -4.0 | NG |
| paddingLeft | 16.0 | 12.0 | -4.0 | NG |

### session-title
| プロパティ | Figma (FCU) | 実装 (resolvedStyle) | 差分 | 状態 |
|-----------|-------------|---------------------|------|------|
| fontSize | 22.0 | 14.0 | -8.0 | NG |
| unityTextAlign | middle-center | upper-left | - | MISSING |

(各要素繰り返し)
```

## Notes

- FCU UXML は9画面バリアント等が1ファイルに混在する。`fcu_root_name` で対象画面を特定する
- 動的生成要素（CloneTree で作られた session-item 等）は `u uitree query -n` で検索。最初にヒットした1つを代表として使う
- テンプレート内要素（SessionListItem.uxml 内の session-title 等）はネスト検索が必要
- FCU USS のクラス名はハッシュ付き（`style-Session-list-item-1356314405`）で不安定。FCU 再実行時に変わる可能性がある
- Play Mode の起動に時間がかかる場合がある。`u state` で `isPlaying: true` を確認してから inspect を実行する
- resolvedStyle に含まれないプロパティ（`background-image`, `-unity-font-definition` 等）はこのスキルの対象外。画像・フォントの検証は別途行う
