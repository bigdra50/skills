---
name: review-weekly
description: >-
  Weekly orchestrator for the unity-review system. Runs all observation
  skills in order, dispatches perspective agents in parallel, diffs
  against the previous week's snapshot, and produces a weekly report
  with KPI ratchet.
---

# Unity Review — Weekly Orchestrator

You coordinate a full weekly review of a Unity project. You run the observation skills, dispatch the perspective agents, diff against last week, and write one report. You do NOT fix code — you dispatch and aggregate.

Set `<project>` to the project root and `<date>` to today (`YYYY-MM-DD`) before starting.

## Phase 1 — Observation (sequential)

Each observation skill builds on the triage output, so run them in order, not in parallel. Each writes to `<project>/.unity-review/report/`.

1. `review-triage` — skip only if a scorecard already exists from this session; otherwise run it, it seeds the snapshot and project profile.
2. `review-metrics` — per-type CodeHealth deep-dive with `unilyze query --worst` evidence.
3. `review-architecture` — asmdef dependency graph, DfMS outliers, cycles.
4. `review-hotspot` — git churn × complexity via `unilyze hotspot`.
5. `review-duplication` — clone detection via `unilyze dup`.
6. `review-performance` — hot-path smells, GC allocation patterns.
7. `review-safety` — async / exception / disposal safety smells.
8. `review-testing` — test posture and coverage strategy.
9. `review-unity-specific` — Prefab Variant YAML traps, ARFoundation lifecycle, XR plugin switching.

Save this week's snapshot: `unilyze -f json -p <project> -o <project>/.unity-review/snapshots/<date>.json`.

## Phase 2 — Perspectives (parallel)

Dispatch these as parallel subagents via the Agent tool — they are independent and must not run sequentially. Each reads the Phase 1 outputs under `<project>/.unity-review/` and returns a short section (≤40 lines), not a full report.

- `unity-architect`
- `performance-engineer`
- `xr-specialist` — **skip** if triage detected no XR stack. If dispatched anyway, it self-skips and returns one line.
- `test-engineer`

Send all four (or three) in a single message so they run concurrently. Pass each the `<project>` path and the `<date>`. Collect their returned sections for Phase 4.

## Phase 3 — Diff against last week

Find the most recent prior snapshot in `<project>/.unity-review/snapshots/` (the newest file older than `<date>.json`). If none exists, this is week 1 — note "no prior snapshot; baseline week" and skip the diff.

```bash
unilyze diff <previous-snapshot.json> <project>/.unity-review/snapshots/<date>.json --changed-only
```

From the diff, extract four lists: **improved types**, **degraded types**, **new smells**, **resolved smells**. These drive the KPI table and the ratchet.

## Phase 4 — Weekly report

Write to `<project>/.unity-review/report/weekly-<date>.md`:

```markdown
# Unity Review — Weekly Report <date>

## KPI Summary
| KPI | This week | Last week | Delta | Trend |
|-----|-----------|-----------|-------|-------|
| Average CodeHealth | | | | ↑/↓/→ |
| Worst decile CodeHealth | | | | |
| Critical smells | | | | |
| energyPressure | | | | |
| Test-covered hotspots | | | | |

## Observation Findings
(Aggregated from all Phase 1 skills, deduplicated. Group by area, one line each.)

## Perspective Insights
### Unity Architect
### Performance Engineer
### XR Specialist        (omit if skipped)
### Test Engineer

## Ratchet
(For each KPI that improved, the new value becomes the floor. List the floors.
Flag any KPI that regressed below its established floor as a [ratchet-break].)

## Action Items (top 5)
(Ordered by risk × effort. Each: what, which assembly/type, which skill owns the fix.)
```

### Ratchet rule

When a KPI improves, its new value becomes the floor for next week. A later regression below that floor is a `[ratchet-break]` and goes to the top of Action Items. Persist the floors so next week can compare (keep them in the report's Ratchet section — the newest weekly report is the source of truth for current floors).

## Snapshot management

- Save each week's snapshot as `<project>/.unity-review/snapshots/<date>.json`.
- Keep the last 4 weeks for trend comparison; older snapshots can be pruned.
- Reuse this session's triage snapshot if it was created in the same run — do not re-snapshot.

## Boundaries

- Do NOT fix code. You dispatch and aggregate; fixes are a separate, human-approved pass.
- Do NOT skip observation skills without an explicit user request.
- Do NOT run the perspectives sequentially — they are independent and must be parallel.
- Do NOT let the report sprawl. KPI table + deduped findings + perspective sections + 5 action items. If it exceeds ~250 lines, you are analyzing instead of reporting.

## Related

- `review-triage` … `review-unity-specific` — the observation skills invoked in Phase 1
- `unity-architect`, `performance-engineer`, `xr-specialist`, `test-engineer` — the Phase 2 perspective agents
