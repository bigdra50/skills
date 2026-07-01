---
name: review-performance
description: >-
  Evaluate Unity-specific performance problems from a unilyze snapshot — GC
  allocation patterns, hot-path Unity API misuse, and Burst/DOTS readiness.
  Produces an impact-ranked findings table pointing at the offending method and
  line. Does NOT refactor, does NOT evaluate non-performance smells (that is
  review-metrics / review-safety), and does NOT profile at runtime — runtime
  profiling needs the Unity Editor and the unity-perf skill from unity-cli.
---

# Unity Review — Performance

You are evaluating static performance risk. Your output is an impact-ranked findings table, not code changes and not a profiler capture. Static analysis tells you *what allocates* and *where*; it cannot tell you the measured frame cost — say so explicitly and defer measured numbers to runtime profiling.

Run `review-triage` first. Triage records `energyPressure`, app type, and scripting backend, and decides whether this skill is worth running. If `energyPressure` is `healthy` (< 0.05) and triage flagged no GC-alloc smell, skip this skill.

## Procedure

1. **Reuse the triage snapshot if it exists**, otherwise take a fresh one.
   ```bash
   SNAP=<project>/.unity-review/snapshots/triage.json
   test -f "$SNAP" || unilyze -f json -p <project> -o "$SNAP"
   ```

2. **Extract the performance smells** (the nine below) with file, line, type, and method.
   ```bash
   jq -r '.typeMetrics[] as $t | ($t.codeSmells // [])[]
     | select(.kind | IN("BoxingAllocation","ClosureCapture","ParamsArrayAllocation",
         "ExpensiveUnityApiInHotPath","LinqInHotPath","CollectionAllocationInHotPath",
         "StringConcatenationInHotPath","MissingBurstCompile","ManagedReferenceInComponentData"))
     | [.severity, .kind, $t.filePath, (.line|tostring), .typeName, .methodName, .message]
     | @tsv' "$SNAP"
   ```
   A smell escalated to `Critical` is one that landed inside a `MonoBehaviour` hot-path method (`Update` / `FixedUpdate` / `LateUpdate` / `OnGUI` / an `IEnumerator` coroutine). `Warning` means it is outside a per-frame path — same allocation, far lower frequency.

3. **Read `energyPressure`** from the snapshot — hot-path smell density, not measured energy.
   ```bash
   jq '.energyPressure' "$SNAP"
   ```

4. **Read the offending source.** The jq output names file + line. Open each and confirm the call is genuinely per-frame — the detector escalates only direct `MonoBehaviour` base-list matches and cannot see through project base classes (`Player : BaseView : MonoBehaviour` is missed under SyntaxOnly).

5. **Classify** each finding against the impact matrix, then write the findings table.

## Smell-to-impact matrix

| Smell | Triggering Unity API / pattern | Runtime impact |
|-------|-------------------------------|----------------|
| ExpensiveUnityApiInHotPath | `GetComponent*`, `Find`, `FindObjectOfType`, `FindObjectsByType`, `FindFirstObjectByType`, `Camera.main` in `Update`/coroutine | Sustained CPU — repeated scene traversal every frame; cache in `Awake` instead |
| LinqInHotPath | `Where`/`Select`/`OrderBy`/`ToList` on a per-frame path | GC spike + CPU — enumerator + delegate + result allocation each frame |
| CollectionAllocationInHotPath | `new List<T>()`, `new T[]`, `ToArray()` inside `Update`/coroutine | GC spike — heap garbage every frame, frame hitch on collection |
| StringConcatenationInHotPath | `"a" + b`, `string.Format`, interpolation in `Update`/`OnGUI` | GC spike — transient string garbage; use cached text or `ZString` |
| BoxingAllocation | value type → `object` (struct in `params object[]`, non-generic API) | GC pressure — small allocs; Critical when per-frame |
| ClosureCapture | lambda capturing a local/field, allocated each call | GC pressure — a new closure object per invocation; Critical when per-frame |
| ParamsArrayAllocation | `params T[]` call site allocating an array each call | GC pressure — hidden array alloc per call |
| MissingBurstCompile | `ISystem`/`IJobEntity`/`IJobChunk` struct without `[BurstCompile]` | Left-on-table CPU — job runs as managed IL, not SIMD-vectorized native code |
| ManagedReferenceInComponentData | `struct IComponentData` with a reference-type field | DOTS correctness + GC — breaks blittability, forces managed chunk storage |

`SystemBase`-derived classes are not Burst targets and are correctly not flagged by MissingBurstCompile.

### Empty OnGUI overhead

