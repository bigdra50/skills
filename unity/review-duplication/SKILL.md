---
name: review-duplication
description: >-
  Detect and classify code clones with `unilyze dup` (token-normalized Type-2/3
  clone detection). For each clone group, decide Extract Method, Extract Base
  Class, move to a shared asmdef, or accept as intentional. Does NOT refactor and
  does NOT evaluate non-duplication metrics — those are refactor-loop and
  review-metrics. Use when review-triage suspects copy-paste is inflating size.
---

# Unity Review — Duplication

You are finding and classifying clones. Output is a clone-group table with a decision per group. You do not extract anything — naming the correct treatment (and, importantly, which clones to *leave alone*) is the deliverable.

Run `review-triage` first. This skill is worth running when triage saw several types with size-penalty CodeHealth drops that look like copy-paste, or when a `review-hotspot` result is hot because the same logic is duplicated across files.

## Procedure

`unilyze dup` re-scans the source (token-normalized), so it does not consume `triage.json`.

1. **Detect clone groups:**
   ```bash
   unilyze dup -p <project> > <project>/.unity-review/report/clones.md
   ```

2. **Read every clone group's source.** The report gives file:line spans. Open each span. You cannot classify a clone you have not read — token similarity does not tell you whether the duplication is business logic or boilerplate.

3. **Classify** each group against the tables below.

## What unilyze dup finds

Detection is token-normalized, so it catches beyond exact copies:

| Clone type | Definition | Caught? |
|------------|-----------|---------|
| Type-1 | Identical text (whitespace/comments aside) | yes |
| Type-2 | Same structure, renamed identifiers/literals | yes |
| Type-3 | Type-2 plus a few added/removed/changed statements | yes (above the gap threshold) |
| Type-4 | Same behavior, different implementation | no (out of scope) |

## Classification

Decide the treatment from four inputs: clone **size** (lines), clone **count** (how many copies), whether the group **crosses asmdef boundaries**, and whether the code is **boilerplate vs business logic**.

| Situation | Decision |
|-----------|----------|
| Small (< 10 lines), business logic, same asmdef | Extract Method into the owning type |
| Medium/large, business logic, ≥ 3 copies, same asmdef | Extract Base Class or shared helper |
| Any size, duplicated **across** asmdefs | Move to a shared/common asmdef, then reference it |
| Boilerplate the compiler/generator will re-emit (serialization, INotifyPropertyChanged, generated glue) | Accept — extraction adds indirection for no behavior win |
| Test arrange/setup blocks | Extract a test fixture/builder, not production code |
| Two clones that are *coincidentally* similar but change for different reasons | Accept — merging them couples unrelated code |

The two "Accept" rows matter as much as the extract rows. DRY-ing a coincidental clone creates a false abstraction that two future changes will fight over — the mechanical cost is a shared method sprouting boolean flags to serve both callers. State the reason when you accept a group.

### Crossing asmdef boundaries

A clone spanning assemblies is the highest-value finding: it means neither assembly can own the logic and the copies will drift. But the fix (a new shared asmdef) has a real cost — an extra assembly, a new reference edge, possible cycle risk. Flag it here; whether the shared asmdef is worth it is a `review-architecture` call.

## Output

Write to `<project>/.unity-review/report/duplication-findings.md`:

```markdown
# Duplication Findings

| Group | Lines | Copies | Locations | Crosses asmdef? | Kind | Decision |
|-------|-------|--------|-----------|-----------------|------|----------|
| 1 | 34 | 4 | Battle/*.cs (4 files) | no | business logic | Extract Base Class |
| 2 | 12 | 2 | Core.asmdef, UI.asmdef | yes | business logic | Move to shared asmdef (confirm w/ review-architecture) |
| 3 | 18 | 6 | generated View glue | no | boilerplate | Accept — codegen re-emits it |
```

Rank by (crosses-asmdef, then lines × copies) descending. Cap at the top clone groups; a wall of 2-copy 5-line clones is noise, not a finding.

## Boundaries

- Do NOT refactor. This skill classifies clones; `refactor-loop` extracts them. Extracting mid-review changes the token stream and the next `unilyze dup` run no longer matches this report.
- Do NOT evaluate non-duplication metrics (CodeHealth, CogCC, coupling, DfMS). Those are `review-metrics` and `review-architecture`. Duplication is one lens; do not smuggle in others.
- Do NOT create the shared asmdef yourself. Flag the cross-boundary clone; the assembly-structure decision is `review-architecture`'s.
- Do NOT DRY boilerplate or coincidental clones just because the tool grouped them. False abstractions are worse than the duplication.

## Related

- `review-triage` — entry point; its size-penalty flags suggest whether clones are inflating types
- `review-metrics` — non-duplication per-type metrics on the same types
- `review-architecture` — owns the "should this become a shared asmdef" decision for cross-boundary clones
- `review-hotspot` — a hotspot that is hot because of copy-paste routes here
- `refactor-loop` — executes the Extract Method / Extract Base Class this skill only decides
