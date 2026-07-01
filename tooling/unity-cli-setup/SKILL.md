---
name: unity-cli-setup
description: >-
  Set up unity-cli (the `u` command) for a Unity project — installation,
  relay server configuration, instance management, and Claude Code plugin
  registration. Use when onboarding unity-cli or troubleshooting connection.
---

# unity-cli setup

unity-cli exposes a running Unity Editor to the shell through the `u` command. It
drives play mode, asset refresh, console reads, Test Runner, GameObject/Component
edits, menu items, builds, and screenshots by talking to a local **Relay Server**
over TCP. This skill covers installing it, getting connected, and wiring it into
Claude Code.

## When this skill applies

- "set up unity-cli" / "let me control Unity from the shell"
- "`u` says connection refused" / "commands time out"
- "run Unity tests from CI without opening the Editor by hand"
- "register unity-cli with Claude Code"

## 1. Installation

Install unity-cli per the project README. It is a Python CLI, typically installed as a
`uv` (or `pipx`) tool so `u` lands on your PATH:

```bash
uv tool install unity-cli      # or: pipx install unity-cli
u --version                    # verify (e.g. "unity-cli v3.12.0")
```

The install also provides `unity-relay` (the relay server, below).

## 2. Relay server

`u` never touches the Editor directly — it sends JSON commands to a Relay Server on
`127.0.0.1:6500`, and the Editor registers itself with that relay. Two pieces must be
running:

1. **The relay process.** Start it (usually once, in the background):
   ```bash
   unity-relay                     # binds 127.0.0.1:6500
   unity-relay --port 6600 --debug # override port / log verbosely
   ```
2. **The Unity-side bridge.** The unity-cli bridge package must be installed in the
   project so the open Editor connects to the relay. Without it, `u instances` shows
   nothing even while the Editor is running.

Override the endpoint per-command with `--relay-host` / `--relay-port`, or via the
`UNITY_RELAY_HOST` / `UNITY_RELAY_PORT` env vars.

## 3. Instance management

One relay can serve several open Editors. List them and target one:

```bash
u instances                    # project path/name + instance ID for each Editor
u instances --json
u -i MyGame state              # target by project name or path prefix
```

Set a default so you stop repeating `-i`: `export UNITY_INSTANCE=MyGame`, or commit a
`.unity-cli.toml` (found by walking up from cwd, like `.editorconfig`):

```bash
u config init                  # write a default .unity-cli.toml in cwd
u config show                  # print resolved config (file + env + flags) and its source
```

## 4. Quick Verify sequence

After editing C# outside the Editor, confirm a clean compile from the shell:

```bash
u console clear                                  # wipe stale entries
u refresh                                        # AssetDatabase.Refresh → recompile
until [ "$(u state --json | jq -r .isCompiling)" = "false" ]; do sleep 1; done
u console get -l E                               # errors + exceptions only
```

Console level hierarchy: `L` (log) < `W` (warning) < `E` (error) < `X` (exception).
`-l W` is warning-and-above; `-l +E` is error only. Add `-s` for stack traces,
`--json` for machine output.

## 5. Offline mode (no running Editor)

`u project` reads `ProjectSettings/`, `Packages/manifest.json`, and `.asmdef` files
straight from disk — no Editor, no relay, no Unity license. Safe in CI:

```bash
u project info -p <project>        # product name, Unity version, build scenes
u project version -p <project>     # Unity version only
u project packages -p <project>    # installed UPM packages
u project assemblies -p <project>  # .asmdef list
```

## 6. Claude Code plugin

A Claude Code plugin is a directory with a `.claude-plugin/plugin.json` manifest plus
`skills/` and `agents/` subdirectories. To let Claude drive Unity, ship a plugin whose
skills and agents wrap the `u` commands (e.g. a "verify build" skill that runs the
Quick Verify sequence, a test-runner agent around `u tests run`).

- Install a directory-based plugin by adding it under `.claude/plugins/`, or publish it
  through a marketplace and `/plugin install` it.
- Skills auto-load by their `SKILL.md` frontmatter; agents live as markdown files under
  `agents/`.

## 7. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Connection refused` | relay not running | start `unity-relay` |
| `u instances` empty, Editor open | bridge package missing / Editor not registered | install the unity-cli bridge package in the project; reopen the Editor |
| Commands time out | large project still compiling | raise the timeout: `u -t 120 <cmd>`; poll `u state --json` first |
| Wrong Editor targeted | multiple instances | pass `-i <name>` or set `UNITY_INSTANCE` |
| Right relay, wrong port | non-default relay | set `--relay-port` / `UNITY_RELAY_PORT` to match `unity-relay` |
