---
name: review-metrics
description: >-
  Deep-dive into per-type CodeHealth metrics from a unilyze snapshot. Pulls
  evidence packs for the worst types with `unilyze query --worst`, reads their
  source, and classifies each finding into a refactoring strategy or a
  downstream review skill. Does NOT refactor, does NOT run hotspot/dup, and does
  NOT evaluate assembly-level metrics — those belong to other unity-review skills.
---

# Unity Review — Metrics

You are doing a per-type metric deep-dive. Your output is a classified findings table, not code changes. This skill turns raw CodeHealth numbers into "which type, which smell, which strategy or which next skill" — nothing more.

Run `review-triage` first. Triage decides whether this skill is worth running and on which assemblies. If triage flagged no type below CodeHealth 8.9, skip this skill.

## Procedure

1. **Reuse the triage snapshot if it exists**, otherwise take a fresh one.
   ```bash
   SNAP=<project>/.unity-review/snapshots/triage.json
   test -f "$SNAP" || unilyze -f json -p <project> -o "$SNAP"
   ```

2. **Pull evidence packs for the worst types.**
   ```bash
   unilyze query --worst 10 -i "$SNAP" > <project>/.unity-review/report/worst-types.md
   ```
   Add `--include-api-surface` only for types you suspect leak too much (public method/field count, doc signatures):
   ```bash
   unilyze query --worst 10 -i "$SNAP" --include-api-surface
   ```

3. **Read the source of each worst type.** The evidence pack names the file and line ranges. Open them. Do not classify a smell you have not read the code behind — the metric tells you *where*, the source tells you *what*.

4. **Classify** each type against the tables below and write the findings table.

## CodeHealth v2 — how to read the score

CodeHealth is 1.0–10.0 (higher is better) built from three **non-compensatory** penalty dimensions. Non-compensatory means a strong dimension cannot rescue a weak one — the worst dimension dominates the final score. A type with perfect cohesion but CogCC 60 is still an alert; do not average the dimensions in your head.

| Dimension | Driven by | What a heavy penalty signals |
|-----------|-----------|------------------------------|
| Complexity penalty | CogCC, CycCC | Branching/nesting too dense to hold in one head |
| Size penalty | WMC, lines, method count | Too many responsibilities in one type |
| Interface penalty | RFC, CBO, public surface | Type touches / is touched by too much |

Read the dimension with the largest penalty first — that names the primary problem. A low score with a balanced spread across all three usually means GodClass (split it); a low score spiking on one dimension points at a single targeted strategy.

## Judgment criteria — structural smells

For structural smells, map the smell to a refactoring **strategy name**. Do not describe the refactoring here; naming the strategy is the deliverable, execution is `refactor-loop`'s job.

| Smell | Trigger (see triage thresholds) | Strategy to recommend |
|-------|--------------------------------|-----------------------|
| GodClass | lines ≥ 500 or methods ≥ 20 | Extract Class (split by field-usage cluster) |
| LongMethod | lines ≥ 80 or CogCC ≥ 25 | Extract Method + Decompose Conditional |
| HighComplexity | CycCC ≥ 15 or CogCC ≥ 15 | Replace Conditional with Polymorphism |
| DeepNesting | nesting depth ≥ 4 | Replace Nested Conditional with Guard Clauses |
| LowCohesion | LCOM-HS ≥ 0.8 | Extract Class along cohesion clusters |
| HighCoupling | CBO ≥ 20 | Introduce Interface / Dependency Inversion |
| DeepInheritance | DIT ≥ 5 | Replace Inheritance with Delegation |
| LowMaintainability | composite | Route to `review-hotspot` to prioritize before touching |

## Judgment criteria — delegated smells

These are real findings but are not classified here. Record the type + smell in the findings table and set the suggested skill column. Do not open the perf/safety refactoring yourself.

| Smell group | Members | Suggested skill |
|-------------|---------|-----------------|
| Hot-path allocation | BoxingAllocation, ClosureCapture, ParamsArrayAllocation, CollectionAllocationInHotPath, StringConcatenationInHotPath, LinqInHotPath, ExpensiveUnityApiInHotPath, WeakTemporization | `review-performance` |
| Async / exception / disposal | AsyncVoidMethod, BlockingTaskWait, CatchAllException, MissingInnerException, ThrowingSystemException | `review-safety` |
| DOTS / ECS | MissingBurstCompile, ManagedReferenceInComponentData | `review-unity-specific` |
| Dependency cycle | CyclicDependency | `review-architecture` |

## Output

Write to `<project>/.unity-review/report/metrics-findings.md`:

```markdown
# Metrics Findings

| Type | Assembly | CodeHealth | Dominant dimension | Primary smell | Strategy / Next skill |
|------|----------|-----------|--------------------|---------------|-----------------------|
| PlayerController | Game.Runtime | 3.2 | complexity | HighComplexity | Replace Conditional with Polymorphism |
| SaveManager | Game.IO | 4.1 | size | GodClass | Extract Class |
| FrameLogger | Game.Debug | 5.8 | — | BoxingAllocation | review-performance |
```

Rank by CodeHealth ascending. Cap at the worst 10–15 rows; if you are writing more, you are cataloguing instead of triaging.

## Supplementary: ReSharper CLI

When `jb inspectcode` is available, use it as a second static-analysis source alongside unilyze. The two tools have different blind spots — unilyze is metric-and-smell-based, ReSharper is rule-and-pattern-based.

```bash
jb inspectcode <solution>.sln \
  --no-build \
  -e=WARNING \
  -o=results.sarif
```

Unity projects require `--no-build` (standard MSBuild cannot build Unity). Add `-s=<solution>.sln.DotSettings` if it exists.

Parse results:
```bash
jq '.runs[0].results[] | {ruleId, message: .message.text, uri: .locations[0].physicalLocation.artifactLocation.uri, line: .locations[0].physicalLocation.region.startLine}' results.sarif
```

Merge ReSharper findings into the same findings table. If both tools flag the same type, list both — they diagnose different aspects. Clean up `results.sarif` after extraction.

If `jb` is not installed, skip this section — unilyze alone is sufficient for the findings table.

## Boundaries

- Do NOT refactor. This skill names strategies; `refactor-loop` executes them. Editing here means the findings table and the diff drift apart and neither can be trusted.
- Do NOT run `unilyze hotspot` or `unilyze dup`. Churn priority is `review-hotspot`; clone detection is `review-duplication`. Running them here duplicates their snapshots and splits their reports.
- Do NOT read or judge assembly-level metrics (Abstractness, DfMS, Relational Cohesion). Per-type CBO/Ca/Ce are in scope; asmdef structure is `review-architecture`.
- Do NOT re-derive triage's scorecard. Consume `triage.json`; do not re-run project metadata.

## Related

- `review-triage` — entry point; decides whether this skill runs and on which assemblies
- `review-architecture` — assembly-level metrics and CyclicDependency findings
- `review-hotspot` — cross complexity with git churn to prioritize the findings here
- `review-duplication` — clone groups (a different lens on the same types)
- `review-performance` / `review-safety` / `review-unity-specific` — destinations for delegated smells
- `refactor-loop` — executes the strategies this skill only names
