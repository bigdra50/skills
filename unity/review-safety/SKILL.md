---
name: review-safety
description: >-
  Evaluate runtime safety from a unilyze snapshot plus targeted AI review —
  async/await patterns, exception handling, and resource disposal. Produces a
  severity-ranked findings table (crash / data-loss / degraded) naming the
  offending pattern. Does NOT propose fixes (flag only), does NOT evaluate
  performance smells (review-performance), and does NOT evaluate architecture
  (review-architecture / review-metrics).
---

# Unity Review — Safety

You are evaluating runtime safety. Your output is a severity-ranked findings table that flags dangerous patterns — you do not write the fix. Six of these smells are detected mechanically by unilyze; two important classes (IDisposable leaks, Process deadlocks) are unilyze blind spots and require a targeted AI read.

Run `review-triage` first. This skill has no threshold gate — safety bugs matter regardless of CodeHealth — but triage tells you the scripting backend, which changes how `async void` fails (see below).

## Procedure

1. **Reuse the triage snapshot if it exists**, otherwise take a fresh one.
   ```bash
   SNAP=<project>/.unity-review/snapshots/triage.json
   test -f "$SNAP" || unilyze -f json -p <project> -o "$SNAP"
   ```

2. **Extract the safety smells** (the six below) with file, line, type, and method.
   ```bash
   jq -r '.typeMetrics[] as $t | ($t.codeSmells // [])[]
     | select(.kind | IN("AsyncVoidMethod","BlockingTaskWait","CatchAllException",
         "MissingInnerException","ThrowingSystemException","WeakTemporization"))
     | [.severity, .kind, $t.filePath, (.line|tostring), .typeName, .methodName, .message]
     | @tsv' "$SNAP"
   ```

3. **AI review for the two blind spots** unilyze does not detect:
   - **IDisposable leaks** — grep for the disposable Unity/native types, then read whether each is disposed.
     ```bash
     grep -rn "new NativeArray\|new NativeList\|new NativeHashMap\|new ComputeBuffer\|new RenderTexture\|GraphicsBuffer\|new CommandBuffer" <project>/Assets --include=*.cs
     ```
   - **Process deadlocks** — external process launches whose stdout/stderr are read after `WaitForExit` (classic pipe-buffer deadlock).
     ```bash
     grep -rn "Process.Start\|ProcessStartInfo\|WaitForExit\|StandardOutput\|StandardError" <project>/Assets --include=*.cs
     ```

4. **Read the source** behind every hit and classify against the severity matrix. Do not classify a smell you have not read — the detector points at the line, the source tells you whether the exception is genuinely swallowed or rethrown with context.

## Smell severity matrix

Severity is the *consequence class*, not CodeHealth. Rank crashes first.

| Smell / pattern | Severity | Why it bites |
|-----------------|----------|--------------|
| BlockingTaskWait | crash / freeze | `.Result` / `.Wait()` / `.GetAwaiter().GetResult()` on Task/ValueTask/UniTask blocks the Unity main thread; if the awaited work resumes on that same thread, it deadlocks — the app hard-freezes |
| Process deadlock (blind spot) | crash / freeze | `WaitForExit` before draining `StandardOutput`/`StandardError` blocks when the child fills the pipe buffer |
| AsyncVoidMethod | crash / silent loss | see async note below — Editor domain-reload crash, silent swallow in builds |
| IDisposable leak (blind spot) | degraded → crash | undisposed `NativeArray`/`ComputeBuffer`/`RenderTexture` leaks native/GPU memory; grows until allocation fails |
| CatchAllException | silent loss | `catch (Exception)` without rethrow hides real bugs; failures pass unnoticed |
| MissingInnerException | data-loss (diagnostic) | catch-and-rethrow that drops the original as `innerException` — the root cause and its stack are gone |
| ThrowingSystemException | degraded | throwing base `Exception`/`SystemException` gives callers no type to catch selectively; forces broad catches downstream |
| WeakTemporization | degraded (correctness) | transform mutation in `Update`/`LateUpdate` without `Time.deltaTime` — movement speed is frame-rate-dependent; behaves differently on a 60Hz vs 144Hz display |

## async/await in the Unity context

