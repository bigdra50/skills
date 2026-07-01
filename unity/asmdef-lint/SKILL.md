---
name: asmdef-lint
description: >-
  Validate Unity Assembly Definition (.asmdef) structure — naming conventions,
  dependency direction, missing test assemblies, versionDefines for optional
  packages, and rootNamespace alignment. Run as a quick pre-commit or PR check.
---

# asmdef Lint

Static structural checks over a project's `.asmdef` files. Cheap enough for a pre-commit hook, catches the assembly-layout mistakes that compile fine but rot the dependency graph. Flags only — it never rewrites assemblies.

`.asmdef` files are JSON, so every check is a `jq` one-liner. `references` may contain either assembly names or `GUID:...` strings depending on the "Use GUIDs" project setting; these checks assume name references (the readable default). If a project uses GUID references, resolve them first or the direction check under-reports.

## Checks

Each rule has a detection command. Run from the project root.

### naming — asmdef name should match its directory path

`App.Domain` should live in a folder ending `App/Domain/`. Mismatches make the graph unreadable.

```bash
find Assets -name '*.asmdef' | while read -r f; do
  name=$(jq -r .name "$f"); dir=$(dirname "$f" | sed 's#.*/Assets/##; s#/#.#g')
  case "$dir" in *"$name") ;; *) echo "$f: [naming] name '$name' != path '$dir'";; esac
done
```

### rootNamespace — must equal the asmdef name

Keeps the C# namespace and assembly aligned; an empty or divergent `rootNamespace` lets files drift into the wrong namespace.

```bash
find Assets -name '*.asmdef' | while read -r f; do
  n=$(jq -r .name "$f"); r=$(jq -r '.rootNamespace // ""' "$f")
  [ "$n" = "$r" ] || echo "$f: [rootNamespace] '$r' != name '$n'"
done
```

### dependency-direction — inner layers must not reference outer

`Domain` must not reference `Presentation`/`Infrastructure`; `UseCase` must not reference `Presentation`. Detect forbidden edges:

```bash
find Assets -name '*.asmdef' | while read -r f; do
  jq -r '.name as $n | .references[]? | "\($n) -> \(.)"' "$f"
done | grep -E 'Domain ->.*(Presentation|Infrastructure)|UseCase ->.*Presentation' \
  && echo "[dependency-direction] outward reference above"
```

### missing-test-assembly — each production asmdef should have a `*.Tests.asmdef`

Test assemblies are marked by `overrideReferences: true` + `precompiledReferences: ["nunit.framework.dll"]` and a reference to `UnityEngine.TestRunner` (there is no `testAssemblies` field in the schema — that flag is legacy).

```bash
find Assets -name '*.asmdef' ! -name '*.Tests.asmdef' | while read -r f; do
  n=$(jq -r .name "$f")
  find Assets -name '*.Tests.asmdef' -exec jq -r .name {} \; | grep -q "^$n\.Tests$" \
    || echo "$f: [missing-test-assembly] no ${n}.Tests found"
done
```

### versionDefines — optional SDK packages must be guarded

Optional packages (XR, Addressables, Burst) should appear under `versionDefines` with a compile guard, never as an unconditional `references` entry — otherwise the assembly won't compile when the package is absent.

```bash
find Assets -name '*.asmdef' -exec sh -c \
  'jq -e ".references[]? | select(test(\"XR|Addressables|Burst\"))" "$1" >/dev/null \
   && echo "$1: [versionDefines] optional package hard-referenced; move to versionDefines"' _ {} \;
```

### autoReferenced — production assemblies should set `autoReferenced: false`

Explicit dependency control; `true` (or absent, which defaults to `true`) lets any assembly implicitly pull this one.

```bash
find Assets -name '*.asmdef' ! -name '*.Tests.asmdef' -exec sh -c \
  'jq -e ".autoReferenced == false" "$1" >/dev/null || echo "$1: [autoReferenced] not set to false"' _ {} \;
```

### test-define-constraint — test assemblies need `UNITY_INCLUDE_TESTS`

Without it, test code ships into non-test builds.

```bash
find Assets -name '*.Tests.asmdef' -exec sh -c \
  'jq -e ".defineConstraints[]? | select(. == \"UNITY_INCLUDE_TESTS\")" "$1" >/dev/null \
   || echo "$1: [test-define-constraint] missing UNITY_INCLUDE_TESTS"' _ {} \;
```

## Quick scan

The two highest-signal checks (direction + missing tests) as one pass — run this first, it catches the mistakes that actually break architecture:

```bash
find Assets -name '*.asmdef' | while read -r f; do
  jq -r '.name as $n | .references[]? | "\($n) -> \(.)"' "$f"
done | grep -E 'Domain ->.*(Presentation|Infrastructure)|UseCase ->.*Presentation'
```

## Output

Collect findings into a violations table, ordered severity-first:

```markdown
| asmdef | Rule | Severity |
|--------|------|----------|
| Assets/App/Domain/App.Domain.asmdef | dependency-direction | error |
| Assets/App/UseCase/App.UseCase.asmdef | missing-test-assembly | warning |
| Assets/App/Infra/App.Infrastructure.asmdef | autoReferenced | info |
```

Severity: `dependency-direction` and `versionDefines` are errors (break the graph or the build); `missing-test-assembly` and `rootNamespace` are warnings; `autoReferenced` and `naming` are info.

## Boundaries

- Do NOT restructure assemblies or edit `.asmdef` files. Flag only; moving types between assemblies is `unity-review/review-architecture` + a human decision.
- Do NOT evaluate code quality, per-type metrics, or coupling numbers — that is `unity-review/review-metrics`.
- Do NOT resolve GUID references or run the Unity editor. This is a static text/JSON pass; if a project uses GUID references, note it and defer the direction check.
