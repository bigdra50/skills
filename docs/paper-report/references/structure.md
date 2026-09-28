# Chapter structure

The skeleton below is the default.
Keep the order, drop a chapter that would have no content, and never pad one to fill the slot.
Headings are given in Japanese (the default output language) with the English equivalent in parentheses.

## Title block

- Kind and date: `技術報告　YYYY-MM-DD`
- Title that says what was done with what: `iPad 1 台の LiDAR と ARKit による XLeRobot の自律走行`
- English title in italics under it
- Scope line: the repository name and path the report covers, and the period. Leave out the owner or account name, commit hashes, and who or what assembled the report
- Abstract box spanning both columns, then a keyword line

The abstract carries the whole result in 5-8 sentences: purpose, what was done, the key numbers, what else exists.
A reader who stops after the abstract should still know the outcome.

## 1 はじめに (Introduction)

- 1.1 背景: what the reader does not know yet; what existing tools do and what they lack
- 1.2 目的と全体像: the goal in one sentence, then the overview figure (Figure 1)
- 1.3 本報告の内容と読み方: contributions as a list with chapter pointers; which chapter to start from for a newcomer and for someone who only wants the status

## 2 予備知識 (Primer)

Only when the reader is new to the domain.
Explain each concept with the names that appear later: real node, topic, file, and parameter names.
The primer then doubles as a map of the system.
One figure for the core communication or data model is usually worth it.
Define every abbreviation at first use.

## 3 システム構成 (System)

- Hardware table: element, specification, role
- Software table: component, inputs, outputs, role; mark the ones this work built
- To-scale drawings for anything physical (layout, geometry, field of view)
- External dependencies described by what they provide, not how they are built

## 4 手法 (Method)

One subsection per technique.
Numbered equations with every symbol defined in the text and the source of every constant (measured, from vendor code, chosen).
State the reason for each design decision next to it.
When a decision is driven by a constraint (sensor field of view, bandwidth, clock skew), say which constraint.

## 5 実験と結果 (Experiments and results)

- Where and how the experiments ran
- One subsection per question, in the order the work answered them
- Each subsection: question, what was run, a table or chart of the numbers, what the numbers say, problems found on the way
- Put the external reference next to each comparison (what counted as ground truth)

## 6 考察 (Discussion)

What the results mean together, the limits of the approach, environmental constraints, and which ways of working paid off.
Compare with published prior work only on points the reader can check.

## 7 現状と今後 (Status and next steps)

This chapter is what a catching-up reader needs most.

- 7.1 成果物の一覧: deliverables with location and status. Define the status words in the text:
  - 実機: verified on the real system with recorded numbers
  - 実装: built, no recorded result
  - 未コミット: not committed yet
- 7.2 作業中の変更: uncommitted work, with what it is for and what has not been verified
- 7.3 残る課題: open problems as a list

## References (参考文献)

`thebibliography` with numbered entries.
Cite papers with authors, title, venue, year.
When the authors are unknown, cite the title and the identifier (arXiv ID, URL) only.

## Appendices

- 付録 A 用語の対応: when the sources use coined or informal terms, map them to standard terms
- 付録 B 起動の手順: the minimal commands to reproduce, wrapped to fit a column (about 55 characters per line)
- 付録 C 開発の経過: a dated table, one row per phase. Build it from `git log`, but leave commit hashes out

## Checklist before building

- [ ] Every number in the text appears in a source note or log, with the same value
- [ ] Every figure and table is referenced from the text before it appears
- [ ] Results that were not recorded are stated as such, not omitted
- [ ] Status table distinguishes verified, built-only, and uncommitted
- [ ] No photos of private spaces; no personal names, device IDs, or credentials
- [ ] No account names, commit hashes, author or tool credits, or paths to the Markdown sources (README, notes)
