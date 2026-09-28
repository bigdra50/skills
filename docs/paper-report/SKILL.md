---
name: paper-report
description: |
  Turn a body of work (an experiment series, a system, a research spike) into a human-facing
  document in technical-paper form: title block, abstract, numbered chapters from background
  and a primer through method, results, discussion, and current status, figures drawn from the
  real mechanism, tables of measured values, references, and appendices.
  Output is LaTeX compiled to PDF with Tectonic (A4 two-column, Hiragino with the Source font
  family, TikZ and pgfplots figures), checked by rendering every page.
  Use when the user wants to catch up on, explain, or hand over work to a reader who does not
  know the domain yet: 「論文形式でまとめて」「論文っぽく」「技術報告にまとめて」「LaTeX で書いて」
  「PDF の資料にして」「実験内容を解説して」「キャッチアップ用の資料」, or "write it up as a paper".
  Not for slides, not for docs that live in a repository (docs-architect),
  and not for polishing one Markdown file (japanese-tech-writing).
user-invocable: true
---

# Paper-format report

A paper's fixed skeleton lets a cold reader find what they need without reading everything.
The abstract gives the outcome and the primer gives the concepts.
The method explains how, the results hold the numbers, and the status chapter says what exists now.
This skill produces that document from project sources and typesets it as a PDF.

## Settle before writing

- Reader and goal: one sentence such as "a reader who has never used ROS 2 understands the current deliverables". Ask only when the request does not imply it
- Sources: repositories, design notes, experiment logs, `git log`, and the uncommitted diff
- Location: next to the sources, for example `<repo>/<area>/report/`, left untracked. Ask before committing it. If the repository is public, point out any private details (room layouts, names) before it is committed

## Workflow

1. Gather facts.
   Read the README and design docs, experiment notes, the code that implements each claim, `git log` for the timeline, and `git status` for work in progress.
   Delegate long notes to sub-agents and ask them for claims with their numbers and `file:line`.
   Keep a fact sheet: claim, value, source, and status.
   Status is one of: verified on the real system, implemented without a recorded result, uncommitted, not recorded.
2. Outline with the chapter skeleton in [references/structure.md](references/structure.md).
   Drop chapters the material cannot fill.
3. Plan the figures with [references/figures.md](references/figures.md).
   List the mechanisms the reader must see; each figure makes one claim.
   Start from the real artifact.
   Measured comparisons become charts, and the project's own models are rendered; schematics cover the rest.
4. Copy [templates/paper.tex](templates/paper.tex) and write the report into it.
   Copy any raster data image into `fig/` beside the `.tex`.
5. Build and check with `scripts/build.sh <file.tex> <pages-dir>`.
   It compiles and renders every page with a contact sheet.
   It fails on overfull boxes, missing glyphs, undefined references, sentences inside table cells, and text below 7 pt.
   Fix what it reports, then check each figure page at 150 dpi against the list in [references/figures.md](references/figures.md).
   Label collisions, hidden overlays, and squeezed table columns only show up this way.
   [references/latex-pitfalls.md](references/latex-pitfalls.md) lists the failures seen so far and their fixes.
6. Deliver.
   Open the PDF (`open` on macOS) and send it with the host's file-sending tool when there is one.
   Report in a few lines: where the files are, the build command, and what could not be verified from the sources.

## Writing rules

- Every number traces to a source. When a result was not recorded, say so in the text instead of leaving the topic out
- The report stands on its own. Leave out account names, commit hashes, who or what assembled it, and paths to the Markdown files it was built from (README, notes)
- The status chapter separates verified, implemented-only, and uncommitted work
- Define every term and abbreviation at first use. The primer uses the project's real names so it doubles as a map
- When the sources use coined or informal terms, keep standard terms in the text and add an appendix that maps the two
- Restructure notes and agent output into short sentences and lists; never paste them
- Tables hold numbers and short labels. Explanations go in the text or the caption, not in the cells
- Cite papers with authors, title, venue, and year. When the authors are unknown, cite only the title and identifier
- Leave out photos of private spaces, personal names, device IDs, and credentials; a map or a diagram carries the same information
- Japanese prose: plain form (である調), one claim per sentence, no bold in running text, no em dashes. Follow japanese-tech-writing when it is installed

## Typesetting defaults

The template encodes these; change them only when the user asks.

| Item | Default |
| --- | --- |
| Class | `bxjsarticle` with `xelatex,ja=standard,a4paper,twocolumn,10pt` |
| Japanese | Body Hiragino Mincho ProN W3 and W6; headings and figures Hiragino Sans W3 and W6 |
| Latin | Source Serif Pro at 94 %, Source Sans Pro, Source Code Pro at 88 % |
| Math | STIX Two Math at 96 % |
| Tables | booktabs and tabularx, caption above, siunitx `S` columns align the decimal points, units in the header |
| Figures | TikZ and pgfplots, caption below, `figure*` for wide diagrams, text at 7 pt or larger |
| Identifiers | `\code{}`, a robust url-style command that breaks long names; ASCII only |

Hiragino ships with macOS, so the default build needs macOS.
Elsewhere, replace the two `\setja...font` lines with installed Japanese fonts.
Latin and math fonts come from the Tectonic bundle on every platform.

When the user asks for a web page instead of a PDF, publish the same chapter structure as an HTML page with inline SVG figures.
Use the host's page-publishing tool for this when it has one.

## Resources

- [templates/paper.tex](templates/paper.tex): preamble, title block, abstract, chapter skeleton, a wide TikZ diagram, a signed bar chart, a numeric table, a status table, references. Builds as is
- [scripts/build.sh](scripts/build.sh): build, log and source checks, page images, contact sheet
- [references/structure.md](references/structure.md): what each chapter holds, and the pre-build checklist
- [references/figures.md](references/figures.md): which figures to draw, the style rules, the figure-page checklist, and the TikZ and pgfplots patterns
- [references/latex-pitfalls.md](references/latex-pitfalls.md): symptoms, causes, and fixes
