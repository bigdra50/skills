# Numbers from scripts

A number typed into the .tex goes stale without notice when the data or the analysis changes.
For numbers computed from data the repository keeps, a script prints the value and the .tex quotes it.
The build runs the script again and stops when a quoted value has moved.

## Files

| File | Written by | Holds |
| --- | --- | --- |
| `facts.json` | the writer | The commands that print values |
| `facts.tex` | `scripts/facts.py update` | One `\factdef{key}{value}` per line, grouped under the command that printed it. Commit it so the report builds without running the commands |
| `code/` | the writer | The scripts the commands call |

```json
{
  "commands": [
    {"run": "python3 code/replay_metrics.py --facts fig/replay_upstream.csv", "requires": ["fig/replay_upstream.csv"]},
    {"run": "uv run --no-sync python code/host_loop.py --facts", "requires": ["~/logs/host"]}
  ]
}
```

- `run`: one line, run by bash in the report directory. `cwd` moves it, relative to the report directory
- `requires`: paths relative to the report directory. When one is missing, for example raw logs kept on another machine, the command is skipped and the values it wrote before are kept
  - List only data outside the repository here. A missing file inside the repository is an error, and listing it would skip the check without notice

## What a command prints

- One JSON object on stdout, such as `{"lag-upstream": "267〜333", "gap-max": "5.80"}`. Anything else on stdout fails the run, so logs go to stderr
- Keys start with a lowercase letter and use only lowercase letters, digits, and `-`. They become TeX control-sequence names
- Values are strings or numbers. Format numbers as strings in the script to fix the digits (`f"{x:.2f}"`); Python prints `0.1 + 0.2` as `0.30000000000000004`
- `%`, `#`, `&`, `$`, and `_` are escaped. `\`, `{`, `}`, `~`, `^`, and line breaks are rejected because they would turn a value into markup. Print plain text and keep units and formatting in the .tex

A `--facts` flag beside the script's human-readable output keeps one script for both.

Have each measurement write its summary to a file in `fig/` when it runs, not only to stdout.
A value that exists only in a terminal cannot be quoted later without measuring again.

## In the .tex

The template defines `\fact` and `\factdef` and reads `facts.tex` when it exists.
`\fact{key}` works in these places:

- Running text, captions, and section titles, including their PDF bookmarks
- pgfplots coordinates
- siunitx `S` columns. The value aligns on the decimal point like a typed number (checked with siunitx 3.0.49)

When the same value appears at two precisions, keep one key and round in the .tex: `\num[round-mode=places,round-precision=1]{\fact{p99}}` prints 14.2 for a value of 14.20.
A value in exponent form, such as `6.9e-5`, prints as 6.9 × 10⁻⁵ with `\num{\fact{key}}`, in text and in tables.

Two uses fail:

- A key that `facts.tex` lacks stops the build with `Undefined fact`
- `\fact` inside `\code{}` prints as written, because `\code{}` takes its argument verbatim. The build does not notice; `facts.py` reports the line

## Workflow

1. Write the script so it prints the values, list it in `facts.json`, and run `python3 <skill>/scripts/facts.py update <report-dir>`
2. Quote each value with `\fact{key}`
3. Build with `scripts/build.sh`. When `facts.json` sits beside the .tex, it runs `facts.py check` first
4. When a value has moved, the check stops the build and prints the key, the old and new values, and each `file:line` that quotes it
5. Run `update`, then reread every listed line. The number follows the data, but the sentence around it ("about three times slower") may no longer hold

`build.sh --no-facts` skips the check while iterating on layout.

## What the check reports

| Report | Fails the check |
| --- | --- |
| A value changed, a key was added, or a key was removed | Yes |
| The .tex quotes a key that `facts.tex` lacks | Yes |
| `\fact` inside `\code{}` | Yes |
| A command skipped for a missing `requires` path | No; its keys keep their committed values |
| A key that no .tex quotes (`unused`) | No |

Some problems stop both `update` and `check` before anything is written, and `facts.tex` stays as it was.
They are a failing command, output that is not one JSON object, a bad key or value, and a key printed by two commands.

## Numbers that stay typed by hand

Numbers that cannot be recomputed from the repository stay typed in the .tex, with their source in the fact sheet.
These include values measured on hardware, read from logs the repository does not keep, or quoted from papers.
