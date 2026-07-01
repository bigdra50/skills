---
name: review-hotspot
description: >-
  Identify refactoring priorities by crossing git churn with code complexity via
  `unilyze hotspot`. Answers WHERE to focus, ranked, not WHAT to change. Does NOT
  refactor and does NOT analyze clone patterns — those are refactor-loop and
  review-duplication. Use after review-triage flags a large or fast-moving
  codebase where "which type first" is the open question.
---

# Unity Review — Hotspot

You are ranking *where* engineering attention pays off, by multiplying how often code changes (git churn) by how hard it is to change (complexity). A complex file nobody touches is cheap to leave alone; a complex file touched every week is where bugs and slowdowns compound. Output is a priority-ranked table, never a change.

Run `review-triage` first. Hotspot is worth running when the repo has real git history (dozens+ of commits) and triage flagged more alert-level types than one review pass can address — the ranking decides the order.

## Procedure

Hotspot reads git history directly, so it does **not** consume `triage.json` — it computes churn from the repo. It does need a git checkout with history (not a shallow `--depth 1` clone).

1. **Type-level hotspots** (start here):
   ```bash
   unilyze hotspot -p <project> > <project>/.unity-review/report/hotspots.md
   ```

2. **Method-level** — only drill in on the top few type-level hotspots, to find the specific method carrying the churn:
   ```bash
   unilyze hotspot -p <project> --methods
   ```

3. **Cross-reference** each top hotspot with `triage.json` CodeHealth so the priority carries a health number, then classify against the matrix.

## Interpretation matrix

Churn and complexity are two axes. The quadrant, not either number alone, sets priority.

| | Low complexity | High complexity |
|--|---------------|-----------------|
| **High churn** | Healthy active code — leave it. Frequent edits to simple code are normal iteration, not debt. | **Urgent.** Every change here is expensive and risky; this is where refactoring ROI is highest. |
| **Low churn** | Dormant and simple — ignore entirely. | Tech debt, but **not burning.** Real complexity, but nobody pays the cost right now. Defer unless a feature is about to land here. |

Priority order for the output: high-churn/high-complexity first, then low-churn/high-complexity (only if upcoming work touches it), then the rest is noise.

The trap to avoid: ranking by complexity alone. A CodeHealth 2.0 type that has not changed in two years is a worse use of a refactoring budget than a CodeHealth 5.0 type edited in half the recent commits — because refactoring the dormant one risks regressions for zero delivery benefit.

## Tuning the churn signal

Raw commit count can mislead. Sanity-check two things before trusting the ranking:

| Distortion | Symptom | Correction |
|------------|---------|------------|
| Generated / vendored files | Auto-generated `.cs`, imported SDK, `Packages/` copies top the churn list | Exclude them; a bulk-regenerated file is not a refactoring target |
| Bulk reformat / rename commits | One commit touches hundreds of files at once | Those inflate churn without reflecting real change pressure — discount them |
| Churn window | An old rewrite dominates over steady recent edits | Prefer recent churn (last N months) when the question is "what is moving *now*" |

If the churn window matters to the decision, note in the report which window the ranking used — a 2-year window and a 3-month window can invert the top of the list.

## Output

Write to `<project>/.unity-review/report/hotspot-findings.md`:

```markdown
# Hotspot Findings

| Rank | Type / Method | File | Churn (commits) | Complexity (CogCC) | CodeHealth | Quadrant | Next skill |
|------|---------------|------|-----------------|--------------------|-----------|----------|------------|
| 1 | BattleSystem.Resolve | Assets/Game/Battle/BattleSystem.cs | 41 | 38 | 2.9 | high/high | review-metrics → refactor-loop |
| 2 | SaveManager | Assets/Game/IO/SaveManager.cs | 6 | 44 | 3.4 | low/high | defer (no active work) |
```

Rank by the high/high quadrant first. The "Next skill" column routes each urgent hotspot: send it to `review-metrics` for strategy classification, or straight to `refactor-loop` if the strategy is already obvious. This skill points; it does not act.

## Boundaries

- Do NOT refactor. Hotspot names the priority; `refactor-loop` executes it. Editing here means the churn baseline the ranking was built on immediately shifts and the ranking becomes a lie.
- Do NOT analyze clone/duplication patterns. Two hotspots that look similar are a `review-duplication` question — `unilyze dup` classifies clones properly; eyeballing them here produces false pairs.
- Do NOT classify smells or name refactoring strategies. That is `review-metrics`. This skill only decides order.
- Do NOT run on a shallow clone. Truncated history skews churn toward recently-cloned files; confirm full history first.

## Related

- `review-triage` — entry point; its alert list is what this skill orders
- `review-metrics` — destination for each urgent hotspot; classifies the smell and names the strategy
- `review-duplication` — for hotspots that are hot because the same logic is copy-pasted
- `review-architecture` — if the hotspots cluster in one zone-of-pain assembly, the fix may be structural
- `refactor-loop` — executes the top-ranked hotspots this skill surfaces
