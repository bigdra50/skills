# Skills repository — maintainer notes

This repo is the upstream source for bigdra50's agent skills.
Each category directory contains skills distributed via [APM](https://github.com/microsoft/apm).

## When editing a skill in this repo

Skills here are installed to `~/.claude/skills/<name>/` via `apm install -g bigdra50/skills/<category>/<skill-name>`.
When you edit a file here, the local copy that Claude Code actually reads does NOT update automatically.

**Propagation rule**: every time a file under `<category>/<skill-name>/` is edited, mirror the same change to `~/.claude/skills/<skill-name>/` so the running Claude Code session picks it up immediately.

After a batch of edits, commit + push here, then the next `apm install -g --update` on any machine pulls the same change.

## Language policy

`SKILL.md` should be written in English for public visibility.
Japanese is acceptable for skills that are inherently Japanese-language tools.

## Before committing

- Skill directory name must match the `name:` in its `SKILL.md` frontmatter.
- Do not commit `node_modules/`, `apm_modules/`, or `.DS_Store`.
