#!/usr/bin/env python3
"""Markdown の文体指摘をルール別・ディレクトリ別に集計する。

md-prose-cleanup スキルの手順 1「実測する」で使う。
推測でルールを選ぶと鳴りっぱなしの設定ができるので、まずここで現状を数える。

Usage:
    python3 survey.py <target-repo> [--dotfiles <path>] [--json <out.json>]

<dotfiles>/scripts/md-lint.sh を JSON 形式で呼び、追跡している *.md を全件集計する。
"""

from __future__ import annotations

import argparse
import collections
import json
import os
import subprocess
import sys

# エージェント向けプロンプトが置かれやすい場所。
# 人間向け散文の規範を当てても直す価値が薄いので、除外候補として別枠で数える。
AGENT_FACING = (
    ".claude/commands/",
    ".claude/agents/",
    ".claude/output-styles/",
    ".claude/skills/",
    ".claude/tools/",
    ".apm/agents/",
)
AGENT_FACING_NAMES = ("AGENTS.md", "SKILL.md")


def tracked_md(repo: str) -> list[str]:
    out = subprocess.run(
        ["git", "-C", repo, "ls-files", "*.md"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return out.split()


def run_lint(
    dotfiles: str, repo: str, files: list[str]
) -> tuple[list[dict], list[str]]:
    """md-lint.sh を叩き、textlint の JSON と一文一行の指摘行を返す。"""
    env = dict(os.environ)
    env["MD_LINT_FORMAT"] = "json"
    proc = subprocess.run(
        ["bash", os.path.join(dotfiles, "scripts", "md-lint.sh")]
        + [os.path.join(repo, f) for f in files],
        capture_output=True,
        text=True,
        env=env,
        check=False,  # 指摘があると exit 1 なので、非ゼロを失敗として扱わない
    )
    if not proc.stdout.strip():
        sys.exit(f"md-lint.sh が何も返しませんでした:\n{proc.stderr[:2000]}")
    # textlint の JSON 配列の直後に sembr-check の出力が続く
    payload, end = json.JSONDecoder().raw_decode(proc.stdout)
    sembr = [line for line in proc.stdout[end:].splitlines() if line.strip()]
    return payload, sembr


def bucket(path: str) -> str:
    if path.startswith(AGENT_FACING) or path.endswith(AGENT_FACING_NAMES):
        return "エージェント向け（除外候補）"
    if "fixtures" in path or "/testdata/" in path:
        return "テストデータ（除外候補）"
    head = path.split("/")[0]
    return head if "/" in path else "（ルート直下）"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("repo")
    ap.add_argument(
        "--dotfiles",
        default=os.path.expanduser("~/dev/github.com/bigdra50/dotfiles"),
    )
    ap.add_argument("--json", dest="json_out")
    args = ap.parse_args()

    repo = os.path.abspath(args.repo)
    files = tracked_md(repo)
    if not files:
        sys.exit("追跡している *.md がありません")

    payload, sembr = run_lint(args.dotfiles, repo, files)

    by_rule: collections.Counter[str] = collections.Counter()
    by_file: collections.Counter[str] = collections.Counter()
    detail: dict[str, list] = collections.defaultdict(list)

    for entry in payload:
        rel = entry["filePath"].replace(repo + "/", "")
        for msg in entry["messages"]:
            rule = msg.get("ruleId") or "(unknown)"
            by_rule[rule] += 1
            by_file[rel] += 1
            detail[rule].append(
                [rel, msg["line"], " ".join(msg["message"].split())[:160]]
            )

    for line in sembr:
        rel = line.split(":", 1)[0].replace(repo + "/", "")
        by_rule["sembr(一文一行)"] += 1
        by_file[rel] += 1

    total = sum(by_rule.values())
    print(
        f"対象 {len(files)} ファイル / 指摘 {total} 件 / 指摘のあるファイル {len(by_file)}"
    )

    print("\n-- ルール別 --")
    for rule, count in by_rule.most_common():
        print(f"{count:6d}  {rule}")

    print("\n-- 区分別 --")
    by_bucket: collections.Counter[str] = collections.Counter()
    for path, count in by_file.items():
        by_bucket[bucket(path)] += count
    for name, count in by_bucket.most_common():
        share = 100 * count / total if total else 0
        print(f"{count:6d}  ({share:4.1f}%)  {name}")

    print("\n-- 指摘の多いファイル 15 --")
    for path, count in by_file.most_common(15):
        print(f"{count:6d}  {path}")

    excluded = sum(v for k, v in by_bucket.items() if "除外候補" in k)
    if excluded:
        print(
            f"\n除外候補を外すと {total} 件が {total - excluded} 件になる。"
            "\nこれらを対象に含めるかどうかをユーザーに確認すること。"
        )

    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump(
                {"by_rule": dict(by_rule), "by_file": dict(by_file), "detail": detail},
                fh,
                ensure_ascii=False,
                indent=1,
            )
        print(f"\n詳細を {args.json_out} に書き出しました")


if __name__ == "__main__":
    main()
