---
name: review-architecture
description: >-
  Evaluate assembly (asmdef) structure from a unilyze snapshot — dependency
  direction, DfMS outliers on the Main Sequence, cyclic dependencies, and layer
  separation. Cross-checks the snapshot's assemblies[] against the raw .asmdef
  reference lists. Does NOT evaluate per-type metrics and does NOT restructure or
  rewrite assemblies — those belong to review-metrics and refactor-loop.
---

# Unity Review — Architecture

You are assessing the assembly graph, not individual types. Output is an assembly map, a dependency-violation list, and a DfMS reading. You do not move types between assemblies or edit `.asmdef` files.

Run `review-triage` first. Triage's scorecard already lists each assembly's DfMS and Instability; this skill exists only when triage flags an assembly in the zone of pain, a DfMS > 0.4, or a suspected cycle.

## Procedure

1. **Reuse the triage snapshot** for the metrics.
   ```bash
   SNAP=<project>/.unity-review/snapshots/triage.json
   test -f "$SNAP" || unilyze -f json -p <project> -o "$SNAP"
   ```
   Read the `assemblies[]` array: each entry carries Abstractness, Instability, DfMS, Relational Cohesion, Ca, Ce.

2. **Read the raw dependency lists** — unilyze gives you the metrics, the `.asmdef` files give you the *intended* direction.
   ```bash
   find <project>/Assets -name "*.asmdef" -not -path "*/Tests/*" \
     -exec sh -c 'echo "== $1 =="; jq -r ".name, (.references[]?)" "$1"' _ {} \;
   ```

3. **Plot each assembly** on the Main Sequence (step below) and **check direction** against the layer rules.

## DfMS analysis — the Main Sequence

`DfMS = |Abstractness + Instability − 1|`. The ideal line is `A + I = 1`. Distance from it is the problem signal. The two failure corners are opposite ends of that line — do not conflate them.

| Zone | Abstractness | Instability | Meaning | Fix direction |
|------|-------------|-------------|---------|---------------|
| Zone of Pain | low (< 0.2) | low (< 0.3) | Concrete + heavily depended upon. Rigid: any change ripples outward. | Introduce abstractions dependents can bind to |
| Zone of Uselessness | high (> 0.7) | high (> 0.7) | Abstract but nothing depends on it. Dead abstraction. | Delete or collapse into a concrete type |
| On Main Sequence | A + I ≈ 1 | | Balanced. | Leave alone |

Flag any assembly with `DfMS > 0.4`. Instability alone is only a concern when `Ca > 5` — an unstable leaf assembly nobody depends on is fine.

## Dependency direction rules

Dependencies must point toward the more stable, more abstract layers. Inner layers must never reference outer layers. Adjust the layer names to the project's actual convention (read it from triage's profile), but the direction is invariant.

| Layer | May reference | Must NOT reference |
|-------|---------------|--------------------|
| Domain / Entities | (nothing) | UseCase, Infrastructure, Presentation |
| UseCase / Application | Domain | Infrastructure, Presentation |
| Infrastructure | Domain (via interfaces) | Presentation |
| Presentation / UI | UseCase, Domain | Infrastructure (concrete) |

A reference that points "outward" (Domain → Infrastructure, UseCase → Presentation) is a violation. Record it — do not fix it.

## Cyclic dependency detection

Two signals, cross-check both:
- The `CyclicDependency` smell in the snapshot (unilyze's assembly-graph SCC detection).
- A manual read of the `.asmdef` `references` lists: if A references B and B references A (directly or transitively), that is a cycle unilyze may report at type granularity.

```bash
unilyze query --worst 20 -i "$SNAP" | grep -i "CyclicDependency" || echo "no cyclic smell reported"
```

Report each cycle as the ordered assembly chain (`A → B → C → A`). Cycles block Burst/IL2CPP incremental builds and make assemblies un-unit-testable in isolation — that is the mechanical cost, state it.

## Output

Write to `<project>/.unity-review/report/architecture-findings.md`:

```markdown
# Architecture Findings

## Assembly map
| Assembly | Types | A | I | DfMS | Ca | Ce | Zone |
|----------|-------|---|---|------|----|----|------|

## Dependency violations
| From | To | Direction | Layer rule broken |
|------|----|-----------|-------------------|

## Cyclic dependencies
- A → B → C → A  (source: unilyze smell / asmdef read)

## Main Sequence reading
(one paragraph: which assemblies sit in pain vs uselessness, and the single worst outlier)
```

## Boundaries

- Do NOT evaluate per-type CodeHealth, CogCC, or per-type smells. Type-level analysis is `review-metrics`. Mixing the two produces a report where nobody can tell if the problem is a class or a layer.
- Do NOT restructure assemblies, move types, or edit `.asmdef` files. This skill produces the violation list; `refactor-loop` acts on it. Editing asmdefs mid-review invalidates the snapshot the findings were computed from.
- Do NOT open Unity Editor. Assembly structure is fully readable offline from the snapshot + asmdef files.

## Related

- `review-triage` — entry point; its scorecard already lists per-assembly DfMS/Instability
- `review-metrics` — per-type deep-dive; CyclicDependency smells surfaced there route back here
- `review-hotspot` — if a zone-of-pain assembly is also high-churn, prioritize it there
- `refactor-loop` — executes the assembly splits/merges this skill only identifies
