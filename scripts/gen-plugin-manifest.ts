// Generates the Claude plugin manifest that makes a category installable as one
// APM entry (`apm install bigdra50/skills/<root>`) instead of one entry per skill.
//
// The whole file is generated, metadata included. apm silently drops a skill that
// the manifest fails to list — and it also silently drops any path outside the
// manifest's own directory — so a hand-maintained `skills` array turns a typo into
// a missing skill with no error anywhere. Generating from the filesystem and
// verifying in `pre-commit` is what makes that failure mode unreachable.

import { parse as parseYaml } from "jsr:@std/yaml@1";

interface Bundle {
  /** Repo-relative directory that becomes the package root. */
  root: string;
  name: string;
  description: string;
  version: string;
}

const BUNDLES: Bundle[] = [
  {
    root: "unity",
    name: "bigdra50-unity",
    description:
      "Unity / C# development skills — project bootstrap, CI, coding guides, the review system, and reviewer perspectives.",
    version: "0.1.0",
  },
  {
    root: "github",
    name: "bigdra50-github",
    description:
      "GitHub workflow skills — pull request creation, reviewer briefings, and issue reporting.",
    version: "0.1.0",
  },
  {
    root: "claude-code",
    name: "bigdra50-claude-code",
    description:
      "Skills for running Claude Code itself — session logs, usage stats, compaction prep, task orchestration, and configuration knowledge.",
    version: "0.1.0",
  },
];

const MANIFEST_PATH = ".claude-plugin/plugin.json";

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

/** Skill directories under `root`, as paths relative to `root`. */
function skillDirs(repo: string, root: string): string[] {
  const cmd = new Deno.Command("git", {
    args: ["-C", repo, "ls-files", "-z", "--", `:(glob)${root}/**/SKILL.md`],
    stdout: "piped",
    stderr: "null",
  });
  const { success, stdout } = cmd.outputSync();
  if (!success) throw new Error("git ls-files failed");
  return new TextDecoder()
    .decode(stdout)
    .split("\0")
    .filter((p) => p.length > 0)
    .filter((p) => !p.includes("/examples/"))
    .map((p) => p.replace(/\/SKILL\.md$/, "").slice(root.length + 1))
    .sort();
}

/** Cross-check against frontmatter so a renamed directory cannot drift from `name:`. */
function frontmatterName(path: string): string | null {
  const text = Deno.readTextFileSync(path);
  if (!text.startsWith("---\n")) return null;
  const closing = text.indexOf("\n---", 4);
  if (closing === -1) return null;
  const fm = parseYaml(text.slice(4, closing)) as Record<string, unknown>;
  return typeof fm.name === "string" ? fm.name : null;
}

function manifest(bundle: Bundle, dirs: string[]): string {
  return JSON.stringify(
    {
      name: bundle.name,
      version: bundle.version,
      description: bundle.description,
      skills: dirs.map((d) => `./${d}`),
    },
    null,
    2,
  ) + "\n";
}

const checkMode = Deno.args.includes("--check");
const repo = repoRoot();
const drift: string[] = [];
const mismatches: string[] = [];

for (const bundle of BUNDLES) {
  const dirs = skillDirs(repo, bundle.root);
  if (dirs.length === 0) {
    drift.push(`${bundle.root}: no tracked SKILL.md found`);
    continue;
  }

  for (const d of dirs) {
    const dirName = d.split("/").pop()!;
    const fmName = frontmatterName(`${repo}/${bundle.root}/${d}/SKILL.md`);
    if (fmName && fmName !== dirName) {
      mismatches.push(
        `${bundle.root}/${d}: directory name != frontmatter name (${fmName})`,
      );
    }
  }

  const target = `${repo}/${bundle.root}/${MANIFEST_PATH}`;
  const next = manifest(bundle, dirs);
  let current: string | null = null;
  try {
    current = Deno.readTextFileSync(target);
  } catch {
    current = null;
  }

  if (current === next) {
    if (!checkMode) console.log(`ok ${bundle.root}/${MANIFEST_PATH}`);
    continue;
  }

  if (checkMode) {
    drift.push(`${bundle.root}/${MANIFEST_PATH} is out of sync (${dirs.length} skills)`);
    continue;
  }

  Deno.mkdirSync(`${repo}/${bundle.root}/.claude-plugin`, { recursive: true });
  Deno.writeTextFileSync(target, next);
  console.log(`synced ${bundle.root}/${MANIFEST_PATH} (${dirs.length} skills)`);
}

if (mismatches.length > 0) {
  console.error("skill directory / frontmatter name mismatch:");
  for (const m of mismatches) console.error(`  ${m}`);
  Deno.exit(1);
}

if (drift.length > 0) {
  console.error(
    checkMode
      ? "plugin manifest check failed — run `mise run gen:plugin-manifest`"
      : "plugin manifest generation failed",
  );
  for (const d of drift) console.error(`  ${d}`);
  Deno.exit(1);
}

if (checkMode) console.log(`plugin manifests up to date (${BUNDLES.length})`);
