---
name: jev-fit
description: |
  Consult on whether Jev would improve the work at hand, without pushing adoption.
  Jev is TypeSafe's System One model: it returns typed yes/no, choice, and score judgments
  with calibrated probabilities, and it does not generate text.
  Injects the Jev facts needed to judge fit, lists the decision points in the current context
  (agent workflow such as CLAUDE.md, hooks, skills, and rules, or an application codebase),
  screens each one, and proposes only what passes. "Nothing fits" is a valid result.
  Measures before and after only after showing the estimated token cost and getting consent.
  Use when the user asks "could Jev do this better?", "jev 使えそう?", "これ jev でよくなる?",
  "jev で最適化できる?", "jev の使いどころは?", or runs /jev-fit.
  Do not trigger on work that does not mention Jev or TypeSafe.
  To implement an accepted candidate, hand off to the official typesafe-ai skill or the live docs.
argument-hint: "[what to look at]"
license: MIT
---

# jev-fit

Decide whether Jev would make the work at hand better, and say so honestly.

Jev is TypeSafe's System One model.
It reads natural language and returns typed judgments with probabilities.
It does not write text, plan, or choose the next action.

This skill decides whether to build.
How to build belongs to the official [typesafe-ai skill](https://github.com/typesafe-ai/skills) and the [live docs](https://docs.typesafe.ai/llms.txt).

## Stance

- The user is exploring, not committed. "Nothing here fits" is a normal result. Say it in two lines and return to the main work.
- Static first. If a regex, parser, type checker, linter, or ast-grep rule can decide it, recommend that instead.
- Every proposal names its payoff with a rough number. No number, no proposal.
- Propose at most three candidates. Give the rest one line each, with the reason they were dropped.
- While consulting, do not edit files, install packages, or call the API. Sketch only. Measuring has its own gate in step 6.
- Do not bring back a candidate the user already declined in this session.
- This is a side consultation. Use what is already in context plus a few targeted reads. Do not survey the whole repository.
- Reply in the user's language.

## Jev in one screen

One request carries one `state` and any number of `questions`.
Every question is answered independently, in parallel, against the same state.
A question cannot see another question's answer.

| Type | Asks | Returns |
| --- | --- | --- |
| `noul` | Does this condition hold? | `noul`, the probability of yes. Near 0.5 means undecided, not medium. No confidence field. |
| `choice` | Which one of up to 255 named options? | `choice`, `probabilities` for every option, `confidence` |
| `score` | Where on 2 to 10 ordered, described levels? | `score` as a probability-weighted level, `probabilities`, `confidence` |

```text
POST https://api.typesafe.ai/v1/systemone      Authorization: Bearer $TYPESAFE_API_KEY
{
  "model": "jev-latest",
  "state": { "command": "rm -rf ./build && git push --force origin main" },
  "questions": {
    "destructive": {
      "type": "noul",
      "instructions": "The shell command in `command` can irreversibly destroy data or rewrite shared history."
    },
    "kind": {
      "type": "choice",
      "instructions": "What kind of operation is the shell command in `command`?",
      "criteria": {
        "read_only": "Only reads or lists information",
        "local_change": "Changes local files only",
        "remote_change": "Changes a remote or shared system",
        "other": null
      }
    }
  }
}

200 OK
{
  "model": "jev-1.13.0",
  "answers": {
    "destructive": { "type": "noul", "noul": 0.97 },
    "kind": { "type": "choice", "choice": "remote_change", "confidence": 0.99, "probabilities": { "remote_change": 1.0 } }
  },
  "usage": { "input_tokens": 389, "output_tokens": 67 }
}
```

Question IDs are for code only and are not sent to the model.
Point at parts of a JSON state with backticked paths such as `ticket.messages[0].text`.

The numbers below are for `jev-1.13.0`.
When a decision hinges on one of them, check [the models page](https://docs.typesafe.ai/models.md) first.

| Topic | Value |
| --- | --- |
| Price | $0.042 per million input tokens. Output tokens are free. |
| Limits | 64k tokens per request. 32k for the state plus the longest question. Text only. |
| Rate limits | 250k tokens per second and 1,200 requests per minute, subject to change |
| Token math | About 265 fixed per request, and about 22 per short question. The state is counted once, however many questions there are. |
| Tokens per character | English prose about 0.16. Code and JSON about 0.25. Japanese about 1.0. |
| Latency, warm connection | About 0.2 to 0.3 s per request. The same for 1 question or 100. |
| Latency, cold process | About 0.5 to 0.8 s, mostly TLS setup. A hook pays this on every call. |
| Stability | The same input gives nearly the same answer, but not bit-identical. A value near a threshold can flip between runs. |
| Language | English is the most accurate. Japanese and other CJK text work with lower accuracy. |
| Data | The state goes to a third-party API. Requests are not used for training. Zero data retention is an enterprise option. |
| Versions | `jev-latest` moves when a release ships. Pin the versioned ID once thresholds are tuned. |
| Customizing | No fine-tuning. Only the state, the instructions, and the criteria shape the answer. |

The token and latency rows were measured from Japan.
Measure again when latency decides the outcome.

This model is weak at the following.
Do them in code or with another model.
The full list is on [the jaggedness page](https://docs.typesafe.ai/model-jaggedness/jev-1.13.md).

- counting and arithmetic
- the order of dates and the gaps between them
- multi-hop references and double negatives
- a state full of text unrelated to the question
- input written to mislead it
- any text generation

## Procedure

### 1. Fix the scope

Take the focus from the argument if one was given.
Otherwise use what the conversation is already about.
If neither is clear, ask one question instead of exploring.

### 2. List the decision points

A decision point is a place where something classifies, selects, ranks, gates, grades, or verifies.
Today that something may be a person, an LLM, a regex or heuristic, or nothing at all because checking was too costly.

Note four things for each: who decides now, how often, how fast it must be, and what a wrong answer costs.

Where to look in an agent workflow:

- context that is always loaded only so the model can pick from it, such as skill descriptions, rule files, memory indexes, and tool lists
- hooks that use a regex for what is really a semantic judgment
- checks done by asking the main model to review itself
- review or lint rules written in natural language
- triage of transcripts, logs, or past sessions

Where to look in an application:

- LLM calls that are prompted and parsed only to get a label, a boolean, or a score
- keyword or regex heuristics with a long tail of exceptions
- manual triage queues
- ranking and reranking
- validation of another model's output
- intent routing for chat, voice, or commands

For concrete shapes, read [references/patterns.md](references/patterns.md).

### 3. Screen each one

A decision point is a fit only when all six hold.

1. The output is a typed judgment: yes or no, one of N, or a level on a described scale. Not text.
2. A knowledgeable person who is handed the state could answer in about a second. No multi-step reasoning.
3. The evidence is text and fits in 32k tokens after narrowing it to what the question needs.
4. No static tool can decide it.
5. There is a payoff you can name. It removes LLM tokens or latency, or replaces a heuristic that keeps missing, or makes a skipped check affordable, or offloads human triage.
6. Failure is survivable. An uncertain answer has somewhere to go, and an API outage has a defined fallback.

Then check what can veto a fit.

- Governance. The state leaves the machine. For proprietary, client, or personal data, the verdict is "blocked until policy is checked".
- Language. For non-English input, the verdict is "maybe" until it is measured on real data. Writing instructions and criteria in English over a Japanese state is worth trying.
- Latency budget. Compare the cold-process figure with what the hook or the UI can tolerate.
- Reproducibility. A CI gate that must give the same result twice should stay advisory, or record answers and replay them.
- Connectivity. There is no local model. Offline or on-device work is out.

Cost is rarely the blocker and rarely the payoff.
The saving usually sits in another model's tokens or in a person's time, so put the number there.

Give each decision point one verdict.

| Verdict | Meaning |
| --- | --- |
| fit | Passes all six, and nothing vetoes it |
| maybe | Passes, but one fact has to be measured first. Name the fact. |
| no | Give one reason: static tool suffices, needs generation or reasoning, state does not fit, no payoff, governance, latency, or offline |

### 4. Sketch what passed

Keep each sketch to a few lines.

- State: the named JSON fields, and only what the questions need.
- Questions: the type, the instruction, and the criteria. One property per question.
- Request shape: put every question over the same state in one request, including ones that only matter on some branches. Code discards the rest.
- Code: thresholds, the hold band, the fallback, and where it plugs in, such as a hook event, a function, or a CI step.
- Paper estimate: tokens per request, cost per thousand decisions, and added latency, from the table above.

A second request is justified only when the first answer is needed to build the next state or the next options.

### 5. Report

Lead with the verdicts, not with Jev.

1. One table: decision point, who decides today, verdict, and reason.
2. A sketch for each fit and each maybe, three at most, ordered by payoff over effort.
3. The dropped items, one line each.
4. One recommended next step. "Do nothing" is allowed.

If nothing fits, skip items 2 to 4, say so, and go back to the main work.

### 6. Measure, only with consent

Measure when the user wants to go ahead with a candidate, or asks for numbers.
Before spending anything, show what would be measured and the estimated cost in tokens and money, then ask.
Follow [references/measurement.md](references/measurement.md).

### 7. Hand off

Once the user accepts a candidate, stop consulting.
Use the official typesafe-ai skill if it is installed, or read the API or SDK page and the closest cookbook from the docs index.
Keep questions and thresholds together in one file, because they are what a person has to review.
