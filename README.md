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

## Skills — Global

Language / domain agnostic. Install globally via `apm install -g`.

### Review

For code review, use the built-in `/code-review`; for Unity/C# projects, use the [Unity review system](#unity--c-review-system).

| Skill | Install path | Description |
|---|---|---|
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
| [compact-prep](workflow/compact-prep/) | `workflow/compact-prep` | Save session state to a temp file before /compact so recovery survives context compaction. |
| [creating-pull-requests](workflow/creating-pull-requests/) | `workflow/creating-pull-requests` | PR creation with structured description and anti-patterns. |
| [disk-usage](workflow/disk-usage/) | `workflow/disk-usage` | Disk usage investigation and tiered cleanup. |
| [fable-prompt](workflow/fable-prompt/) | `workflow/fable-prompt` | Generate self-contained, guide-compliant prompts for separate Claude Fable 5 sessions. |
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

### Misc

| Skill | Install path | Description |
|---|---|---|
| [legacy-code-improvement](misc/legacy-code-improvement/) | `misc/legacy-code-improvement` | Legacy code improvement guide (Extract/Sprout + TDD). |

## For Unity / C# Development

Unity and C# skills are **project-scoped** — install them per-project, not globally.

### Setup

Add to your Unity project's `apm.yml`:

```yaml
name: my-unity-project
version: 1.0.0
targets:
  - claude
dependencies:
  apm:
    # Review system — start with review-triage
    - bigdra50/skills/unity/review-triage
    - bigdra50/skills/unity/review-metrics
    - bigdra50/skills/unity/review-architecture
    - bigdra50/skills/unity/review-hotspot
    - bigdra50/skills/unity/review-duplication
    - bigdra50/skills/unity/review-performance
    - bigdra50/skills/unity/review-safety
    - bigdra50/skills/unity/review-testing
    - bigdra50/skills/unity/review-unity-specific
    - bigdra50/skills/unity/review-weekly
    - bigdra50/skills/unity/perspectives/unity-architect
    - bigdra50/skills/unity/perspectives/performance-engineer
    - bigdra50/skills/unity/perspectives/xr-specialist
    - bigdra50/skills/unity/perspectives/test-engineer

    # Development
    - bigdra50/skills/unity/asmdef-lint
    - bigdra50/skills/unity/project-bootstrap
    - bigdra50/skills/unity/visual-test
    - bigdra50/skills/unity/unity-playmode-test

    # Language guide
    - bigdra50/skills/lang/unity-csharp-guide

    # Tooling
    - bigdra50/skills/tooling/unilyze-setup
    - bigdra50/skills/tooling/unity-cli-setup

    # DevOps
    - bigdra50/skills/devops/unity-ci

    # Static analysis (from bigdra50/unilyze)
    - bigdra50/unilyze/src/Unilyze/Skills/quality-audit
    - bigdra50/unilyze/src/Unilyze/Skills/refactor-loop
```

Then run `apm install` in the project root.

### Recommended plugins (project-scoped)

```sh
claude plugin install unity-coding-skills@bigdra50-unity-coding-skills --scope project
claude plugin install unity-dev@bigdra50 --scope project
claude plugin install unity-cli@unity-tools --scope project
claude plugin install csharp-lsp@claude-plugins-official --scope project
```

### Unity / C# Review System

Uses [unilyze](https://github.com/bigdra50/unilyze) for static analysis and [unity-cli](https://github.com/bigdra50/unity-cli) for project metadata.

Start with `review-triage`, then run the observation skills it recommends.
Use `review-weekly` to orchestrate all review skills together.

| Skill | Description |
|---|---|
| [review-triage](unity/review-triage/) | Day 0 scorecard — CodeHealth, assembly structure, test posture, top 3 risks. |
| [review-metrics](unity/review-metrics/) | Per-type metric deep-dive with unilyze evidence packs. |
| [review-architecture](unity/review-architecture/) | Assembly (asmdef) structure — dependency direction, DfMS, cyclic deps. |
| [review-hotspot](unity/review-hotspot/) | Git churn x complexity refactoring priorities. |
| [review-duplication](unity/review-duplication/) | Code clone detection and classification. |
| [review-performance](unity/review-performance/) | Unity hot-path smells, GC allocation, Burst/DOTS readiness. |
| [review-safety](unity/review-safety/) | Async patterns, exception handling, resource disposal. |
| [review-testing](unity/review-testing/) | Test posture — EditMode/PlayMode coverage, CI, test design quality. |
| [review-unity-specific](unity/review-unity-specific/) | Unity-specific gotchas no static analyzer catches. |
| [review-weekly](unity/review-weekly/) | Weekly orchestrator — runs all observation skills, dispatches perspectives, diffs KPIs. |

Perspective sub-skills (dispatched in parallel by `review-weekly`): `unity/perspectives/{unity-architect, performance-engineer, xr-specialist, test-engineer}`.

### Unity Development Skills

| Skill | Description |
|---|---|
| [asmdef-lint](unity/asmdef-lint/) | Assembly Definition structure validation — naming, dependency direction, test assemblies. |
| [project-bootstrap](unity/project-bootstrap/) | Day 0 project setup checklist — asmdef structure, .editorconfig, CI, unilyze baseline. |
| [visual-test](unity/visual-test/) | UXML resolvedStyle comparison for Figma-to-Unity visual testing. |
| [unity-playmode-test](unity/unity-playmode-test/) | Unity UI Toolkit PlayMode test patterns with trap avoidance. |
| [unity-csharp-guide](lang/unity-csharp-guide/) | C# in Unity patterns AI gets wrong — serialization, async/await, IL2CPP, hot-path allocations. |
| [unilyze-setup](tooling/unilyze-setup/) | Set up unilyze — first snapshot, CI integration, SARIF, badges, baselines. |
| [unity-cli-setup](tooling/unity-cli-setup/) | Set up unity-cli (`u` command) — installation, relay server, instance management. |
| [unity-ci](devops/unity-ci/) | GitHub Actions CI/CD for Unity — GameCI, test matrix, unilyze quality gate. |

## For 3DCG Development

3DCG skills are project-scoped.

```yaml
# Add to your project's apm.yml
dependencies:
  apm:
    - bigdra50/skills/3dcg/blender-export
    - bigdra50/skills/3dcg/blender-inspect
```

| Skill | Description |
|---|---|
| [blender-export](3dcg/blender-export/) | Blender scene inspection + FBX export. |
| [blender-inspect](3dcg/blender-inspect/) | 3-layer Blender quality inspection with auto-fix. |

## For Even Realities Development

```yaml
# Add to your project's apm.yml
dependencies:
  apm:
    - bigdra50/skills/even/evenhub-upload
```

```sh
claude plugin install everything-evenhub@everything-evenhub --scope project
```

| Skill | Description |
|---|---|
| [evenhub-upload](even/evenhub-upload/) | Upload .ehpk builds to Even Hub (unofficial API). |

## License

Each skill may carry its own license. Skills without an explicit license default to MIT.
