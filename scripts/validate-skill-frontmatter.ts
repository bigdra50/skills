import { parse as parseYaml } from "jsr:@std/yaml@1";

interface ValidationError {
  path: string;
  line?: number;
  column?: number;
  message: string;
}

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

function trackedSkillFiles(): string[] {
  const root = repoRoot();
  const cmd = new Deno.Command("git", {
    args: ["-C", root, "ls-files", "-z", "--", ":(glob)**/SKILL.md"],
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

function validate(path: string): ValidationError | null {
  let text: string;
  try {
    text = Deno.readTextFileSync(path);
  } catch {
    return { path, line: 1, message: "file not found" };
  }

  const lines = text.split("\n");
  if (lines[0]?.trimEnd() !== "---") {
    return { path, line: 1, column: 1, message: "missing YAML frontmatter" };
  }

  const closeIndex = lines.slice(1).findIndex((l) => l.trimEnd() === "---");
  if (closeIndex === -1) {
    return {
      path,
      line: 1,
      column: 1,
      message: "missing closing frontmatter delimiter",
    };
  }

  const yamlContent = lines.slice(1, closeIndex + 1).join("\n");
  let parsed: unknown;
  try {
    parsed = parseYaml(yamlContent);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return {
      path,
      line: 2,
      message: `invalid YAML frontmatter: ${msg.split("\n")[0]}`,
    };
  }

  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    return {
      path,
      line: 2,
      column: 1,
      message: "frontmatter must be a YAML mapping",
    };
  }

  return null;
}

function formatError(err: ValidationError): string {
  let location = err.path;
  if (err.line) location += `:${err.line}`;
  if (err.column) location += `:${err.column}`;
  return `${location}: ${err.message}`;
}

const files =
  Deno.args.length > 0
    ? Deno.args.filter((a) => a.endsWith("SKILL.md"))
    : trackedSkillFiles();

const errors = files
  .map((f) => validate(f))
  .filter((e): e is ValidationError => e !== null);

if (errors.length === 0) {
  console.log(`skill frontmatter ok (${files.length} files)`);
  Deno.exit(0);
} else {
  console.error(
    `skill frontmatter check failed (${errors.length} errors)`,
  );
  for (const err of errors) {
    console.error(formatError(err));
  }
  Deno.exit(1);
}
