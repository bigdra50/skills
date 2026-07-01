---
name: review-unity-specific
description: >-
  Detection-only checklist for Unity-specific gotchas that no static analyzer
  catches — Prefab Variant YAML traps, ARFoundation lifecycle ordering, XR
  plugin switching, asmdef versionDefines, UI Toolkit overflow, .meta safety,
  and Unity Hub module paths. Runs a grep/find detection command per trap and
  reports ✓/✗ with affected files. Does NOT fix anything, and does NOT evaluate
  metrics or architecture (review-metrics / review-architecture).
---

# Unity Review — Unity-Specific Gotchas

This skill is detection only. Each item below is a known trap that compiles clean, passes unilyze, and still breaks at build time, on device, or across a domain reload. Run the detection command, decide ✓ (safe / not present) or ✗ (trap present), and list affected files. You do not fix; you surface.

Run `review-triage` first for the project profile — the XR items only apply if triage recorded an XR stack.

For each trap: **Symptom** (what the developer sees), **Cause** (the underlying mechanism), **Detect** (the command to run), **Severity**.

---

## 1. Prefab Variant `m_AddedComponents` with implicit fileIDs

- **Symptom:** components added on a Prefab Variant silently vanish in builds or when the base prefab is restructured.
- **Cause:** a variant records added components as overrides keyed by the base prefab's serialized `fileID`. If the base prefab is edited so those fileIDs shift, the override dangles and Unity drops the component with no error.
- **Detect:** `grep -rln "m_AddedComponents\|m_RemovedComponents" <project>/Assets --include=*.prefab` then open each and confirm no override references a stripped/missing fileID.
- **Severity:** high (silent build-time loss).

## 2. ARFoundation `SubsystemLifecycleManager` AddComponent ordering

- **Symptom:** an AR manager added at runtime (e.g. `ARPlaneManager`) never activates; its subsystem stays stopped.
- **Cause:** managers derived from `SubsystemLifecycleManager` bind to their subsystem in `OnEnable`. `gameObject.AddComponent<ARPlaneManager>()` after the `ARSession` is already running, or on a disabled GameObject, adds it in a state where the subsystem was never started. Order matters: session/config first, then managers, on an enabled object.
- **Detect:** `grep -rn "AddComponent<AR\|AddComponent<XR" <project>/Assets --include=*.cs`
- **Severity:** high on `xr-app`, otherwise n/a.

## 3. XREAL Image Tracking vs Marker Tracking confusion

- **Symptom:** tracking configured but nothing is detected on device.
- **Cause:** the XREAL SDK exposes **Image Tracking** and **Marker Tracking** as distinct subsystems with separate config assets. Wiring the tracked-image database into a marker-tracking flow (or vice versa) compiles fine and tracks nothing.
- **Detect:** `grep -rn "NRTrackableImage\|TrackingImageDatabase\|MarkerTracking\|NRMarker" <project>/Assets --include=*.cs` and confirm the config asset matches the subsystem in use.
- **Severity:** medium on `xr-app`, otherwise n/a.

## 4. Gradle TLS handshake failure

