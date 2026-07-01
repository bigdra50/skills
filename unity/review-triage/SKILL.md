---
name: review-triage
description: >-
  Day 0 assessment for a Unity project. Runs unilyze snapshot and
  u project info to produce a scorecard covering CodeHealth, assembly
  structure, test posture, Unity version, and top 3 risks.
  Does NOT propose fixes — those come from the other unity-review-* skills.
---

# Unity Review — Triage

You are performing Day 0 triage for a Unity project. Your job is to produce a short, honest scorecard of the repository's current state, not to propose fixes. Fix recommendations come later from the other `unity-review-*` skills.

## Classify the project

Before running any tool, determine the project profile. Ask the user or infer from ProjectSettings and manifest.json.

| Dimension | Values |
|-----------|--------|
| App type | `mobile-game` / `pc-game` / `xr-app` / `enterprise-tool` / `sdk-library` |
| Render Pipeline | URP / HDRP / Built-in |
| Scripting Backend | IL2CPP / Mono |
| XR stack (if applicable) | ARFoundation + ARCore/ARKit, OpenXR, XREAL SDK, Meta SDK |
| Multiplayer (if applicable) | Netcode for GameObjects, Photon, Mirror, none |

The app type determines which thresholds are P0 vs P1 in the scorecard:

| Check | mobile-game | pc-game | xr-app | enterprise-tool | sdk-library |
|-------|-------------|---------|--------|-----------------|-------------|
| energyPressure | P0 | P1 | P0 | skip | skip |
| GC alloc smells | P0 | P1 | P0 | P1 | P1 |
| Test coverage | P1 | P1 | P1 | P0 | P0 |
| API surface stability | skip | skip | skip | P1 | P0 |
| IL2CPP compatibility | P0 | P1 | P0 | P1 | P0 |

## Procedure

0. **Project metadata** — run offline, no Editor needed.
   ```bash
   u project info -p <project>
   u project version -p <project>
   u project packages -p <project>
   u project assemblies -p <project>
   ```
   If `u` is not installed: read `ProjectSettings/ProjectVersion.txt`, `Packages/manifest.json`, and `find . -name "*.asmdef"` directly.

1. **unilyze snapshot** — static analysis.
   ```bash
   mkdir -p <project>/.unity-review/snapshots
   unilyze -f json -p <project> -o <project>/.unity-review/snapshots/triage.json
   ```
   Then get the one-liner:
   ```bash
   unilyze statusline -i <project>/.unity-review/snapshots/triage.json
   ```
   If `unilyze` is not installed: count `.cs` files with `find . -name "*.cs" -not -path "*/Packages/*" | wc -l`, skim a few large files, and note "unilyze not available — metrics are estimates" in the scorecard.

2. **File structure scan** — gather signals the tools do not cover.
   - Count of `.asmdef` files and their dependency graph shape (flat? layered? circular?)
   - Presence of `Tests/` or `*Tests.asmdef` — EditMode, PlayMode, or both?
   - Presence of `.github/workflows/` or other CI config
   - Presence of `.editorconfig`, `Directory.Build.props`, or custom analyzers
   - Check `.editorconfig` for unused-code diagnostics: `resharper_unused_type_global_highlighting`, `resharper_unused_member_global_highlighting`. Their absence means dead code accumulates silently and should be flagged as a risk.
   - Presence of `Packages/com.unity.test-framework` in manifest.json

3. **Open issues** — if the repo is on GitHub:
   ```bash
   gh issue list --state open --limit 20 --json number,title,labels
   ```

4. **Cross-reference** — map the unilyze JSON to the scorecard template below. Flag any metric that crosses a threshold as `alert` or `warning`.

## Scorecard

Write the scorecard to `<project>/.unity-review/report/triage-scorecard.md`:

