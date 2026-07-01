---
name: review-testing
description: >-
  Assess a Unity project's test posture — presence of test assemblies,
  EditMode vs PlayMode coverage, CI integration, coverage tooling, and test
  design quality. Produces a scorecard plus a gap list of assemblies with no
  corresponding tests. Does NOT write tests, does NOT run tests (that is
  run-tests / unity-verify), and does NOT evaluate code-quality metrics
  (review-metrics).
---

# Unity Review — Testing

You are assessing test *posture*, not test *results*. Your output is a scorecard and a gap list: which assemblies have tests, which do not, and whether the test infrastructure (CI, coverage tooling, layer split) exists. You do not author tests and you do not run them.

Run `review-triage` first. Triage records the app type, which sets whether test coverage is P0 (`sdk-library`, `enterprise-tool`) or P1 (games, xr-app).

## Procedure

1. **Scan for test assemblies.** Test asmdefs reference `UnityEngine.TestRunner` / `UnityEditor.TestRunner` and typically carry `.Tests`, `.EditMode`, or `.PlayMode` in the name.
   ```bash
   find <project>/Assets <project>/Packages -name "*.asmdef" | sort
   grep -rln "UnityEngine.TestRunner\|nunit.framework" <project> --include=*.asmdef
   ```
   Read each test asmdef's `includePlatforms`: an asmdef with `["Editor"]` is EditMode-only; an empty/all-platform list that references `UnityEngine.TestRunner` runs in PlayMode.

2. **Confirm the test framework is installed.**
   ```bash
   grep -n "com.unity.test-framework\|com.unity.testtools.codecoverage\|com.nowsprinting" <project>/Packages/manifest.json
   ```
   `com.unity.test-framework` is required for any tests; `com.unity.testtools.codecoverage` indicates coverage tooling; `com.nowsprinting.test-helper` indicates the project uses the test-helper package (screenshot, scene-load, sampling attributes).

3. **Check CI integration.**
   ```bash
   grep -rln "test-framework\|game-ci\|u tests run\|unity-test-runner\|-runTests" <project>/.github/workflows <project>/.gitlab-ci.yml 2>/dev/null
   ```
   Note whether CI runs EditMode, PlayMode, or both, and whether it uploads coverage.

4. **Count tests if unity-cli is available** (needs the Editor project open; skip if offline).
   ```bash
   u tests list edit -p <project>
   u tests list play -p <project>
   ```
   If `u` is unavailable, count `[Test]` / `[UnityTest]` occurrences as an estimate and label it an estimate:
   ```bash
   grep -rho "\[Test\]\|\[UnityTest\]" <project> --include=*.cs | wc -l
   ```

5. **Build the gap list.** For every production asmdef (non-test), check whether a test asmdef references it. A production assembly with no referencing test assembly is a gap.

## Test layer taxonomy

Tests fall into five layers. Use this to check whether a project's tests sit at the right layer, and whether integration-level behavior is actually covered by integration tests rather than deferred to visual or manual checking.

| Layer | What it tests | Typical assembly | Example |
|-------|--------------|------------------|---------|
| Editor tests | Asset validation, editor extensions | `*.Editor.Tests` | ScriptableObject field constraints |
| Unit tests | Single method, pure logic | `*.Tests` | Math utility, state machine transitions |
| Integration tests | Scene/prefab/component wiring | `*.Tests` (PlayMode) | UI operation sequences, scene transitions |
| Visual verification | Screenshot capture, no assertion | `*.Tests` (PlayMode) | `[TakeScreenshot]` + `[Category("VisualVerification")]` |
| Manual tests | Human sensory judgment only | — | Audio quality, haptic feedback |

Explicitly design integration tests before falling back to visual verification or manual. Visual verification and manual are the last resort, not a substitute for behavior that an assertion could cover.

## Test posture matrix

Rate each dimension. `✓` / `✗` / `partial`.

| Dimension | How to determine | Rating |
|-----------|-----------------|--------|
| EditMode test assembly exists | test asmdef with `includePlatforms: ["Editor"]` | |
| PlayMode test assembly exists | test asmdef referencing TestRunner, non-Editor-only | |
| Test framework installed | `com.unity.test-framework` in manifest | |
| CI runs tests | workflow invokes a test runner | |
| CI runs both modes | workflow runs EditMode AND PlayMode | |
| Coverage tooling | `com.unity.testtools.codecoverage` present | |
| Test count (EditMode / PlayMode) | `u tests list` or `[Test]` estimate | |

## Test design quality checklist

Judge existing tests against the `test-designing-guide` methodology (from `unity-coding-skills`). This is a design-quality read of a sample of test files, not a full audit.