- **AsyncVoidMethod is uniquely dangerous in Unity.** An `async void` has no `Task` to observe, so an exception it throws is unobserved. In the **Editor**, an unobserved exception during play can corrupt or crash the domain reload; in a **player build** (especially IL2CPP) it is silently swallowed and the operation just… stops, with no log and no crash to investigate. unilyze already excludes genuine Unity message methods (`async void Start` is idiomatic) and event handlers — a remaining hit is a real async-void call site. Prefer `async UniTask` / `async UniTaskVoid` with explicit exception handling.
- **BlockingTaskWait deadlocks the main thread.** Unity's default synchronization context marshals continuations back to the main thread. Blocking that thread on `.Result` while the awaited continuation is queued *for* that thread is a self-deadlock. This is why sync-over-async freezes Unity where it merely stalls a thread-pool app.
- **A `catch (Exception)` around an `await` breaks cancellation.** When awaiting with a `CancellationToken`, cancellation surfaces as `OperationCanceledException`. A general `catch (Exception)` swallows it, so cancellation never propagates and the caller's `Task` completes as if the work succeeded — this is a CatchAllException sub-case that specifically corrupts async control flow. Re-throw `OperationCanceledException` in a dedicated `catch` clause placed *before* the general one (or `catch (Exception ex) when (ex is not OperationCanceledException)`). Detect it by grepping `catch (Exception` in files that also contain `CancellationToken` or `OperationCanceledException`.

## IDisposable patterns in Unity

These MUST be disposed and are easy to forget — no GC finalizer will reliably reclaim native/GPU memory in time:

| Type | Leak consequence | Correct ownership |
|------|-----------------|-------------------|
| `NativeArray<T>` / `NativeList<T>` / `NativeHashMap` | native memory leak; the Job safety system logs a leak on domain reload | `using`, or dispose in `OnDestroy`, or `[Allocator.Temp]` scope |
| `ComputeBuffer` / `GraphicsBuffer` | GPU memory leak | dispose in `OnDisable`/`OnDestroy` |
| `RenderTexture` | GPU memory leak; `Release()` required, not just GC | `Release()` + `Destroy()` when done |
| `CommandBuffer` | native leak per frame if created in a render callback | create once, reuse, dispose on teardown |

## IL2CPP code stripping and `[Preserve]`

A method reached only through reflection has no static call site, so IL2CPP's managed-code stripping removes it from player builds. There is no compile error and no runtime exception until the reflection lookup itself fails (`GetMethod` returns null, or `Invoke` throws) — and only in the build, never in the editor. This is a classic "works in the editor, silently broken on device" trap.

- **Symptom:** a reflected method or type disappears in IL2CPP builds; the lookup returns null while the same code works in the editor (Mono).
- **Cause:** the stripper cannot see a reference that exists only at runtime via reflection.
- **Correct handling:** annotate the reflected member (or type) with `[Preserve]` (`UnityEngine.Scripting.Preserve`), or cover it with a `link.xml`. Flag only — do not add the attribute yourself.
- **Detect:** `grep -rn "MethodInfo\|GetMethod\|\.Invoke(" <project>/Assets --include=*.cs`, then check whether the reflected target types/members carry `[Preserve]`. This matters most when triage recorded the IL2CPP backend.

## Output

Write to `<project>/.unity-review/report/safety-findings.md`. Rank by severity (crash → data-loss → degraded).

```markdown
# Unity Review — Safety Findings

backend: <IL2CPP/Mono>

| # | Severity | Pattern | File:Line | Type.Method | Consequence |
|---|----------|---------|-----------|-------------|-------------|
| 1 | crash | BlockingTaskWait | Loader.cs:88 | Loader.Init | main-thread deadlock on .Result |

## Blind-spot findings (AI review)
| # | Severity | Pattern | File:Line | Evidence |
|---|----------|---------|-----------|----------|
| 1 | degraded | NativeArray not disposed | Mesh.cs:40 | allocated in Awake, no OnDestroy dispose |
```

Keep it under 180 lines.

## Boundaries

- Do NOT propose or apply fixes. Flag the pattern and its severity; the fix is a separate task.
- Do NOT evaluate performance smells (`LinqInHotPath`, `BoxingAllocation`, hot-path allocation) — that is `review-performance`.
- Do NOT evaluate architecture, coupling, or per-type CodeHealth — that is `review-architecture` / `review-metrics`.
- Do NOT run the code or open the Unity Editor. This is a static + read-only review.
- Do NOT modify project files except under `<project>/.unity-review/`.

## Related

- `review-triage` — entry point; records scripting backend
- `review-performance` — hot-path allocation and Unity API misuse
- `review-metrics` — per-type CodeHealth and quality smells
- `review-weekly` — orchestrator; perspective agents read this skill's output
