# bigdra50/skills

A collection of agent skills maintained by [@bigdra50](https://github.com/bigdra50), distributed via [APM](https://github.com/microsoft/apm).

Each directory is a standalone skill following the [agentskills.io](https://agentskills.io/specification) open standard.

## Install

Install an individual skill (global / user scope):

```sh
apm install -g bigdra50/skills/<category>/<skill-name>
```

Or declare it in `apm.yml` for a reproducible setup:

```yaml
dependencies:
  apm:
    - bigdra50/skills/<category>/<skill-name>
```

then run `apm install`.

These follow the open [Agent Skills](https://agentskills.io) format, so any
compatible agent (Claude Code, Codex, opencode, Gemini CLI, Cursor, ...) can use
them without APM:

```sh
npx skills add bigdra50/skills --skill <skill-name>
```

## Skills

### Unity

Unity/C# development and review skills. Uses [unilyze](https://github.com/bigdra50/unilyze) for static analysis and [unity-cli](https://github.com/bigdra50/unity-cli) for project metadata.

**Review system** — start with `review-triage`, then run the observation skills it recommends. Use `review-weekly` to orchestrate all review skills together.

| Skill | Install path | Description |
|---|---|---|
| [review-triage](unity/review-triage/) | `unity/review-triage` | Day 0 scorecard — CodeHealth, assembly structure, test posture, top 3 risks. |
| [review-metrics](unity/review-metrics/) | `unity/review-metrics` | Per-type metric deep-dive with unilyze evidence packs. |
| [review-architecture](unity/review-architecture/) | `unity/review-architecture` | Assembly (asmdef) structure — dependency direction, DfMS, cyclic deps. |
| [review-hotspot](unity/review-hotspot/) | `unity/review-hotspot` | Git churn x complexity refactoring priorities. |
| [review-duplication](unity/review-duplication/) | `unity/review-duplication` | Code clone detection and classification. |
| [review-performance](unity/review-performance/) | `unity/review-performance` | Unity hot-path smells, GC allocation, Burst/DOTS readiness. |
| [review-safety](unity/review-safety/) | `unity/review-safety` | Async patterns, exception handling, resource disposal. |
| [review-testing](unity/review-testing/) | `unity/review-testing` | Test posture — EditMode/PlayMode coverage, CI, test design quality. |
| [review-unity-specific](unity/review-unity-specific/) | `unity/review-unity-specific` | Unity-specific gotchas no static analyzer catches. |
| [review-weekly](unity/review-weekly/) | `unity/review-weekly` | Weekly orchestrator — runs all observation skills, dispatches perspectives, diffs KPIs. |

Perspective sub-skills (dispatched in parallel by `review-weekly`): `unity/perspectives/{unity-architect, performance-engineer, xr-specialist, test-engineer}`.

**Development skills:**

| Skill | Install path | Description |
|---|---|---|
| [asmdef-lint](unity/asmdef-lint/) | `unity/asmdef-lint` | Assembly Definition structure validation — naming, dependency direction, test assemblies. |
| [project-bootstrap](unity/project-bootstrap/) | `unity/project-bootstrap` | Day 0 project setup checklist — asmdef structure, .editorconfig, CI, unilyze baseline. |
| [visual-test](unity/visual-test/) | `unity/visual-test` | UXML resolvedStyle comparison for Figma-to-Unity visual testing. |
| [unity-playmode-test](unity/unity-playmode-test/) | `unity/unity-playmode-test` | Unity UI Toolkit PlayMode test patterns with trap avoidance. |
### 3DCG

| Skill | Install path | Description |
|---|---|---|
| [blender-export](3dcg/blender-export/) | `3dcg/blender-export` | Blender scene inspection + FBX export. |
| [blender-inspect](3dcg/blender-inspect/) | `3dcg/blender-inspect` | 3-layer Blender quality inspection with auto-fix. |

### Languages

| Skill | Install path | Description |
|---|---|---|
| [unity-csharp-guide](lang/unity-csharp-guide/) | `lang/unity-csharp-guide` | C# in Unity patterns AI gets wrong — serialization, async/await, IL2CPP, hot-path allocations, version-gated APIs. |

### Tooling

| Skill | Install path | Description |
|---|---|---|
| [unilyze-setup](tooling/unilyze-setup/) | `tooling/unilyze-setup` | Set up unilyze — first snapshot, CI integration, SARIF, badges, baselines. |
| [unity-cli-setup](tooling/unity-cli-setup/) | `tooling/unity-cli-setup` | Set up unity-cli (`u` command) — installation, relay server, instance management. |

### DevOps

| Skill | Install path | Description |
|---|---|---|
| [unity-ci](devops/unity-ci/) | `devops/unity-ci` | GitHub Actions CI/CD for Unity — GameCI, test matrix, unilyze quality gate. |

### Review

Language-agnostic code review skills. For Unity/C# projects, prefer the [Unity](#unity) review system above.

| Skill | Install path | Description |
|---|---|---|
| [multi-review](review/multi-review/) | `review/multi-review` | Multi-tool 4-perspective code review (Claude/Codex/Copilot). |
| [review-loop](review/review-loop/) | `review/review-loop` | Iterative code review loop with MUST/SHOULD/NICE convergence. |
| [plan-loop](review/plan-loop/) | `review/plan-loop` | Iterative design plan review loop. |
| [google-code-review](review/google-code-review/) | `review/google-code-review` | Google code review standards — 10 review dimensions. |

### Knowledge

| Skill | Install path | Description |
|---|---|---|
| [kb-claude-code](knowledge/kb-claude-code/) | `knowledge/kb-claude-code` | Claude Code configuration, hooks, MCP, parallel agent patterns. |
| [kb-macos](knowledge/kb-macos/) | `knowledge/kb-macos` | macOS CLI techniques (osascript, ImageMagick, sips, mDNS). |

### Workflow

| Skill | Install path | Description |
|---|---|---|
| [claude-stats](workflow/claude-stats/) | `workflow/claude-stats` | Aggregate Claude Code usage statistics. |
| [cc-worklog](workflow/cc-worklog/) | `workflow/cc-worklog` | Generate daily work reports from session logs. |
| [creating-pull-requests](workflow/creating-pull-requests/) | `workflow/creating-pull-requests` | PR creation with structured description and anti-patterns. |
| [disk-usage](workflow/disk-usage/) | `workflow/disk-usage` | Disk usage investigation and tiered cleanup. |
| [orchestrator](workflow/orchestrator/) | `workflow/orchestrator` | Multi-step task decomposition with parallel sub-tasks. |
| [pr-brief](workflow/pr-brief/) | `workflow/pr-brief` | Convert branch diff into a reviewer-friendly briefing document. |
| [report-issue](workflow/report-issue/) | `workflow/report-issue` | Create GitHub issues from conversation context. |
| [session-recap](workflow/session-recap/) | `workflow/session-recap` | Analyze past sessions and generate workflow documentation. |
| [x-research](workflow/x-research/) | `workflow/x-research` | X (Twitter) information collection via web search (no API required). |

### Docs

| Skill | Install path | Description |
|---|---|---|
| [docs-architect](docs/docs-architect/) | `docs/docs-architect` | Repository documentation structure diagnosis and prescription. |
| [html-reports](docs/html-reports/) | `docs/html-reports` | Structured HTML report management with templates. |
| [html-reports-arch](docs/html-reports-arch/) | `docs/html-reports-arch` | Architecture visualization pages for html-reports. |
| [sync-docs](docs/sync-docs/) | `docs/sync-docs` | Verify documentation against implementation code. |

### Design

| Skill | Install path | Description |
|---|---|---|
| [design-mockup](design/design-mockup/) | `design/design-mockup` | Generate interactive HTML mockups with viewport presets. |
| [drawio](design/drawio/) | `design/drawio` | Generate draw.io diagrams with cross-platform CLI export. |

### Even Realities

| Skill | Install path | Description |
|---|---|---|
| [evenhub-upload](even/evenhub-upload/) | `even/evenhub-upload` | Upload .ehpk builds to Even Hub (unofficial API). |

### Misc

| Skill | Install path | Description |
|---|---|---|
| [legacy-code-improvement](misc/legacy-code-improvement/) | `misc/legacy-code-improvement` | Legacy code improvement guide (Extract/Sprout + TDD). |

## License

Each skill may carry its own license. Skills without an explicit license default to MIT.
