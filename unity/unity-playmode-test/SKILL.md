---
name: unity-playmode-test
description: Unity UI Toolkit のクリック操作を [Test]/[UnityTest] + LogAssert または Assert.That(state) + ClickEvent で回帰テスト化するスキル。シーン読込 → element 取得 → ClickEvent 発火 → ログ assert または ViewModel state assert の最小テンプレを生成し、`u tests run play` で自動実行する手順までカバー。MonoBehaviour 内で `_root` を再 parent するパターン (ScreenConfigRuntime.ExtractScreen 系) で起きる「Q チェーンは取れるがクリックが届かない」罠の Reflection 回避策 (`_root` だけでなく `_viewModel` 等 private collaborator 全般) 付き。Focus / TextField 値入力 / uGUI / monkey test はカバー外。Use when "PlayMode テスト書いて", "ClickEvent を自動化", "u tests run play", "UI 操作の回帰テスト", "[UnityTest]", "LogAssert.Expect", "Assert.That ViewModel", "EditorSceneManager.LoadSceneInPlayMode", "PlayMode test for UI Toolkit".
---

# Unity Playmode Test (UI 操作)

> **PREREQUISITE**: `unity-shared` (Relay Server 経由で Unity Editor 起動中、`-i <instance>` 必須)

`u uitree click` で外形操作する `unity-ui` とは目的が違う。本スキルは **NUnit `[UnityTest]` クラスを書いて回帰テストとして main に commit する** 部分を扱う。CI / `u tests run play` で再実行できる形に落とし込むことが目的。

## ワークフロー

1. **テスト対象の決定** — どの MonoBehaviour / どのシーン / どの element / 何が成功条件か。
   **Pre-flight A** (シーン側): 指定シーンに target MonoBehaviour が wire されているか `u -i <project> uitree dump` で確認 (空シーン / Prefab だけのシーンに対してテストを書いて SetUp で `FindAnyObjectByType` が null を返す事故を防ぐ)。
   **Pre-flight B** (production の到達範囲側): 観測したい element が production の **screen-extract 後の `_root` 配下にあるか** を確認する。`ScreenConfigRuntime.ExtractScreen` のような切り出しを通すと、UXML 上は存在しても `_root.Q(...)` で null を返す要素がある (sibling frame / 状態別 frame / Off-screen 等)。
   - `*_ScreenConfig.asset` (ScriptableObject) の `defaultElementName` / `parentElementName` を直接読んで、production が「Empty / Loading 等」をどう extract しているかを把握する
   - 観測対象が extract 範囲外の場合、**テストの前に production 側の wiring を直す** か、本スキル末尾「Contract test として残す」パターンを使う
2. **要素名の命名規則確認** — `_root.Q<T>("name")` の name は **UXML 上の生 `name` 属性** (例: `"Favorite Empty"`、空白あり)。一方 Source Generator が生成する `UI.X` プロパティ名は PascalCase 化された identifier (`UI.FavoriteEmpty`)。Q に渡す文字列を間違えないように、UXML の name を正として写す (`UI.X` の名前から推測しない)。詳細は採用先 `docs/unity/figma-naming-conventions.md` 参照。
3. **asmdef 配置** — `assets/asmdef.template.json` を `Tests/PlayMode/` に置く
4. **テストクラス作成** — `assets/PlaymodeTest.template.cs` を雛形にして書く
5. **コンパイル確認** — `u -i <project> refresh` → `u -i <project> state` で `isCompiling=False`
6. **実行** — `u -i <project> tests run play -a <Assembly>`
7. **fail したら** `references/troubleshooting.md` を読む

## Contract test として残すパターン

production 側に潜在バグがあって fix がスコープ外の時は、テストを「望ましい挙動の encoding」として残す。production fix 後に有効化される設計:

```csharp
// [Explicit] は Unity Test Framework の `u tests run play -a <asm>` (filter なし) で
// run されてしまう。確実に skip するには [Ignore] を class または method に付ける。
[Ignore("Currently failing on purpose — encodes desired behavior for X bug. Remove [Ignore] once production Y is fixed.")]
public sealed class FooContractTests { ... }
```

`[Explicit]` ではなく `[Ignore]` を使うこと。bug fix 後に `[Ignore]` を外せば自動的に gating されはじめる。コミットメッセージ / PR description / コメントで「contract test、production fix 待ち」と必ず明示する。

## 配置場所

