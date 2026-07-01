# Troubleshooting

## `_root.Q<T>("name")` が null を返す (production の extract 範囲外)

最頻症状: 構造テスト (`Q != null` を assert するだけのテスト) が fail する。Click 系のテストはその後段で NullReferenceException を吐く。

### 切り分け順

1. **UXML 上に該当 name の element が本当にあるか** — `grep -n 'name="<target>"' Assets/.../*.uxml` で生 name を確認。Source Generator の `UI.X` から推測した名前ではなく **UXML 上の生 name 属性** を写すこと。空白 / 大文字小文字 / ハイフンに注意。
2. **production の screen-extract 設定で `_root` 配下に入っているか** — 採用先が `ScreenConfigRuntime.ExtractScreen` のように **特定 frame を切り出してから bind** する設計を採っている場合、UXML には存在しても `_root` 配下にない要素がある。
   - `*_ScreenConfig.asset` を直接 cat して `defaultElementName` を確認
   - 観測対象がその default element の **配下** にあるか / 同階層 sibling か判定
   - sibling の場合、`_root` から `Q` しても null
3. **Template 展開漏れか** — IncludeTemplates 経由で取れるはずの element が null なら Source Generator 側 (`com.upft.uitoolkit-gen` v0.2.x) の問題。`u console get -l W` で `UITK002 / UITK007 / UITK012` が出ていないか確認。

### 解決策

- 観測対象が **extract 範囲外** = production 設計上のバグまたは仕様ギャップ
  - production 側を修正できるなら ScreenConfig を直す / ExtractScreen を拡張する
  - スコープ外なら本スキル「Contract test として残すパターン」(`[Ignore]` + 理由 XMLDoc + Issue 化) で main に証拠を残す
- 観測対象が **正しく `_root` 配下に居るのに null**
  - 罠 1 (Reflection escape hatch) を疑う: `UIDocument.rootVisualElement` ではなく production が再 parent した `_root` を Reflection で取り出す
  - フレーム待ちが足りない: SetUp で `yield return null` をもう 1 回足す

## ClickEvent.SendEvent しても callback が発火しない

最頻症状: テスト出力で `Expected log did not appear: [Log] ...` のみ報告される。

### 切り分け

1. **構造テストを別に書く** — `Q` が non-null を返すかを `[Test]` で確認する。これが落ちるなら element 取得自体が失敗している (Q チェーン / Template 展開 / シーン未ロードの順で疑う)。
2. **Q チェーン経路と production wiring 経路の `_root` が同じ instance か** — production 側で `ScreenConfigRuntime.ExtractScreen` のような **VisualElement の reparent** をしていると、`UIDocument.rootVisualElement` から見える木と production が callback 登録した木が別 instance になる。

### 解決策

1. **Reflection で production の `_root` を取り出す** (本スキル既定):
   ```csharp
   var rootField = typeof(MyView).GetField("_root", BindingFlags.NonPublic | BindingFlags.Instance);
   var root = (VisualElement)rootField.GetValue(view);
   ```
2. **production 側に `internal VisualElement RootForTesting => _root;` を生やす** — InternalsVisibleTo を使うか、別のテスト境界を切る。Reflection より型安全だが production への侵襲がある。
3. **Panel 経由 dispatch** を併用:
   ```csharp
   element.panel.visualTree.SendEvent(click);  // VisualElement.SendEvent より dispatcher を確実に経由
   ```
   ただしこれは「同 instance」が前提。reparent 問題は解決しない。

## `LogAssert.Expect` 後にテスト全体が fail する (期待通りログは出ているのに)

`LogAssert` は登録した期待ログが `[TearDown]` までに消化されないと fail する。複数 Expect を登録するなら、対応する actions を全て呼ぶこと。

期待 vs 実装が文字列で完全一致していない場合も fail。`→` のような Unicode 文字 / 末尾空白 / 括弧表記の差をまず疑う。

## `[UnitySetUp]` が呼ばれない

- 戻り値型は `IEnumerator` 必須 (`void` ではない)
- 通常の `[SetUp]` (NUnit) と混同しない。`[UnitySetUp]` は Unity 拡張で yield ベース
- フレーム待ちが必要な処理 (シーン読込 / OnEnable 完了待ち) は `yield return null` で 1 フレーム進める

## EditorSceneManager が見つからない (`error CS0234`)

`UnityEditor.SceneManagement` namespace は **Editor 専用**。テスト asmdef の `includePlatforms` が空 (= 全プラットフォーム) でも、Editor namespace は `[UnityTest]` 経由なら使える。
ビルド時にも asmdef がロードされて困る場合は `defineConstraints: ["UNITY_INCLUDE_TESTS"]` を必ず付ける (本スキル asmdef テンプレートは付与済)。

## `u tests run play` が `INSTANCE_BUSY: running_tests` を返す

前回のテスト実行が完了していない、または Editor が他の処理中。

```bash
# ステータス確認 (poll)
u -i <project> tests status

# 強制的に Editor を待たせず後で結果取得
u -i <project> tests run play --no-wait
u -i <project> tests status   # しばらくしてから
```

## テストが見つからない (passed: 0 / failed: 0)

- asmdef の name が `*.Tests.*` 等の Test Runner 認識パターンに合っているか確認 (本スキルテンプレートは `{Project}.{Feature}.PlayMode.Tests` 形式)
- `defineConstraints: ["UNITY_INCLUDE_TESTS"]` が付いているか
- `u tests list play` で discoverable な一覧を確認

## アセンブリ参照不足 (`The type or namespace name 'X' could not be found`)

asmdef の `references` に追加する。最低限必要な 4 つ:

| 参照 | 用途 |
|------|------|
| `{Project}.{Feature}` | テスト対象 (View / MonoBehaviour) |
| `UnityEngine.TestRunner` | `[UnityTest]` `LogAssert` `IPrebuildSetup` 等 |
| `UnityEditor.TestRunner` | `EditorSceneManager` `LoadSceneInPlayMode` |
| (NUnit は自動) | `[Test]` `[TestCase]` `Assert` 等 — TestRunner 参照が引き連れてくる |

`overrideReferences: false` + `precompiledReferences: []` で OK (Unity 6 / com.unity.test-framework 1.6.0+)。
