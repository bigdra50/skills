# Measuring before and after

Nothing is spent without consent.
Jev itself costs almost nothing to call.
The real spend is the other model's tokens, the agent's own tokens for writing and running scripts, and the user's time.

## 1. Show the plan first

Before running anything, tell the user:

- the decision being measured
- the two arms: before is the current implementation, after is Jev
- how many cases, and where the labels come from
- which metrics will be reported
- the estimated spend: Jev tokens and dollars, the other model's tokens, the agent tokens for the scripts, and the wall-clock time

Offer the next cheaper tier as the alternative, then ask whether to go ahead.
If the answer is no, stop at the paper estimate.

## 2. Pick the cheapest tier that answers the question

| Tier | Answers | Costs |
| --- | --- | --- |
| 0. Paper estimate | Is it plausible at all? Tokens, cost, and latency come from the table in SKILL.md. | Nothing |
| 1. Probe | Does Jev separate the clear cases? Send 10 to 30 real inputs and read the probabilities. | A fraction of a cent on Jev, and a few thousand agent tokens for the script |
| 2. Labelled comparison | Is after better than before? Run 30 to 100 labelled cases through both arms. | Jev is negligible. The before arm costs what it costs today, times the number of cases. |
| 3. End-to-end agent A/B | Does a workflow change save tokens without hurting results? Run the same fixed prompts with and without the change, at least three runs each. | Prompts times runs times the average session tokens. This is usually the only expensive tier, so always quote the number first. |

## 3. Cases and labels

- Prefer real inputs: git history, past incidents, existing fixtures, and logs.
- Include cases near the boundary, and cases where nothing should fire.
- Use existing ground truth first. Otherwise ask the user to label.
- Use model-written labels only with the user's agreement, and say so in the report.
- When there are enough cases, tune the questions on one part and report on the other.
- Remove secrets and personal data before a case leaves the machine.

## 4. Metrics

| Metric | How |
| --- | --- |
| Accuracy | Correct over answered, per question |
| Coverage | Answered over labelled, after the hold band removes uncertain answers |
| Confusion | TP, FP, TN, and FN for yes or no questions. Say which error is the costly one. |
| Latency | p50 and p95, measured the way it will run: a cold process for a hook, a warm connection for a server |
| Cost per 1,000 decisions | Tokens times price for each arm, including the other model's output tokens |
| Agent tokens, tier 3 only | Input, output, and cache-read tokens and the cost per run. Report the mean and the range. |
| Stability | Run the after arm twice and count the decisions that flipped |

## 5. Running it

- Write throwaway scripts in a scratch or temp directory.
- Do not add dependencies to the target repository or commit to it unless asked.
- Read the key from `TYPESAFE_API_KEY`. Never print it, and never write request headers to a file.
- Send one request per case with all the questions in it.
- Pin the versioned model ID, and record the `model` field of the response.
- Set a timeout, and retry on 429, 503, and 529.
- For tier 3, use headless agent runs that report usage as JSON, such as `claude -p --output-format json`.
- In tier 3, keep the prompts and the model the same, start a fresh session for each run, and change one thing only.
- If the first few cases show that the questions are wrong, stop and fix them instead of spending the rest.

## 6. Report

Give a before and after table, the misses worth reading, and one verdict.
The verdict is one of: adopt, adopt with a hold band, or not worth it.

State the number of cases, the label source, the model version, and the date.
Say plainly when the sample is too small to decide.
With 30 cases, a gap of ten points is within noise.
