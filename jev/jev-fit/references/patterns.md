# Patterns worth checking

Shapes that have worked for Jev, grouped by what the decision does.
Use them to recognise a decision point, not as a list of things to propose.
Figures quoted from cookbooks and third-party repos are their authors' results, not guarantees.

Cookbook and pattern pages live under `https://docs.typesafe.ai/`.
Append `.md` to a page path to get Markdown, for example `https://docs.typesafe.ai/cookbooks/skill_suggestion.md`.
The full index is `https://docs.typesafe.ai/llms.txt`.

## Agent workflow: select

Decide outside the context window, then load less into it.

| Pattern | Jev shape | Payoff to measure | Watch out | Pointer |
| --- | --- | --- | --- | --- |
| Skill routing | Request 1 ranks every skill description with one Choice, and asks with a few Nouls whether the turn needs a skill at all. Request 2 rereads the top three with fuller text and may reject all. One suggestion line goes after the unchanged roster. | Wrong loads, needless loads, and description tokens that no longer need loading | Reported: wrong loads 16.8% to 7.3% on a 182-skill roster. A confident wrong suggestion persuades more than none. A small roster gains little. | `cookbooks/skill_suggestion` |
| Rule and memory routing | One Noul per rule file or memory entry: "this request involves X". Load those above a low threshold. | Always-loaded tokens per session | A miss silently drops a rule, so favour recall. Leave must-always rules unrouted. | `patterns/intent-routing`, `patterns/fan-out` |
| Agent, tool, or model routing | A Choice over handlers, or a Score for task difficulty | Expensive-model calls avoided | Difficulty is hard to judge in a second. Measure before trusting it. | `patterns/confidence-routing` |
| Rerank after search | Keyword search builds a shortlist. One question per candidate scores relevance. | Top-1 and top-10 hit rate | Reported: top-10 38% to 62% on legal queries with 30 candidates per query. | `cookbooks/rerank_typesafe`, `cookbooks/semantic_find` |

## Agent workflow: gate

A judgment inside a hook or a request path, where an LLM call is too slow and a regex is too crude.

| Pattern | Jev shape | Payoff to measure | Watch out | Pointer |
| --- | --- | --- | --- | --- |
| Command risk gate | Before a shell command runs, Nouls ask: destructive, touches shared or remote state, sends secrets out. | Risky commands a regex list missed, against added latency per call | Keep the static allowlist first and gate only what it does not match. Decide fail-open or fail-closed for outages. Jev is weaker against input written to mislead. | `cookbooks/llm_guardrails` |
| Screening fetched content | After a web fetch or a tool result, a Noul asks whether the text contains instructions addressed to the assistant. | Injection attempts flagged | Narrow the state to the fetched text. | `cookbooks/classifying_rag_passages` |
| Completion check | At stop, the state is the final message plus the commands that ran. A Noul asks whether it claims passing tests when no test command ran. | False completion claims caught | Transcripts are large. Build a small state in code first. | `patterns/fan-out` |

## Agent workflow: grade

Many natural-language checks in one batch.

| Pattern | Jev shape | Payoff to measure | Watch out | Pointer |
| --- | --- | --- | --- | --- |
| Natural-language lint | ast-grep selects the targets. Each rule is a Noul such as "the function body contradicts what its name promises". | Findings a static linter cannot express, with cost and time per run | Reported: about 9,800 lines and 22 rules in 7.7 s for about $0.055. Scores are not reproducible, so keep it advisory, or record and replay. | [jev-lint](https://github.com/mizchi/jev-lint), [article](https://zenn.dev/mizchi/articles/jev-lint-intro) |
| Writing and PR rules | Nouls for rules a text linter cannot express, such as "the PR body states why the change is needed". | Review comments avoided | Keep static rules in the text linter. Japanese prose needs measuring first. | `patterns/composite-scoring` |
| Doc against code drift | Per doc section, with the code it cites: "the description contradicts the code". Only hits go to a full review. | Review tokens saved by the shortlist | It is a cascade, not a verdict. | `cookbooks/sde_cascade`, `cookbooks/citation_check` |
| Transcript compaction | Two Nouls per old tool call: keep the call, keep the result verbatim. The rest is dropped or truncated. Nothing is rewritten. | Context removed without a lossy summary | The full state is resent with every batch of questions. | [fast-jev-compaction](https://github.com/tamaratran/fast-jev-compaction) |
| Session mining | Classify past turns in bulk, for example "the user corrected the assistant here". | Hours of manual reading | Label a small sample first. | `cookbooks/parallel_questions` |
| Rubric grading | One Score per rubric dimension, with levels that describe situations. Weights live in code. | LLM-judge tokens | Check against a few human grades. One dimension per Score. | `patterns/composite-scoring` |

## Application features

| Pattern | Jev shape | Payoff to measure | Watch out | Pointer |
| --- | --- | --- | --- | --- |
| Intent routing with arguments | A Choice picks the handler. Speculative questions fill each handler's closed-set arguments in the same request. | LLM calls avoided, response time | Free-text arguments still need a generator. | `cookbooks/function_calling`, [jev-ultrafast](https://github.com/browser-use/jev-ultrafast) |
| Guardrails | Nouls and severity Scores on what enters and leaves an LLM feature. | Incidents caught per added latency | Set thresholds by how reversible the action is. | `cookbooks/llm_guardrails` |
| Extraction as selection | Code finds candidate spans. A Choice picks one, with a "not stated" option. | Parse failures | The model cannot pick a value that was not offered. | `cookbooks/pre_parsed_value_extraction_cookbook`, `cookbooks/date_extraction_cookbook` |
| Extraction cascade | A small LLM extracts. Jev checks each field. Only suspicious records reach a large model. | Large-model calls | Measure the miss rate of the check. | `cookbooks/sde_cascade` |
| Triage and priority | One Score per axis, scaled to 0..1, combined with weights in code. | Human triage time | Tune the weights, not the prompts. | `patterns/composite-scoring` |
| Matching and dedup | One Score whose levels are the actions: merge, leave apart, send to a curator. | Curator workload | Candidate pairs come from code. | `cookbooks/entity_alignment` |
| Deep taxonomy | A Choice per level, with beam search where probabilities are close. | Accuracy at depth | Needs sequential requests. | `cookbooks/hierarchical_classification` |
| Claim against source | A Choice: the quoted context supports, contradicts, or does not address the claim. | Bad citations caught | Pass the surrounding context, not only the quote. | `cookbooks/citation_check` |
| Features for classical ML | Jev answers become numeric features for a trained model. | Model error | Needs labelled outcomes. | `cookbooks/autoresearch_feature_discovery` |
| Interactive state | User or player text becomes typed state changes such as intent, mood, or target. | Response time against an LLM call | The device needs a network connection. | `demos/smart-home` |

## Reshape, not only replace

Some gains come from changing the shape of the work so that a decision becomes typed.

1. Make options uniform.
   Give every option the same fields, such as `what`, `not_for`, and `examples`.
   For a catalog of skills or tools, that means structured "when to use" and "what it returns" fields instead of free prose.
   Uniform fields are what keep a hundred options separable in one Choice.
2. Move selection out of the context window.
   Keep the catalog in files or a database, select with Jev, and load only the winner.
3. Split a broad judgment.
   "Is this good?" hides several judgments.
   Ask each one separately and combine them in code.
4. Ask everything at once.
   Put branch-specific questions in the first request, and discard what the branch does not need.
5. Cascade.
   Let Jev settle the clear cases, and send the hold band to an LLM or a person.
6. Keep constants together.
   Put questions, thresholds, and weights in one file, since those are what gets reviewed and tuned.
