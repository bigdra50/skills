---
name: second-opinion
description: |
  One review pass by a reviewer that did not write the work — a Fable subagent by default, or Codex / Copilot.
  Reviews a design plan or a code change and returns findings with file:line and a severity estimate.
  Use for: "second opinion", "セカンドオピニオン", "別視点でレビュー", "fable にレビューさせて", "codex にレビュー", "copilot にレビュー", "プランを外部レビュー"
---

# Second Opinion

A review is worth something only when the reviewer does not already believe the work is correct.
Two things buy that, independently:

- **A fresh context** — the reviewer never read the reasoning that produced the work, so it cannot inherit the rationalizations
- **A different model** — its blind spots fall in different places

`/code-review` runs as a fork. It inherits this conversation, including every justification talked into
existence along the way, so it buys neither. This skill always buys the first and optionally the second.

## When NOT to use

- A quick pass over your own diff — `/code-review` is cheaper and usually enough
- Iterating until findings stop — `/goal "no MUST or SHOULD findings remain"`, and run this inside it
- Repeating on a schedule — `/loop`
- The plan or the code does not exist yet — write it first

**This skill performs one pass.** It does not count rounds, thread history, or decide when to stop.
`/goal` and `/loop` do those better; restating them here would be scaffolding the model reads past.

## Parameters

| Param | Values | Default | Buys |
|---|---|---|---|
| `--tool` | `fable`, `codex`, `copilot` | `fable` | fresh context always; a different vendor with `codex` / `copilot` |
| target | a path, `--staged`, or omitted | recent changes | — |

Never name a model generation, here or in a delegation prompt. Each CLI carries its own default and its
own config, and a generation written into a skill goes stale with nothing to catch it.

## Dispatching

**`fable`** — the Agent tool with `model: "fable"`, `subagent_type: "general-purpose"`, and
`run_in_background: false`. Hand it the target, the files, and the dimensions. Do **not** summarize your own
reasoning into the prompt: an unread context is the thing being bought, and narrating your intent spends it.
Avoid `opus-code-reviewer` — it filters to high-priority findings, which is the failure documented below.

**`codex` / `copilot`** — the agents of the same name. They add vendor decorrelation on top of the fresh
context, at the cost of CLI authentication and sandbox path access.

## What to ask for

Give the reviewer the target, the files it needs, and the dimensions below.

**Ask for every finding, each carrying its own severity estimate. Never ask for serious findings only.**
A reviewer told to filter by severity investigates exactly as hard, then drops whatever it judged below the
bar — the findings are gone and their absence is invisible. Classify after they return, never before.

Require a `file:line` on each finding. One without a reference cannot be checked, and in practice means the
reviewer answered from the prompt instead of opening the target.

Dimensions for a **design plan**: architecture and separation of concerns; performance on hot paths;
concurrency; backward compatibility; test strategy; edge cases.

Dimensions for a **code change**: security (input validation, permissions, secret exposure);
performance (complexity, allocation, I/O); maintainability (readability, naming, duplication);
design (responsibility, dependency direction, extensibility).

With `codex` / `copilot`, ask for Japanese output — the external CLIs do not inherit this session's
language setting.

## Fable declines some security work

Fable runs safety classifiers over cybersecurity content, and benign security tooling trips them
often enough to matter. A declined request returns a refusal, which through a subagent reads as an empty or
evasive report rather than an error.

**A Fable review that says nothing about the security dimension is not evidence of no security findings.**
Re-run it on `codex` or `copilot` before concluding anything. Auth code, token handling, and permission
checks are the likeliest to trip it — and the likeliest to need the review.

Fable also draws on a weekly quota. When that is tight, `codex` costs only the model-quality difference;
the fresh context is unaffected.

## Constraints

**The reviewer proposes; it never edits.** Bring the findings back and apply them yourself, so the user
approves each change and any later regression traces to a decision somebody made deliberately.

Classify what returns:

- **MUST** — a bug, a security hole, or data loss
- **SHOULD** — a real gain in correctness, performance, or design
- **NICE** — style and preference

Report all three. Apply MUST and SHOULD once the user approves them. Leave NICE to the user; applying it
quietly swaps the reviewer's taste in for theirs.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| Empty report, or the security dimension goes unmentioned | Fable's classifiers declined the request | Re-run on `codex` or `copilot`; do not read silence as a clean result |
| The reviewer returns nothing at all | CLI unauthenticated, or its sandbox cannot reach the target path | Switch `--tool` to isolate which half is broken |
| Findings carry no `file:line` | It answered from the prompt without opening the files | Pass absolute paths and state that the files must be read |
| One shallow pass, then "looks fine" | Only some dimensions were actually evaluated | Check the output against the dimensions above before believing it |
| Applied fixes break the tests | Applied without running them | Find the project's test command in CLAUDE.md and run it before reporting done |
| The same finding recurs on a later pass | Earlier fixes were never described to the next reviewer | Summarize what changed, and why, in the next delegation |

## Anti-patterns

| Rationalization | Reality |
|---|---|
| "`/code-review` already looked at this" | It forked this conversation and read the reasoning behind the work. That is the anchoring this skill exists to avoid |
| "It found nothing, so the code is clean" | It may not have opened the files, or Fable may have declined. Check for `file:line` before concluding anything |
| "The findings came from a reviewer, so apply them" | Reviewers are wrong regularly. The user approves; you apply |
| "Ask for high-severity findings only, to cut the noise" | It then drops real bugs it judged minor, silently. Filter after, never before |
| "Run it a few more times until it comes back clean" | That is a loop. `/goal` runs it and knows when to stop |
| "Fable is the strongest model, so its verdict settles it" | Same model family as the work under review. For decorrelated blind spots you need a different vendor |
| "Both tools agree, so the finding is certain" | Agreement between two models is weak evidence. A `file:line` you can open yourself is strong evidence |
