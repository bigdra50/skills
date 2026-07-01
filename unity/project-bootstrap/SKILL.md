---
name: project-bootstrap
description: >-
  One-shot setup checklist for a new Unity project — asmdef structure,
  .editorconfig, .gitignore, CI pipeline, unilyze baseline, and recommended
  packages. Use at Day 0 of a new project or when standardizing an existing one.
---

# Unity Project Bootstrap

A Day 0 checklist that lays down the assembly structure, editor config, ignore rules, CI, and a code-health baseline. Run it once on a fresh project, or against an existing project to bring it up to the standard layout. Everything here is a template to copy and adapt — none of it is enforced automatically.

## When to invoke

- Starting a new Unity project and you want the structure right before the first feature lands.
- Standardizing an inherited project that grew without an assembly layout or CI.
- Establishing a unilyze baseline so future PRs can gate on regression.

## asmdef structure template

A layered structure with dependencies pointing inward (outer layers reference inner, never the reverse):

```
Assets/
  App/
    Domain/          App.Domain.asmdef          (no Unity references, no outward refs)
    UseCase/         App.UseCase.asmdef          (references Domain)
    Infrastructure/  App.Infrastructure.asmdef   (references UseCase, Domain via interfaces)
    Presentation/    App.Presentation.asmdef     (references UseCase, Domain)
  Tests/
    Domain.Tests/          App.Domain.Tests.asmdef
    UseCase.Tests/         App.UseCase.Tests.asmdef
    Infrastructure.Tests/  App.Infrastructure.Tests.asmdef
```

Set on every production asmdef: `rootNamespace` = the asmdef name, `autoReferenced: false`, `noEngineReferences: true` on `Domain`. Each `*.Tests.asmdef` sets `overrideReferences: true`, `precompiledReferences: ["nunit.framework.dll"]`, and `defineConstraints: ["UNITY_INCLUDE_TESTS"]`. Validate with the `asmdef-lint` skill after creating them.

## .editorconfig

Drop at the repo root. The ReSharper/Rider diagnostics turn unused code into build-visible warnings:

```ini
root = true

[*.cs]
indent_style = space
indent_size = 4
charset = utf-8-bom
trim_trailing_whitespace = true
insert_final_newline = true

# ReSharper / Rider unused-code diagnostics
resharper_unused_member_global_highlighting = warning
resharper_unused_field_global_highlighting = warning
resharper_unused_parameter_global_highlighting = warning
dotnet_diagnostic.IDE0051.severity = warning   # unused private member
dotnet_diagnostic.IDE0060.severity = warning   # unused parameter
```

## .gitignore

Unity-specific ignores — never commit generated project files or the import cache:

```gitignore
[Ll]ibrary/
[Tt]emp/
[Oo]bj/
[Bb]uild/
[Bb]uilds/
[Ll]ogs/
[Uu]serSettings/
*.csproj
*.sln
*.user
.vs/
.idea/
*.apk
*.aab
# Keep meta files for tracked assets — do NOT ignore *.meta
```

Use Git LFS for binary assets (textures, models, audio); add a `.gitattributes` tracking `*.png`, `*.fbx`, `*.wav`, etc.

## Recommended packages

Choose by project type. `required` = install now; `recommended` = default yes; `optional` = per feature; `skip` = don't add:

| Package | mobile-game | xr-app | enterprise | sdk |
|---------|-------------|--------|------------|-----|
| com.unity.test-framework | required | required | required | required |
| com.unity.inputsystem | recommended | recommended | optional | skip |
| com.unity.addressables | recommended | optional | optional | skip |
| com.unity.xr.management | skip | required | skip | skip |
| com.unity.render-pipelines.universal | recommended | recommended | optional | skip |
| com.unity.burst | optional | recommended | optional | skip |

An `sdk` project stays dependency-light so consumers aren't forced to pull transitive packages; gate anything optional behind `versionDefines` (see `asmdef-lint`).

## unilyze baseline

Capture a code-health snapshot at Day 0 so later PRs can diff against it. Commit the snapshot as the baseline; the CI quality gate (see below) diffs each PR's snapshot against it:

```bash
mkdir -p .unity-review/snapshots
unilyze -f json -p . -o .unity-review/snapshots/baseline.json
git add .unity-review/snapshots/baseline.json
```

Later runs compare with `unilyze diff .unity-review/snapshots/baseline.json <new>.json`. Refresh the baseline deliberately (not per-PR) when the team accepts a new floor.

## CI template

Add the GitHub Actions pipeline from the `unity-ci` skill: compile + EditMode/PlayMode tests + the unilyze quality gate on PRs, and a platform build matrix on push. Wire the gate as a required status check in branch protection so a regression blocks merge.

## Day 0 checklist

```markdown
- [ ] Layered asmdef structure created (Domain / UseCase / Infrastructure / Presentation)
- [ ] rootNamespace + autoReferenced:false set on every production asmdef
- [ ] *.Tests.asmdef created for each layer with UNITY_INCLUDE_TESTS constraint
- [ ] asmdef-lint passes (quick scan clean)
- [ ] .editorconfig at repo root
- [ ] .gitignore + .gitattributes (LFS) committed; *.meta files tracked
- [ ] Packages installed per project-type table
- [ ] unilyze baseline snapshot committed
- [ ] unity-ci workflow added; quality gate set as required status check
- [ ] Unity version pinned in ProjectVersion.txt and referenced in CI
```

## Boundaries

- Do NOT scaffold gameplay/domain code — this sets up structure, not features.
- Do NOT restructure an existing project's assemblies wholesale; introduce the layout incrementally and let `asmdef-lint` flag drift.

## Related skills

- `unity-dev/asmdef-lint` — validates the assembly structure this skill lays down.
- `devops/unity-ci` — the CI pipeline referenced above.
- `unity-review/review-triage` — Day 0 scorecard once the project has code to measure.