```
Assets/<Project>/Scripts/UI/<Feature>/
  ├── <Feature>View.cs           ← テスト対象
  ├── <Feature>View.gen.cs
  └── Tests/PlayMode/            ← 本スキルが追加する
      ├── <Project>.<Feature>.PlayMode.Tests.asmdef
      └── <Feature>ViewTests.cs
```

asmdef は **テスト対象の asmdef と同階層に Tests/PlayMode/ を作って配置** するのが Unity 慣習。

## asmdef の最低条件 (assets/asmdef.template.json)

| 設定 | 値 | 理由 |
|------|---|------|
| `name` | production asmdef name + `.PlayMode.Tests` (例: `DroidKaigi.UI.Favorite` → `DroidKaigi.UI.Favorite.PlayMode.Tests`) | template の `{Project}.{Feature}` は production 名全体を 1 単位として扱い、`.PlayMode.Tests` を append する |
| `references` | テスト対象 + `UnityEngine.TestRunner` + `UnityEditor.TestRunner` | NUnit / EditorSceneManager / LogAssert を解決 |
| `defineConstraints` | `["UNITY_INCLUDE_TESTS"]` | 本番 build から除外 (採用先汚染防止) |
| `autoReferenced` | `false` | 他 asmdef から自動参照させない |
| `overrideReferences` | `false`, `precompiledReferences: []` | Unity 6 の TestRunner が NUnit を提供するため明示 precompiled は不要 |

## テストクラスの定型 (assets/PlaymodeTest.template.cs)

最小骨格 (LogAssert mode):

```csharp
[UnitySetUp]
public IEnumerator SetUp()
{
    EditorSceneManager.LoadSceneInPlayMode(ScenePath, new LoadSceneParameters(LoadSceneMode.Single));
    yield return null;  // OnEnable 完了
    yield return null;  // UI tree 構築完了

    var view = Object.FindAnyObjectByType<MyView>();
    var rootField = typeof(MyView).GetField("_root", BindingFlags.NonPublic | BindingFlags.Instance);
    _root = (VisualElement)rootField.GetValue(view);
}

[Test]
public void Click_X_LogsExpected()
{
    var element = _root.Q<VisualElement>("X");
    LogAssert.Expect(LogType.Log, "[MyView] X clicked");

    using var click = ClickEvent.GetPooled();
    click.target = element;
    element.panel.visualTree.SendEvent(click);
}
```

### State assert mode (LogAssert を使わない場合)

assert したいのが「ログが出る」ではなく「ViewModel / VisualElement の状態が変わる」場合は `[UnityTest] IEnumerator` を使い、Click 発火後 1 フレーム待ってから `Assert.That` で読む。

```csharp
[UnityTest]
public IEnumerator Click_X_FlipsViewModelState()
{
    var element = _root.Q<VisualElement>("X");

    using var click = ClickEvent.GetPooled();
    click.target = element;
    element.panel.visualTree.SendEvent(click);

    yield return null;  // dispatcher → propertyChanged → state mutate を 1 フレーム消化

    Assert.That(_viewModel.Selected, Is.True);  // _viewModel も Reflection で取り出す (罠 1 参照)
}
```

LogAssert mode と state mode の選択基準:

| 観測対象 | 推奨 mode | 必要な属性 | 待ち |
|----------|----------|----------|------|
| `Debug.Log(...)` | LogAssert | `[Test]` | 不要 (Expect は遅延消化) |
| `_viewModel.X` / `element.classList` の変化 | State | `[UnityTest] IEnumerator` | dispatch 後 `yield return null` 1 回 |

State mode で「View 単独 vs Service 経由」の判断: production の click handler が **View 内で完結** している (例: `_viewModel.Selected = true`) なら `[UnitySetUp]` で View だけ用意すれば足りる。production が **collaborator (Service / Reducer 等) を経由** して状態を変える場合は、`[UnitySetUp]` 内で minimal stub collaborator を wire する (test を contract spec として書く)。どちらかを選んだ理由をテストの XMLDoc にコメントしておく。

### Unicode を含む期待文字列

`Debug.Log("→")` のような非 ASCII 文字を `LogAssert.Expect` で照合するときは、ソース上での揺れ (エディタの自動変換、ZWSP 混入) を避けるため `"→"` の Unicode escape で書くことを推奨。grep で検索しやすくもなる。

## 必須の罠 3 点

### 1. Reflection escape hatch (private 依存の汎用取り出し)

