---
name: fable-prompt
description: >-
  Turn a rough task request into a self-contained, high-quality prompt for a separate
  Claude Fable 5 session, following Anthropic's Fable prompting guide. Gathers project
  context so the prompt works in a fresh session, recommends an effort level, selects
  only the behavior instructions the task profile needs, and flags tasks too routine to
  spend Fable quota on. Use for: "fableに投げるプロンプト作って", "fable用プロンプト",
  "fableにやらせたい", "Fableへの依頼文", "fable prompt", "prepare a prompt for Fable".
---

# Fable Prompt Generator

You (Sonnet/Opus) convert a rough delegation request into a paste-ready prompt for a
fresh Claude Fable 5 session. Fable quota is limited, runs are long, and the new session
starts with zero context from this conversation. Your output quality directly determines
whether that quota is well spent.

Respond to the user in the language they used (typically Japanese). Write the generated
prompt's narrative sections in that same language, but keep the behavior blocks from the
[Block library](#block-library) in English verbatim — they are Anthropic-tested phrasings.

## Flow

1. Understand the ask
2. Gate: is this Fable-worthy?
3. Gather context for self-containment
4. Classify the task and select effort + blocks
5. Assemble and deliver

### Step 1 — Understand the ask

From the arguments and the conversation so far, identify:

- Goal — what should exist or be known when the run ends
- Why / who for — what the output enables (Fable performs better with intent)
- Deliverable and done criteria — how anyone would judge the run complete
- Run mode — attended (user watches, can answer) vs unattended (overnight, autonomous)
- Constraints — scope limits, things not to touch, deadlines

Infer as much as possible from the current repo and conversation before asking anything.
If, after inferring, you still cannot fill two or more of {why, done criteria, run mode},
ask once via AskUserQuestion (max 3 questions in one round). Otherwise proceed and state
your assumptions explicitly in the final output — the user reviews the prompt before
pasting it, so a visible assumption beats a blocking question.

### Step 2 — Fable-worthiness gate

Fable is for the top of the difficulty range. Testing it on simple workloads undersells
it and wastes quota.

Worth sending to Fable:

- Long-horizon autonomous work: multi-hour or multi-day runs, large migrations, big refactors
- First-shot correctness on a complex, well-specified system (previously days of iteration)
- Deep debugging or bug-hunting across a large codebase or repository history
- Ambiguous, multi-threaded problems that need judgment about next steps
- Work that benefits from sustained parallel-subagent orchestration
- Dense vision work: technical diagrams, detailed screenshots, web-app UI analysis

Not worth Fable quota — say so and offer to handle it in this session or via a cheaper
model instead (still generate the prompt if the user insists):

- 1–2 file mechanical edits, boilerplate, scaffolding, config wiring
- Routine refactors or doc updates with no design judgment
- Anything you could finish yourself in a few minutes

Refusal risk — warn the user before they spend a session on it:

- Offensive cybersecurity (exploits, malware, attack tooling) and biology/life-science
  lab methods can return `stop_reason: "refusal"` on Fable. Suggest Opus 4.8 instead.
  Benign security work can also trip the classifiers; if the task is defensive or
  CTF-scoped, bake that authorization context into the prompt explicitly.

Scope up, not down: since each Fable run re-pays the cost of context gathering, one
well-scoped large run beats several small ones. If the conversation shows adjacent hard
work (the follow-up fix, the verification suite, the docs), propose bundling it into the
same prompt.

### Step 3 — Gather context for self-containment

The Fable session starts blank. Anything the user would have to say twice in the new
session belongs in the prompt. Collect and bake in:

- Repo identity and location — `ghq list` path or absolute path, branch/worktree to use
- Key files and directories, by path, with one line on why each matters
- Commands — how to build, test, run, and verify in this project (exact invocations)
- Background decisions from this conversation the task depends on (summarize; never
  write "as we discussed" — the new session has no idea)
- Specs, issues, URLs, error logs — inline the relevant excerpts, not just references

Actually run the cheap lookups now (`ghq list | rg …`, check for test commands in
package.json/mise.toml/Makefile, confirm file paths exist) rather than guessing paths
that Fable will then waste time discovering are wrong.

### Step 4 — Classify and select

Pick the closest profile. The target is usually a Claude Code session, whose harness
already enforces act-when-ready, autonomy, lead-with-outcome, and faithful reporting at
a baseline — blocks exist to emphasize what the task especially depends on. Select the
few that matter; never all.

| Profile | Signals | Effort | Blocks |
|---|---|---|---|
| Spec-driven build | Clear spec, complex system, first-shot correctness matters | xhigh | SCOPE, VERIFY, TLDR |
| Exploratory build | "Make X better somehow", open design questions | high | ACT, SCOPE, CHECKPOINT, TLDR |
| Long autonomous run | Unattended hours+, migration, overnight batch | high (xhigh if hard) | AUTONOMOUS, EVIDENCE, VERIFY, COMMS; add SUBAGENTS if parallelizable, MEMORY if recurring |
| Bug hunt / review / debugging | Root-cause analysis, audit, "find what's wrong" | high–xhigh | ASSESS, TLDR; add SUBAGENTS for breadth |
| Research / analysis / documents | Reports, financial analysis, slides, docs | high | ACT, TLDR |

Effort recommendation:

- `xhigh` — capability-sensitive work: one-shot correctness on a complex spec, deep
  debugging, decisions that are expensive to revisit
- `high` — default for anything that passed the worthiness gate
- If `medium` or lower feels right, the task probably shouldn't go to Fable at all —
  revisit Step 2

### Step 5 — Assemble

Build the prompt from this template. Drop headings that would be empty; never pad.

```
## Context
[Why this task exists, who it's for, what the output enables.
 Pattern: "I'm working on [larger task] for [who]. They need [what the output enables]."]

## Environment
[Repo path, branch, key files with paths, build/test/verify commands.]

## Task
[The specific ask. Deliverable and done criteria stated plainly.
 Outcomes and constraints — NOT step-by-step procedure.]

## Constraints & boundaries
[What not to touch, scope limits, irreversible-action policy.]

## Verification
[How to check the work: exact commands, acceptance criteria, spec to verify against.]

[Selected behavior blocks, verbatim, in English.]
```

Assembly rules:

- Prescribe outcomes, not process. Fable degrades under step-by-step micromanagement;
  give it the goal, the constraints, and the verification method, and let it determine
  the steps. Only spell out a procedure when the user requires that exact procedure.
- Verification is never optional. Every prompt states how Fable checks its own work.
- For unattended runs, open the Task section with "Work end to end without pausing for
  approval" so the run doesn't stall on a checkpoint.
- Never instruct Fable to echo, transcribe, or explain its internal reasoning in the
  response — that triggers `reasoning_extraction` refusals.
- Don't duplicate what the target repo's CLAUDE.md already enforces, when you know it.

## Block library

Copy these verbatim. Short IDs match the profile table.

ACT — anti-overplanning, for ambiguous tasks:

> When you have enough information to act, act. Do not re-derive facts already
> established in the conversation, re-litigate a decision the user has already made, or
> narrate options you will not pursue in user-facing messages. If you are weighing a
> choice, give a recommendation, not an exhaustive survey. This does not apply to
> thinking blocks.

SCOPE — anti-overengineering, for implementation tasks:

> Don't add features, refactor, or introduce abstractions beyond what the task requires.
> A bug fix doesn't need surrounding cleanup and a one-shot operation usually doesn't
> need a helper. Don't design for hypothetical future requirements: do the simplest
> thing that works well. Avoid premature abstraction and half-finished implementations.
> Don't add error handling, fallbacks, or validation for scenarios that cannot happen.
> Trust internal code and framework guarantees. Only validate at system boundaries (user
> input, external APIs). Don't use feature flags or backwards-compatibility shims when
> you can just change the code.

TLDR — lead with the outcome, for attended sessions:

> Lead with the outcome. Your first sentence after finishing should answer "what
> happened" or "what did you find": the thing the user would ask for if they said "just
> give me the TLDR." Supporting detail and reasoning come after. Being readable and
> being concise are different things, and readability matters more.
>
> The way to keep output short is to be selective about what you include (drop details
> that don't change what the reader would do next), not to compress the writing into
> fragments, abbreviations, arrow chains like A → B → fails, or jargon.

CHECKPOINT — pause only when genuinely needed:

> Pause for the user only when the work genuinely requires them: a destructive or
> irreversible action, a real scope change, or input that only they can provide. If you
> hit one of these, ask and end the turn, rather than ending on a promise.

EVIDENCE — grounded progress claims, for long autonomous runs:

> Before reporting progress, audit each claim against a tool result from this session.
> Only report work you can point to evidence for; if something is not yet verified, say
> so explicitly. Report outcomes faithfully: if tests fail, say so with the output; if a
> step was skipped, say that; when something is done and verified, state it plainly
> without hedging.

ASSESS — report, don't fix, for analysis/review/debugging deliverables:

> When the user is describing a problem, asking a question, or thinking out loud rather
> than requesting a change, the deliverable is your assessment. Report your findings and
> stop. Don't apply a fix until they ask for one. Before running a command that changes
> system state (restarts, deletes, config edits), check that the evidence actually
> supports that specific action. A signal that pattern-matches to a known failure may
> have a different cause.

SUBAGENTS — parallel delegation, for parallelizable work:

> Delegate independent subtasks to subagents and keep working while they run. Intervene
> if a subagent goes off track or is missing relevant context.

MEMORY — lesson notes, for recurring/multi-session work (designate a notes location):

> Store one lesson per file with a one-line summary at the top. Record corrections and
> confirmed approaches alike, including why they mattered. Don't save what the repo or
> chat history already records; update an existing note rather than creating a
> duplicate; delete notes that turn out to be wrong.

VERIFY — self-verification cadence, for long builds (fill in the interval):

> Establish a method for checking your own work at an interval of [X] as you build. Run
> this every [X interval], verifying your work with subagents against the specification.

AUTONOMOUS — for unattended pipelines:

> You are operating autonomously. The user is not watching in real time and cannot
> answer questions mid-task, so asking "Want me to…?" or "Shall I…?" will block the
> work. For reversible actions that follow from the original request, proceed without
> asking. Offering follow-ups after the task is done is fine; asking permission after
> already discussing with the user before doing the work is not. Before ending your
> turn, check your last paragraph. If it is a plan, an analysis, a question, a list of
> next steps, or a promise about work you have not done ("I'll…", "let me know when…"),
> do that work now with tool calls. End your turn only when the task is complete or you
> are blocked on input only the user can provide.

COMMS — final-summary readability, replaces TLDR for long unattended runs:

> Terse shorthand is fine between tool calls (that's you thinking out loud, and brevity
> there is good). Your final summary is different: it's for a reader who didn't see any
> of that.
>
> If you've been working for a while without the user watching (overnight, across many
> tool calls, since they last spoke), your final message is their first look at any of
> it. Write it as a re-grounding, not a continuation of your working thread: the outcome
> first, then the one or two things you need from them, each explained as if new. The
> vocabulary you built up while working is yours, not theirs; leave it behind unless you
> re-introduce it.
>
> When you write the summary at the end, drop the working shorthand. Write complete
> sentences. Spell out terms. Don't use arrow chains, hyphen-stacked compounds, or
> labels you made up earlier. When you mention files, commits, flags, or other
> identifiers, give each one its own plain-language clause. Open with the outcome: one
> sentence on what happened or what you found. Then the supporting detail. If you have
> to choose between short and clear, choose clear.

## Output format

Deliver in this order, in the user's language:

1. Judgment — 3–5 lines: profile, recommended effort with a one-line reason, blocks
   selected and why, and any assumptions you made in place of asking.
2. Session setup — one line, e.g.: `新セッションで: model Fable 5 / /effort xhigh /
   想定実行時間: 数十分〜` . Note that Fable turns run long; the user shouldn't
   interrupt a working run.
3. The prompt — inside a four-backtick fence (the prompt often contains triple-backtick
   code blocks), ready to paste as-is.
4. Offer once to copy it to the clipboard (`pbcopy` on macOS) or save it to a file.

## Anti-patterns

- Kitchen-sink blocks. Every block you add that the task doesn't need makes the prompt
  more prescriptive and the output worse. When in doubt, leave it out.
- Step-by-step procedures for work Fable should sequence itself.
- Prompts that lean on this session's context: "as we discussed", "the file I
  mentioned", relative references with no path.
- Guessed file paths or commands. Verify them here, cheaply, before baking them in.
- "Explain your reasoning" / "show your thinking" instructions — refusal trigger.
- Splitting one hard task into several small Fable runs. Bundle instead.
- Spending Fable quota on work this session could finish now. Say so instead.