- **Layer assignment is correct** — runtime logic driven by a direct method call lives in **Unit tests**; behavior that only emerges from `AddComponent<T>()` wiring, a prefab, or a scene lives in **Integration tests**; `/Editor/` code and asset validation live in **Editor tests**. Red flag: EditMode tests exercising runtime logic — EditMode and PlayMode runners cannot run in one pass, so splitting one SUT across both prevents running all tests at once.
- **Technique selection is visible** — tests show evidence of equivalence partitioning + boundary value analysis (parameterized where a partition has multiple cases), state transition testing for FSM-shaped code, decision tables for multi-condition logic, and error guessing for game-specific failure modes (button mashing, input during scene transition, PRNG bias, overflow).
- **Specification-based over structural** — tests assert observable behavior, not implementation internals. Structural tests coupled to private state break on every refactor.
- **Naming convention** — `MethodName_Condition_ExpectedResult` for Unit/Editor tests; `Condition_ExpectedResult` (no method name) for Integration/Visual tests.
- **Randomness handled** — PRNG-dependent SUTs stub the generator, verify ranges, verify statistical properties, or verify structural characteristics — not a single lucky assertion.

## Test code quality smells

Grep-able patterns to check when sampling test code. Each is a signal, not a verdict — confirm by reading the surrounding test before flagging.

| Smell | Detection | Why it's bad |
|-------|-----------|-------------|
| Classic assertions | `Assert.AreEqual`, `Assert.IsTrue` in test files | Use constraint model `Assert.That` instead |
| IEnumerator tests | `[UnityTest]` with `IEnumerator` return type | Prefer `[Test] async Task` with `Awaitable` (2023.1+) |
| Control flow in tests | `if`/`switch`/`for`/`foreach`/`while`/ternary in test methods | Each test should be a single path — split into separate methods |
| Raw GameObject.Find | `GameObject.Find` in test files | Use GameObjectFinder (timing-safe, reachability-checked) |
| Fixed-time waits | `Task.Delay`, `Thread.Sleep`, `WaitForSeconds(N)` in tests | Use `Awaitable.NextFrameAsync()` or `WaitUntil` with `[Timeout]` |
| LogAssert for production code | `LogAssert.Expect` verifying production behavior | Use spy logger; LogAssert only for uncontrollable engine logs |
| Merged partitions | `Matches`, `OnlyWhen`, `DependingOn` in test method names | One test = one equivalence partition = one expected outcome |
| Parameterized expected values | Expected outcome varies with test parameters | Never parameterize the expected outcome — split into separate methods |

## Gap analysis

List every production assembly and whether it has a corresponding test assembly:

| Production assembly | Test assembly | Covered? |
|---------------------|---------------|----------|
| MyGame.Core | MyGame.Core.Tests | ✓ |
| MyGame.Gameplay | — | ✗ gap |

Prioritize gaps by the app type: for `sdk-library` / `enterprise-tool`, an untested public-API assembly is P0; for a game, prioritize gaps in assemblies with high churn or low CodeHealth (cross-reference `review-metrics` / `review-hotspot` if their reports exist).

When integration tests exist, a covered assembly can still leave integration-level behavior untested. Check whether the integration tests cover these angles:

- Multi-frame event system interactions
- Scene transitions
- Asset linkage (prefab/SO references survive build)
- UI operation sequences
- UI blocking (modal/overlay reachability)
- UI layout (overlap/overflow via rect assertions, NOT visual verification)

## Output

Write to `<project>/.unity-review/report/testing-scorecard.md`.

```markdown
# Unity Review — Testing Scorecard

app type: <type>  |  coverage priority: <P0/P1>

## Posture
| Dimension | Rating |
|-----------|--------|
| ... | |

## Design quality
- (bullets from the checklist — what the sampled tests do well / miss)

## Gaps
| Production assembly | Test assembly | Covered? | Priority |
|---------------------|---------------|----------|----------|

## Recommendation
- (one line: strongest gap to close first, and which layer it belongs in)
```

Keep it under 180 lines.

## Boundaries

- Do NOT write tests. Test authoring is a separate task (`test-writing-guide` / `failing-test-writer`).
- Do NOT run tests. Running is `run-tests` (unity-cli) or `unity-verify`; this skill only inspects posture.
- Do NOT evaluate code-quality metrics (CodeHealth, GodClass, complexity) — that is `review-metrics`.
- Do NOT design specific test cases — that is `test-designing-guide` at implementation time.
- Do NOT modify project files except under `<project>/.unity-review/`.

## Related

- `review-triage` — entry point; records app type / coverage priority
- `review-metrics` / `review-hotspot` — cross-reference to prioritize gaps by CodeHealth and churn
- `test-designing-guide` (unity-coding-skills) — the design methodology this checklist samples against
- `run-tests` (unity-cli) — the runner this skill defers execution to
- `test-engineer` (perspective) — reads this skill's output for `review-weekly`

Test design methodology details come from the `test-designing-guide` and `test-writing-guide` skills in [unity-coding-skills](https://github.com/nowsprinting/unity-coding-skills).