production が `_root = ScreenConfigRuntime.ExtractScreen(_root, _screenConfig)` のように **VisualElement を別 container に reparent** していると、`UIDocument.rootVisualElement` から見える木と production がイベントハンドラを登録した木が **別 instance** になる。

→ `Q` で element は取れるが Click を発火しても callback が呼ばれない (= テストだけ fail、手動操作なら動く罠)。

回避: production の private `_root` フィールドを Reflection で取り出す (上記 SetUp 参照)。理由をコメントで明記すること (将来の自分が「なぜ Reflection？」と問う)。

`_root` が代表例だが、**Reflection は private 依存を取り出す汎用 pattern として使う**。state assert で `_viewModel` を見たい / Service の内部 cache を確認したい等、private collaborator 全般に同じ手法を適用できる。

```csharp
var vmField = typeof(MyView).GetField("_viewModel", BindingFlags.NonPublic | BindingFlags.Instance);
_viewModel = (MyViewModel)vmField.GetValue(view);
```

production 側に侵襲してよいなら `internal VisualElement RootForTesting => _root;` / `internal MyViewModel ViewModelForTesting => _viewModel;` + `InternalsVisibleTo` の方が型安全 (リネーム時に compile error で気付ける)。Reflection は production 改変できない / 改変したくないときの fallback。

production が Source Generator 出力 (`*.gen.cs`) で **partial class** に分割されているケースも同様に動く: `typeof(View).GetField("_root", NonPublic | Instance)` は同 partial class 全体 (gen.cs + 手書き .cs 両方) のフィールドを 1 つの type として見る。どの partial にフィールドが宣言されていても触れる。再生成で消えるのは gen.cs 側だけなので、`internal *ForTesting` を生やすなら手書き .cs 側に置く。

### 2. ClickEvent dispatch は panel 経由

```csharp
element.SendEvent(click);             // ❌ dispatcher を経由しないことがある
element.panel.visualTree.SendEvent(click);  // ✅ Manipulator (Clickable) を確実に経由
```

### 3. 構造テストと動作テストを分離する

1 つの `[TestCase]` に「Q できる」「Click が発火する」を混ぜない。fail したとき切り分けに時間がかかる。

```csharp
[Test] public void Element_IsReachable() { ... Assert.That(seg, Is.Not.Null); }     // 構造
[TestCase(...)] public void Click_LogsExpected(...) { ... LogAssert.Expect(...); }  // 動作
```

両方 fail なら element 取得が悪い、構造のみ pass で動作 fail なら罠 1 か 2 を疑う。

## `u tests run play` 実行

```bash
# 全 PlayMode テスト
u -i <project> tests run play

# 特定 asmdef
u -i <project> tests run play -a <Assembly>

# regex (テスト名)
u -i <project> tests run play -g "Click_.*"

# fire-and-forget (大規模 suite)
u -i <project> tests run play --no-wait
u -i <project> tests status
```

返り値:

```
total / passed / failed / skipped / duration
failedTests: [ { name, message, stackTrace } ]
```

非ゼロ exit code で fail するため CI に組み込みやすい。

## fail 時の起点

`references/troubleshooting.md` 参照。よくある順:

1. ClickEvent が届かない → 罠 1 (Reflection escape hatch) または罠 2 (panel dispatch)
2. `LogAssert.Expect` が消化されない → 期待文字列が完全一致していない (Unicode 文字 / 末尾空白)
3. `[UnitySetUp]` が呼ばれない → 戻り値型が `IEnumerator` でない / 通常の `[SetUp]` と混同
4. テストが見つからない → asmdef name / `defineConstraints` / `u tests list play` で確認

## 本スキルでカバーしないもの

- **uGUI** (`Button.onClick.Invoke()` 等の API は別)
- **Visual Regression** (screenshot 比較は `unity-ui` の `u screenshot` + 画像比較に任せる)
- **monkey test** (`unity-ui` の `u uitree monkey` を使う)
- **EditMode test** (シーン不要な単体テスト) — 本スキルは PlayMode 専用
- **Focus / FocusEvent 単独テスト** (focus state を assert したいだけの場合) — 別途 FocusEvent + `Assert.That(panel.focusController.focusedElement, Is.SameAs(...))` が必要。本スキルの ClickEvent パターンは応用できるが boilerplate を別途用意していない
- **TextField の値入力テスト** (`SetValueWithoutNotify` / `value = ...` / `ChangeEvent<string>` 発火) — Click とはイベントモデルが異なる。本スキルではクリックのみ扱う
