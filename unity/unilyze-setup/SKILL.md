---
name: unilyze-setup
description: >-
  Set up unilyze for a Unity or .NET project — installation, first snapshot,
  CI integration with SARIF, badge generation, and baseline creation for
  zero-new-violations enforcement. Use when onboarding unilyze or configuring
  quality gates.
---

# unilyze setup

unilyze is a static analyzer for Unity and general C# projects. It scores per-type
Code Health, detects smells / duplication / hotspots, and emits JSON, SARIF, HTML, and
a status-line summary. This skill covers onboarding and wiring CI quality gates.

## When this skill applies

- "set up unilyze" / "add a code-quality gate to this Unity repo"
- "generate a SARIF report for Code Scanning" / "add a Code Health badge"
- "enforce zero new violations" / "create a baseline"

## 1. Installation

Install unilyze per the project README. On macOS/Linux it ships as a Homebrew formula:

```bash
brew install bigdra50/tap/unilyze
unilyze --version          # verify (e.g. "unilyze 0.5.3")
```

Source and other install methods: <https://github.com/bigdra50/unilyze>.

## 2. First snapshot

Analyze the project and write a JSON snapshot (the format is inferred from `-o`'s
extension; `-f json` makes it explicit):

```bash
mkdir -p snapshots
unilyze -f json -p <project> -o snapshots/baseline.json
```

Get a one-line health read for eyeballing or a status line:

```bash
unilyze statusline -p <project>
# CH:9.4/3.2 87smells 🔴5 📦12 ♻3 [core]
#   CH:<avg>/<min> Code Health · <n>smells · 🔴 critical · 📦 boxing · ♻ cycles
```

Running `unilyze -p <project>` with no `-o` opens an interactive HTML viewer — useful
for first exploration.

## 3. Configuration

Settings merge additively from global (`$XDG_CONFIG_HOME/unilyze/config.json`) and
project (`<project-root>/.unilyze.json`) scopes.

```bash
unilyze config list                          # show resolved config + sources
unilyze config add-exclude-dir Assets/Plugins       # project scope
unilyze config add-exclude-dir Packages --global    # global scope
```

A hand-written `.unilyze.json` at the project root:

```json
{ "excludeDirs": ["Assets/Plugins", "Assets/ThirdParty"], "profile": "unity" }
```

Use the `unity` profile for Unity role-aware smell thresholds. Scope analysis to
specific assemblies instead of excluding directories:

```bash
unilyze -p <project> --prefix App          # only asmdefs whose name starts with "App"
unilyze -p <project> -a Domain             # exact or suffix match ("App.Domain" matches)
```

## 4. CI integration

**SARIF → GitHub Code Scanning.** Emit SARIF and upload it so findings appear in the
Security tab and inline on PRs:

```yaml
# .github/workflows/unilyze.yml
- run: unilyze -p . -f sarif -o report.sarif
- uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: report.sarif
```

**Diff-based PR gate.** Analyze the base ref in a temp worktree, diff against the PR
head, and fail the job on regression (exit code 2). Post the markdown diff as a PR
comment:

```bash
git fetch origin main          # or fetch-depth: 0 in the checkout step
unilyze -p . -o after.json
unilyze diff --base-ref origin/main after.json -f markdown --fail-on-regression
```

Exit codes are uniform: `0` pass · `1` usage error · `2` quality gate failed.

## 5. Badge

Emit a shields.io endpoint JSON, or a self-contained SVG for private repos:

```bash
unilyze badge -p <project> -o badge.json                 # shields.io endpoint
unilyze badge -p <project> --format svg -o codehealth.svg  # embeddable, no external calls
```

Metrics: `codehealth` (default), `mi`, `smells`, `energy`, `dup`. A badge command
doubles as a gate — `--fail-under` for codehealth/mi, `--fail-over` for smells/dup/energy:

```bash
unilyze badge --metric codehealth --fail-under 7   # fail if min Code Health < 7
```

## 6. Baseline (zero new violations)

Snapshot the current smells, then suppress them so only *new* violations fail the gate:

```bash
unilyze baseline create -p <project>       # writes <project>/.unilyze/baseline.json
unilyze -p <project> --baseline <project>/.unilyze/baseline.json -f json -o after.json
```

`--baseline` works with the main analysis, `badge`, and `statusline` — pass it
everywhere the gate runs so the known-smell floor stays consistent.

## 7. Snapshot management (trend)

Keep dated JSON snapshots in one directory and render a trend over time:

```bash
unilyze -f json -p <project> -o snapshots/$(date +%F).json   # append per run (e.g. nightly CI)
unilyze trend snapshots/ -o trend.html                       # charts across all snapshots
```

## 8. Agent integration

Install the bundled review skills into an AI coding tool, or run unilyze as an MCP
server for live grounding:

```bash
unilyze skills install --claude              # → .claude/skills/  (add -g for ~/)
unilyze skills list                          # installation status
claude mcp add unilyze -- unilyze mcp        # register the stdio MCP server
```

The MCP server exposes tools like `analyze`, `worst_types`, `query_type`, `diff`, and
`hotspot` for per-type evidence packs.

## Decision: which gate to use

| Goal | Command |
|---|---|
| Block PRs that lower overall quality | `unilyze diff --base-ref <ref> after.json --fail-on-regression` |
| Enforce an absolute Code Health floor | `unilyze badge --metric codehealth --fail-under <n>` |
| Allow existing smells, block new ones | `unilyze baseline create` + `--baseline <file>` |
| Surface findings in the GitHub Security tab | `unilyze -f sarif -o report.sarif` + upload-sarif |
