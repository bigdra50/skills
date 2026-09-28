#!/usr/bin/env python3
"""Check the figure and table rules that can be read off a paper-report .tex source.

    check_source.py <file.tex>

Prints two counts on stdout, "sentences small":
- sentences: Japanese full stops inside tabular bodies. A full stop in a cell means a
  sentence sits there; explanations belong in the text or the caption
- small: uses of \\tiny and of \\fontsize below 7 pt, the minimum text size for figures

Each offending line goes to stderr so the writer can find it.
"""

from __future__ import annotations

import re
import sys

MIN_PT = 7.0
TABLE_ENV = re.compile(r"\\begin\{(tabularx|tabular\*?|longtable)\}(.*?)\\end\{\1\}", re.S)
FONTSIZE = re.compile(r"\\fontsize\{([\d.]+)\}")
TINY = re.compile(r"\\tiny(?![A-Za-z])")
COMMENT = re.compile(r"(?<!\\)%.*")


def strip_comments(src: str) -> str:
    """Drop LaTeX comments so rules written in comments do not count."""
    return "\n".join(COMMENT.sub("", line) for line in src.splitlines())


def table_sentences(src: str) -> list[str]:
    """Return the table lines that contain a Japanese full stop, one entry per stop."""
    hits: list[str] = []
    for match in TABLE_ENV.finditer(src):
        for line in match.group(2).splitlines():
            hits.extend([line.strip()] * line.count("。"))
    return hits


def small_text(src: str) -> list[str]:
    """Return the lines that set text below the minimum size, one entry per use."""
    hits: list[str] = []
    for line in src.splitlines():
        count = len(TINY.findall(line))
        count += sum(1 for size in FONTSIZE.findall(line) if float(size) < MIN_PT)
        hits.extend([line.strip()] * count)
    return hits


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    with open(argv[1], encoding="utf-8") as f:
        src = strip_comments(f.read())
    sentences = table_sentences(src)
    small = small_text(src)
    for line in sentences:
        print(f"table cell sentence: {line[:80]}", file=sys.stderr)
    for line in small:
        print(f"text below {MIN_PT:g} pt: {line[:80]}", file=sys.stderr)
    print(len(sentences), len(small))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