- **Problem**: Unity calls `OnGUI` every frame even when the method body is empty. Each call incurs IMGUI layout/repaint overhead.
- **Detection**: `grep -rn 'void OnGUI' --include=*.cs` — check for empty or minimal bodies
- **Impact**: Per-frame CPU cost, especially noticeable on mobile/XR where frame budget is tight
- **Fix direction**: Remove empty `OnGUI()` methods, or guard with `#if UNITY_EDITOR` if editor-only

## Cysharp optimization categories

For each finding, name the applicable category from the `csharp-perf-optimizer` knowledge (Cysharp/neuecc OSS). Report the category; do NOT apply the fix here.

| Category | Applies to | Unity-preferred tool |
|----------|-----------|----------------------|
| Zero-allocation | LinqInHotPath, CollectionAllocationInHotPath | `ZLinq`, pre-sized reused buffers |
| Span / Memory | Substring, `Array.Copy`, temp buffers | `Span<T>`, `stackalloc` |
| Struct design | small class value-holders, class enumerators | `readonly struct`, struct enumerator |
| Buffer management | repeated `new byte[]`, no pooling | `ArrayPool<T>`, `MemoryPool<T>` |
| Async optimization | `async Task` on hot path, sync-over-async | `UniTask` |
| UTF-8 native | `Encoding.UTF8.GetString/GetBytes` in I/O | UTF-8 pipelines, `MemoryPack` |
| SIMD | numeric array loops, ECS jobs | `[BurstCompile]`, `System.Numerics` vectors |
| Source Generator migration | reflection, `typeof`, `GetProperties` | `MemoryPack`, source-gen serializers |
| Data layout | struct arrays with field-only bulk ops | SoA, `NativeArray<T>` |
| String allocation | StringConcatenationInHotPath | `ZString`, cached labels |

## Platform sensitivity

Weight findings by the app type recorded in triage. GC spikes hurt most where the frame budget is tight and memory is thermally constrained.

| Issue class | mobile-game | pc-game | xr-app | enterprise-tool | sdk-library |
|-------------|-------------|---------|--------|-----------------|-------------|
| GC alloc in hot path | P0 | P1 | P0 | P2 | P1 |
| ExpensiveUnityApiInHotPath | P0 | P1 | P0 | P2 | P1 |
| Burst/DOTS readiness | P1 | P1 | P0 (frame timing) | P2 | P1 |
| String garbage per frame | P0 | P2 | P0 | P2 | P2 |
| Empty OnGUI overhead | P0 | P1 | P0 | P2 | P2 |
| IL2CPP generic/reflection bloat | P1 (startup, binary size) | P2 | P1 | P2 | P1 |

XR frame budget is ~11ms at 90fps — a single per-frame alloc that a PC title tolerates is a P0 dropped-frame source on a headset.

## Output

Write to `<project>/.unity-review/report/performance-findings.md`. Rank by impact (Critical hot-path first), then by platform priority for the recorded app type.

```markdown
# Unity Review — Performance Findings

energyPressure: <value> (<healthy/warning/alert>)  |  app type: <type>  |  backend: <IL2CPP/Mono>

| # | Impact | Smell | File:Line | Type.Method | Cysharp category | Platform priority |
|---|--------|-------|-----------|-------------|------------------|-------------------|
| 1 | Critical | LinqInHotPath | Player.cs:142 | Player.Update | Zero-allocation (ZLinq) | P0 |

## Notes
- (findings the tool cannot see: base-class-hidden MonoBehaviours, transitive hot paths)
- Measured frame cost is NOT included — run runtime profiling to confirm (unity-perf).
```

Keep it under 200 lines. If you are writing prose paragraphs per finding, you are reviewing instead of cataloguing.

## Boundaries

- Do NOT refactor or edit project code. This skill flags; fixes are a separate task.
- Do NOT evaluate quality smells (GodClass, LongMethod, HighComplexity, coupling, cohesion) — that is `review-metrics`.
- Do NOT evaluate safety smells (`AsyncVoidMethod`, `BlockingTaskWait`, `CatchAllException`, exception smells) — that is `review-safety`.
- Do NOT profile at runtime or quote measured ms/GC bytes. Runtime profiling needs the Unity Editor + the `unity-perf` skill from `unity-cli`.
- Do NOT modify project files except under `<project>/.unity-review/`.

## Related

- `review-triage` — entry point; records `energyPressure`, app type, backend
- `review-metrics` — per-type CodeHealth and quality smells
- `review-safety` — async / exception / disposal smells
- `lang/unity-csharp-guide` — C# in Unity patterns; covers the same allocation traps from the coding side
- `performance-engineer` (perspective) — reads this skill's output for `review-weekly` frame-budget commentary
- `unity-perf` (unity-cli) — the runtime profiler this skill defers measured numbers to