- **Symptom:** Android build fails resolving dependencies with a TLS/SSL handshake error.
- **Cause:** `gradle.properties` (or the JDK's `jdk.tls.disabledAlgorithms`) restricts TLS versions, and a repository requires a version that was disabled. Common after a Unity/JDK upgrade.
- **Detect:** `find <project> -name "gradle.properties" -exec grep -Hn "tls\|https.protocols\|systemProp" {} +` and check for a restrictive TLS setting.
- **Severity:** high (Android build blocker).

## 5. `SessionState` vs `EditorPrefs` for cross-recompile state

- **Symptom:** editor-tool state is lost after a script recompile, or unexpectedly persists across Editor restarts.
- **Cause:** `EditorPrefs` persists indefinitely (registry/plist) — wrong for transient state, which then leaks between sessions. `SessionState` persists only within one Editor session, surviving domain reloads but cleared on exit — the correct store for "remember across recompile, forget on restart."
- **Detect:** `grep -rn "EditorPrefs.Set\|SessionState.Set" <project>/Assets --include=*.cs` (paths under `/Editor/`), then judge whether the chosen store matches the intended lifetime.
- **Severity:** medium (state bugs in tooling).

## 6. asmdef `versionDefines` not set for optional SDK dependencies

- **Symptom:** code guarded by `#if SOME_SDK` never compiles even when the SDK is installed, or the assembly fails to compile when the SDK is absent.
- **Cause:** the `#if` symbol must be produced by the asmdef's `versionDefines` (define this symbol when package X ≥ version Y is present). Without it, the symbol is never defined and the guarded code silently drops out — or hard-references break when the optional package is missing.
- **Detect:** `grep -rn "#if " <project>/Assets --include=*.cs | grep -iv "UNITY_\|DEBUG\|UNITY_EDITOR"` to find SDK guards, then `grep -rln "versionDefines" <project>/Assets --include=*.asmdef` and confirm each guard symbol is defined.
- **Severity:** medium.

## 7. UI Toolkit text-overflow requires 3 properties + a width constraint

- **Symptom:** long text is not truncated with an ellipsis; it overflows or wraps unexpectedly.
- **Cause:** UI Toolkit ellipsis needs all of `text-overflow: ellipsis`, `overflow: hidden`, and `white-space: nowrap`, **plus** a bounded element width. Any one missing and truncation silently does not apply.
- **Detect:** `grep -rn "text-overflow\|white-space\|overflow" <project>/Assets --include=*.uss` and cross-check each truncating label has all three plus a width.
- **Severity:** low (UI polish).

## 8. `.meta` file hand-editing

- **Symptom:** broken asset references, reimport churn, or GUID collisions after a commit.
- **Cause:** a `.meta` file binds an asset path to its GUID and import settings. Hand-editing it (especially the `guid:`) desyncs every reference that points at the old GUID. Meta files must change only through the Editor.
- **Detect:** `git -C <project> log --oneline -5 -- '*.meta'` and `git -C <project> diff --stat -- '*.meta'` — flag any hand edit to a `guid:` line.
- **Severity:** high. If a `.meta` or YAML asset genuinely needs a scripted change, route it through the `unity-yaml-editing-guide` skill — never a freehand edit.

## 9. XRLoader switching via `XRPackageMetadataStore` (needs reflection for featureId)

- **Symptom:** programmatic XR loader / plugin-provider switching (e.g. build automation toggling OpenXR features) fails silently or throws.
- **Cause:** `XRPackageMetadataStore` and the `featureId` accessors used to enable/disable OpenXR features are internal API; correct access requires reflection, and the surface changes between XR Management versions.
- **Detect:** `grep -rn "XRPackageMetadataStore\|XRGeneralSettings\|OpenXRSettings\|SetFeatureEnabled" <project>/Assets --include=*.cs`
- **Severity:** medium on `xr-app`, otherwise n/a.

## 10. Unity Hub module (PlaybackEngines) path assumptions

- **Symptom:** a build script reports a build-target module (Android/iOS/etc.) as not installed even though it is.
- **Cause:** PlaybackEngines live in different places depending on install method. On macOS a Hub-installed editor keeps them under `Hub/Editor/{VERSION}/PlaybackEngines`, while a standalone/manually placed editor uses `<Unity>.app/Contents/PlaybackEngines`. A script hard-coding one path misses the other.
- **Detect:** `grep -rn "PlaybackEngines\|Contents/PlaybackEngines\|Hub/Editor" <project> --include=*.cs --include=*.sh --include=*.yml`
- **Severity:** medium (CI / build-tooling breakage).

## 11. Deprecated `FindObjectOfType` on Unity 2022.3+

- **Symptom:** a deprecation warning at compile time (and eventual removal), plus a silent per-call cost.
- **Cause:** `FindObjectOfType` / `FindObjectsOfType` were deprecated in Unity 2022.3 in favour of `FindObjectsByType(FindObjectsSortMode)`, which makes the sort explicit — the old API always sorted by InstanceID, an avoidable cost. On 6000.4+, `FindFirstObjectByType` is itself being deprecated, so pinning to it is not future-proof.
- **Detect:** `grep -rn "FindObjectOfType\b" <project>/Assets --include=*.cs` — the replacement is `FindObjectsByType` with an explicit `FindObjectsSortMode`.
- **Severity:** medium (2022.3+); high on 6000.4+ where `FindFirstObjectByType` is also deprecated.

## 12. `CanvasScaler` left on Constant Pixel Size

- **Symptom:** UI does not scale across resolutions — correct in the editor Game view, wrong on device.
- **Cause:** a `CanvasScaler` on `Constant Pixel Size` (`m_UiScaleMode: 0`) sizes UI in fixed pixels and does not adapt to different resolutions/DPI. `Scale With Screen Size` (`m_UiScaleMode: 1`) is almost always the intended mode for multi-resolution UI.
- **Detect:** `grep -rn "m_UiScaleMode: 0" <project>/Assets --include=*.unity --include=*.prefab` (0 = ConstantPixelSize; 1 = ScaleWithScreenSize).
- **Severity:** medium.

## 13. Empty `OnGUI()` methods

- **Symptom:** measurable per-frame overhead with no visible benefit.
- **Cause:** any `OnGUI` — even an empty body — routes the component through the IMGUI event loop, which invokes it several times per frame (Layout + Repaint + input events) and allocates. A leftover or empty `OnGUI` is pure waste on every frame.
- **Detect:** `grep -rn "void OnGUI" <project>/Assets --include=*.cs`, then check for empty or near-empty bodies.
- **Severity:** medium (per-frame cost).

## 14. IL2CPP reflection target missing `[Preserve]`

- **Symptom:** a method reached only via reflection returns null / is not found in IL2CPP player builds, though it works in the editor. No compile error, no exception until the reflection call fails — and only in the build.
- **Cause:** IL2CPP's managed-code stripping removes members with no static call site. A method invoked purely through reflection (`GetMethod` + `Invoke`) is stripped unless annotated with `[Preserve]` or covered by a `link.xml`.
- **Detect:** `grep -rn "GetMethod\|MethodInfo\|\.Invoke(" <project>/Assets --include=*.cs`, then confirm the reflected target types/members carry `[Preserve]`. (See also `review-safety`, which flags this as a runtime-safety trap.)
- **Severity:** high (silent, build-only failure).

## 15. Coroutines where `Awaitable` is available (Unity 2023.1+)

- **Symptom:** none functionally — a missed-modernization signal. Coroutines cannot return values, are awkward to cancel, and swallow exceptions.
- **Cause:** Unity 2023.1+ ships `Awaitable`, which integrates with `async`/`await`, `CancellationToken`, and structured exception handling. New async-shaped work written as `IEnumerator` + `StartCoroutine` forgoes cancellation and error propagation.
- **Detect:** `grep -rn "StartCoroutine\|IEnumerator" <project>/Assets --include=*.cs` — only relevant when triage recorded Unity ≥ 2023.1.
- **Severity:** low (info / modernization).

## 16. Prefab editing without the `LoadPrefabContents` / `UnloadPrefabContents` lifecycle

- **Symptom:** prefab corruption, or edits from an editor script that don't save or save only partially.
- **Cause:** editing a prefab asset from an editor script must go `PrefabUtility.LoadPrefabContents(path)` → mutate the returned root → `SaveAsPrefabAsset` → `UnloadPrefabContents`. Mutating a loaded prefab any other way, or skipping the unload, leaks the loaded scene and risks writing a corrupt asset.
- **Detect:** `grep -rn "LoadPrefabContents" <project>/Assets --include=*.cs` and confirm every call has a matching `UnloadPrefabContents`.
- **Severity:** medium.

## 17. Unity YAML written with `true`/`false` instead of `0`/`1`

- **Symptom:** a serialized bool/enum field is silently ignored or misread after a hand edit.
- **Cause:** Unity's YAML serializer writes booleans and enum flags as integers (`1`/`0`), not `true`/`false`. Hand-editing an asset to `: true` yields a value Unity does not parse as expected, so the field falls back to its default with no error.
- **Detect:** `grep -rn ": true\|: false" <project>/Assets --include=*.asset --include=*.mat`
- **Severity:** medium. If an asset genuinely needs a value change, route it through the `unity-yaml-editing-guide` skill — never a freehand edit.

---

## Output

Write to `<project>/.unity-review/report/unity-specific-checklist.md`. XR items on a non-XR project are marked `n/a`.

```markdown
# Unity Review — Unity-Specific Checklist

| # | Trap | Result | Severity | Affected files |
|---|------|--------|----------|----------------|
| 1 | Prefab Variant fileID override | ✓ / ✗ / n/a | high | ... |
| 2 | ARFoundation AddComponent order | ✓ / ✗ / n/a | high | ... |
| ... | | | | |

## Notes
- (context for each ✗ — one line, no fix)
```

Keep it under 180 lines.

## Boundaries

- Do NOT fix any trap. This skill detects and reports only; remediation is a separate task.
- Do NOT hand-edit `.meta` or YAML assets to "verify" a trap — detection is read-only. Any asset edit goes through `unity-yaml-editing-guide`.
- Do NOT evaluate CodeHealth, complexity, or coupling — that is `review-metrics`.
- Do NOT evaluate asmdef dependency direction / layering — that is `review-architecture`.
- Do NOT modify project files except under `<project>/.unity-review/`.

## Related

- `review-triage` — entry point; records the XR stack that gates items 2, 3, 9
- `review-architecture` — asmdef dependency graph (this skill only checks `versionDefines`, not layering)
- `unity-yaml-editing-guide` — the only sanctioned path for editing `.meta` / YAML assets
- `xr-specialist` (perspective) — reads this skill's output for `review-weekly` XR commentary
