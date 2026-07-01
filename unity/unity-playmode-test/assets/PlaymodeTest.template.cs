// Replace placeholders:
//   {Namespace}        e.g. DroidKaigi.UI.Favorite.PlayMode.Tests
//   {ViewType}         MonoBehaviour holding the UIDocument + UI bindings (e.g. FavoriteView)
//   {ViewNamespace}    Namespace of {ViewType} (e.g. DroidKaigi.UI.Favorite)
//   {ScenePath}        Asset path to the preview scene (e.g. Assets/.../FavoritePreview.unity)
//   {ElementName}      VisualElement name to click (e.g. "Segment 1")
//   {ElementSlug}      Identifier-safe form of {ElementName} for method names (e.g. Segment1)
//   {ExpectedLog}      Exact Debug.Log output (used with LogAssert.Expect; prefer "\uXXXX"
//                      escapes for non-ASCII like → so the source stays grep-stable)
//
// SKILL.md requires both a structural test (Q reachable) and a behavioral test (click logs).
// This template ships both — keep them split when adapting.

using System.Collections;
using System.Reflection;
using NUnit.Framework;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;
using UnityEngine.UIElements;

namespace {Namespace}
{
    public sealed class {ViewType}Tests
    {
        const string ScenePath = "{ScenePath}";

        VisualElement _root;

        [UnitySetUp]
        public IEnumerator SetUp()
        {
            EditorSceneManager.LoadSceneInPlayMode(
                ScenePath,
                new LoadSceneParameters(LoadSceneMode.Single));

            // Two frames: one for awake/enable, one for the UI tree to be queryable.
            yield return null;
            yield return null;

            var view = Object.FindAnyObjectByType<{ViewNamespace}.{ViewType}>();
            Assert.That(view, Is.Not.Null, "{ViewType} not found in scene");

            // Pull the post-extract root via reflection so click events go to the elements
            // production code actually wired callbacks against. See SKILL.md "Reflection escape hatch".
            var rootField = typeof({ViewNamespace}.{ViewType})
                .GetField("_root", BindingFlags.NonPublic | BindingFlags.Instance);
            Assert.That(rootField, Is.Not.Null, "_root field missing — test needs an update");
            _root = rootField.GetValue(view) as VisualElement;
            Assert.That(_root, Is.Not.Null, "_root is null — extract pipeline likely failed");
        }

        // Structural test: split per SKILL.md rule 3 (構造テストと動作テストを分離する)
        [Test]
        public void {ElementSlug}_IsReachable()
        {
            var element = _root.Q<VisualElement>("{ElementName}");
            Assert.That(element, Is.Not.Null, "{ElementName} not reachable");
        }

        // Behavioral test: LogAssert mode (default).
        // For state-assertion mode, see SKILL.md "State assert mode" — switch to
        // [UnityTest] IEnumerator and yield return null after the dispatch.
        [Test]
        public void Click_{ElementSlug}_LogsExpectedMessage()
        {
            var element = _root.Q<VisualElement>("{ElementName}");
            Assert.That(element, Is.Not.Null, "{ElementName} not reachable");

            LogAssert.Expect(LogType.Log, "{ExpectedLog}");

            using var click = ClickEvent.GetPooled();
            click.target = element;
            Assert.That(element.panel, Is.Not.Null, "{ElementName} is detached from its panel");
            element.panel.visualTree.SendEvent(click);
        }
    }
}
