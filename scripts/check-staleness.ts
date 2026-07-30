interface Issue {
  path: string;
  line: number;
  column: number;
  rule: string;
  match: string;
  hint: string;
}

interface Rule {
  id: string;
  pattern: RegExp;
  hint: string;
}

// A skill only earns its context cost by carrying what the model does not already
// know. Both rules below flag the opposite case: text that overrides what the model
// knows correctly, which makes the skill actively harmful rather than merely stale.
const RULES: Rule[] = [
  {
    id: "retired agent API",
    // `Task(` predates the Agent tool; `TodoWrite` predates the Task* tools.
    pattern: /\bTask\(|\bTodoWrite\b/g,
    hint: "use the Agent tool and the Task* tools instead",
  },
  {
    id: "hardcoded model generation",
    // Generation-tagged ids (claude-opus-4-6, gpt-5.4, Opus 5) go out of date on
    // every release. Unversioned aliases (`--model opus`) survive, so allow those.
    pattern:
      /\b(?:claude-)?(?:opus|sonnet|haiku|fable)[-\s.]?\d+(?:[.-]\d+)?\b|\bgpt-\d+(?:\.\d+)?\b|\bgemini-\d+(?:\.\d+)?\b|\bo[34]-(?:mini|preview)\b/gi,
    hint: "drop the generation, or use an unversioned alias such as `opus`",
  },
];

// Escape hatch for docs that must quote a bad example verbatim.
const WAIVER = "staleness-ok";

function repoRoot(): string {
  const cmd = new Deno.Command("git", {
    args: ["rev-parse", "--show-toplevel"],
    stdout: "piped",
    stderr: "null",
  });
  const { success, stdout } = cmd.outputSync();
  if (!success) throw new Error("not a git repository");
  return new TextDecoder().decode(stdout).trim();
}

function trackedMarkdownFiles(): string[] {
  const root = repoRoot();
  const cmd = new Deno.Command("git", {
    args: ["-C", root, "ls-files", "-z", "--", ":(glob)**/*.md"],
    stdout: "piped",
    stderr: "null",
  });
  const { success, stdout } = cmd.outputSync();
  if (!success) return [];
  return new TextDecoder()
    .decode(stdout)
    .split("\0")
    .filter((p) => p.length > 0)
    .map((p) => `${root}/${p}`);
}

function inspect(path: string): Issue[] {
  let text: string;
  try {
    text = Deno.readTextFileSync(path);
  } catch {
    return [];
  }

  const issues: Issue[] = [];
  text.split("\n").forEach((line, index) => {
    if (line.includes(WAIVER)) return;
    for (const rule of RULES) {
      rule.pattern.lastIndex = 0;
      for (const m of line.matchAll(rule.pattern)) {
        issues.push({
          path,
          line: index + 1,
          column: (m.index ?? 0) + 1,
          rule: rule.id,
          match: m[0],
          hint: rule.hint,
        });
      }
    }
  });
  return issues;
}

function formatIssue(i: Issue): string {
  return `${i.path}:${i.line}:${i.column}: ${i.rule}: "${i.match}" — ${i.hint}`;
}

const files =
  Deno.args.length > 0
    ? Deno.args.filter((a) => a.endsWith(".md"))
    : trackedMarkdownFiles();

const issues = files.flatMap(inspect);

if (issues.length === 0) {
  console.log(`staleness check ok (${files.length} files)`);
  Deno.exit(0);
} else {
  console.error(`staleness check failed (${issues.length} issues)`);
  for (const issue of issues) {
    console.error(formatIssue(issue));
  }
  console.error(
    `\nAdd an inline "${WAIVER}: <reason>" comment on a line that must keep the pattern.`,
  );
  Deno.exit(1);
}