```markdown
# Unity Review — Triage Scorecard

## Project Profile
| Item | Value |
|------|-------|
| Unity version | |
| Render Pipeline | |
| Scripting Backend | |
| App type | |
| .NET target | |
| XR stack | |
| Multiplayer | |
| .editorconfig diagnostics | configured / partial / missing |

## CodeHealth Summary
| Metric | Value | Rating |
|--------|-------|--------|
| Average CodeHealth | | |
| Worst decile CodeHealth | | |
| LOC-weighted avg CodeHealth | | |
| Types analyzed | | — |
| Critical smells | | — |
| energyPressure | | |

## Assembly Structure
| Assembly | Types | Avg CH | DfMS | Instability | Flag |
|----------|-------|--------|------|-------------|------|
| | | | | | |

## Test Posture
| Category | Status |
|----------|--------|
| EditMode test assembly | ✓ / ✗ |
| PlayMode test assembly | ✓ / ✗ |
| Test count (if available) | |
| CI pipeline | ✓ type / ✗ |

## Top 3 Risks
1. [alert/warning] (one sentence)
2. [alert/warning] (one sentence)
3. [alert/warning] (one sentence)

## Open Questions
- (things you cannot determine from code alone)

## Next Phase
- (which unity-review-* skill to run next, and on which assemblies)
```

Keep the entire report under 300 lines. If you find yourself writing more, you are analyzing instead of triaging.

## Rating thresholds

Use these thresholds for the Rating column. They come from unilyze's metric definitions.

### CodeHealth (per type, 1.0–10.0, higher is better)

| Rating | Range | Meaning |
|--------|-------|---------|
| healthy | >= 9.0 | No action needed |
| warning | 4.0–8.9 | Review recommended |
| alert | < 4.0 | Immediate attention |

### Critical smell thresholds

| Smell | Threshold | Critical threshold |
|-------|-----------|-------------------|
| GodClass | lines >= 500 OR methods >= 20 | lines >= 1000 |
| LongMethod | lines >= 80 OR CogCC >= 25 | lines >= 150 OR CogCC >= 40 |
| HighComplexity | CycCC >= 15 OR CogCC >= 15 | — |
| LowCohesion | LCOM-HS >= 0.8 | — |
| HighCoupling | CBO >= 20 | — |

### Assembly metrics

| Metric | Ideal | Acceptable | Zone of pain |
|--------|-------|------------|--------------|
| DfMS (Distance from Main Sequence) | < 0.15 | 0.15–0.4 | > 0.4 |
| Instability (with high Ca) | 0.0–0.3 | 0.3–0.7 | > 0.7 with Ca > 5 |

### energyPressure (Unity hot-path smell density)

| Rating | Range |
|--------|-------|
| healthy | < 0.05 |
| warning | 0.05–0.15 |
| alert | > 0.15 |

## Boundaries

- Do NOT propose refactoring steps. Each risk in "Top 3 Risks" is one sentence stating the problem, not a solution.
- Do NOT run `unilyze diff`, `unilyze hotspot`, or `unilyze dup` — those belong to `review-metrics`, `review-hotspot`, and `review-duplication`.
- Do NOT modify any project files except those under `<project>/.unity-review/`.
- Do NOT open Unity Editor. This is an offline assessment.
- Do NOT run tests. That is `review-testing`'s job.
- Do NOT review individual source files in depth. That is `review-metrics`'s job with `unilyze query --worst`.

## Related

Triage determines which of these skills to run next. List them in "Next Phase" by name.

- `review-metrics` — deep-dive into unilyze metrics per type, with `unilyze query --worst` evidence packs
- `review-architecture` — asmdef dependency graph, DfMS outliers, cyclic dependencies
- `review-hotspot` — git churn × complexity via `unilyze hotspot`
- `review-duplication` — code clone detection via `unilyze dup`
- `review-performance` — Unity hot-path smells, GC allocation patterns, Cysharp optimization patterns
- `review-safety` — async/exception/disposal safety smells
- `review-testing` — test posture assessment, coverage strategy
- `review-unity-specific` — Prefab Variant YAML traps, ARFoundation lifecycle, XR plugin switching
- `review-weekly` — orchestrator that runs all of the above and diffs against the previous week
