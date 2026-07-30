import { assertEquals } from "jsr:@std/assert@1";
import { join } from "jsr:@std/path@1";

const SCRIPT = new URL("./check-staleness.ts", import.meta.url).pathname;

function writeDoc(dir: string, body: string, name = "SKILL.md"): string {
  const path = join(dir, name);
  Deno.writeTextFileSync(path, body);
  return path;
}

async function runScript(
  ...paths: string[]
): Promise<{ stdout: string; stderr: string; success: boolean }> {
  const cmd = new Deno.Command("deno", {
    args: ["run", "--allow-read", "--allow-run=git", SCRIPT, ...paths],
    stdout: "piped",
    stderr: "piped",
  });
  const output = await cmd.output();
  return {
    stdout: new TextDecoder().decode(output.stdout),
    stderr: new TextDecoder().decode(output.stderr),
    success: output.success,
  };
}

async function withDoc(
  body: string,
  fn: (r: { stdout: string; stderr: string; success: boolean }) => void,
) {
  const dir = Deno.makeTempDirSync();
  try {
    fn(await runScript(writeDoc(dir, body)));
  } finally {
    Deno.removeSync(dir, { recursive: true });
  }
}

Deno.test("detects the retired Task( agent call", async () => {
  await withDoc(
    "# Doc\n\nTask(\n  subagent_type: \"Explore\",\n)\n",
    ({ stderr, success }) => {
      assertEquals(success, false);
      assertEquals(stderr.includes("retired agent API"), true);
      assertEquals(stderr.includes(":3:"), true);
    },
  );
});

Deno.test("detects the retired TodoWrite tool", async () => {
  await withDoc("# Doc\n\n常に TodoWrite で可視化する。\n", ({ stderr, success }) => {
    assertEquals(success, false);
    assertEquals(stderr.includes("retired agent API"), true);
  });
});

Deno.test("detects a hyphenated model id", async () => {
  await withDoc("# Doc\n\nclaude --model claude-opus-4-6\n", ({ stderr, success }) => {
    assertEquals(success, false);
    assertEquals(stderr.includes("hardcoded model generation"), true);
  });
});

Deno.test("detects a gpt model id", async () => {
  await withDoc("# Doc\n\n--models security=gpt-5.4\n", ({ stderr, success }) => {
    assertEquals(success, false);
    assertEquals(stderr.includes("hardcoded model generation"), true);
  });
});

Deno.test("detects a prose model generation such as Opus 5", async () => {
  await withDoc("# Doc\n\n基本は Opus 5 を推奨する。\n", ({ stderr, success }) => {
    assertEquals(success, false);
    assertEquals(stderr.includes("hardcoded model generation"), true);
  });
});

Deno.test("detects a gemini model id", async () => {
  await withDoc("# Doc\n\nreviewer: gemini-3.1-pro\n", ({ stderr, success }) => {
    assertEquals(success, false);
    assertEquals(stderr.includes("hardcoded model generation"), true);
  });
});

Deno.test("honors an inline staleness-ok waiver", async () => {
  await withDoc(
    "# Doc\n\n`--model claude-opus-4-6` <!-- staleness-ok: documents the bad pattern -->\n",
    ({ stdout, success }) => {
      assertEquals(success, true);
      assertEquals(stdout.includes("staleness check ok"), true);
    },
  );
});

Deno.test("does not flag product names or unversioned aliases", async () => {
  await withDoc(
    `# Doc

Works in Claude Code, Codex, Cursor and Gemini CLI.
Use \`--model opus\` or \`--model sonnet\` without a generation.
Anthropic ships Claude models; OpenAI ships GPT models.
`,
    ({ stdout, success }) => {
      assertEquals(success, true);
      assertEquals(stdout.includes("staleness check ok"), true);
    },
  );
});

Deno.test("reports every offending line, not just the first", async () => {
  await withDoc(
    "# Doc\n\ngpt-5 here\nTodoWrite there\nclaude-sonnet-4.6 too\n",
    ({ stderr, success }) => {
      assertEquals(success, false);
      assertEquals(stderr.includes("3 issues"), true);
    },
  );
});
