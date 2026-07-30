---
name: second-opinion
description: |
  Delegate a review to a model that did not write the thing being reviewed — Codex or Copilot.
  Reviews a design plan or a code change and returns findings with file:line and a severity estimate.
  Use for: "second opinion", "セカンドオピニオン", "別視点でレビュー", "外部AIにレビューさせて", "codex にレビュー", "copilot にレビュー", "プランを外部レビュー"
---

# Second Opinion

One model's blind spots are consistent: it misses on the second pass what it missed on the first.
Another model's blind spots are different, and that difference is the whole value here.
Everything else in a review — reading the diff, checking the tests, deciding what matters — Claude already does unprompted.

## When NOT to use

- Reviewing a diff with Claude itself — `/code-review` covers it
- Iterating until the findings stop — `/goal "no MUST or SHOULD findings remain"`, then run this inside it
- Repeating on a schedule — `/loop`
- The plan or the code does not exist yet — write it first

**This skill performs one pass.** It does not count rounds, track history, or decide when to stop.
`/goal` and `/loop` do those better, and restating them here would be scaffolding the model has to read past.

## Parameters

| Param | Values | Default | Notes |
|---|---|---|---|
| `--tool` | `codex`, `copilot` | `codex` | Which model reviews. `cursor-agent` is an implementation agent, not a reviewer |
| target | a path, `--staged`, or omitted | recent changes | A plan file, a source path, or the staged diff |

Never name a model generation, here or in the delegation prompt.
Each CLI has its own default and its own config; a generation written into a skill goes stale silently.

## What to ask for

Give the reviewer the target, the source files it needs, and the dimensions below.

**Ask for every finding, each with a severity estimate — never ask for serious findings only.**
A reviewer told to filter by severity investigates just as hard, then drops what it judged below the bar.
The findings are gone and you never learn they existed. Classify after they come back, not before.

Require a `file:line` on each finding. One without a reference cannot be verified, and in practice means the
reviewer answered from the prompt instead of reading the target.

Dimensions for a **design plan**: architecture and separation of concerns; performance on hot paths;
concurrency; backward compatibility; test strategy; edge cases.

Dimensions for a **code change**: security (input validation, permissions, secret exposure);
performance (complexity, allocation, I/O); maintainability (readability, naming, duplication);
design (responsibility, dependency direction, extensibility).

Ask for Japanese output. The external CLIs do not inherit this session's language setting.

## Constraints

**The reviewer proposes; it never edits.** Bring the findings back and apply them yourself, so the user
approves each change and a later regression traces to a decision somebody made on purpose.

Classify what returns:

- **MUST** — a bug, a security hole, or data loss
- **SHOULD** — a real gain in correctness, performance, or design
- **NICE** — style and preference

Report all three. Apply MUST and SHOULD once the user approves them.
Leave NICE to the user; applying it silently swaps the reviewer's taste in for theirs.

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| The reviewer returns nothing | CLI unauthenticated, or its sandbox cannot read the target path | Switch `--tool` to isolate which half is broken |
| Findings carry no `file:line` | It answered from the prompt without opening the files | Pass absolute paths and state that the files must be read |
| One shallow pass, then "looks fine" | Only some dimensions were actually evaluated | Check the output against the dimensions above before believing it |
| Applied fixes break the tests | Applied without running them | Find the project's test command in CLAUDE.md and run it before reporting done |
| The same finding recurs on a later pass | The earlier fixes were never described to the next reviewer | Summarize what changed, and why, in the next delegation |

## Anti-patterns

| Rationalization | Reality |
|---|---|
| "Claude already reviewed this, so a second pass is redundant" | Same model, same blind spots. A different model looking is the point |
| "It found nothing, so the code is clean" | It may not have read the files. Check for `file:line` before concluding anything |
| "The findings came from a reviewer, so apply them directly" | Reviewers are wrong regularly. The user approves; you apply |
| "Ask for high-severity findings only, to cut the noise" | It then drops real bugs it judged minor, silently. Filter after, never before |
| "Run it a few more times until it comes back clean" | That is a loop. `/goal` runs it and knows when to stop |
| "Both tools agree, so the finding is certain" | Agreement between two models is weak evidence. A `file:line` you can open is strong evidence |
