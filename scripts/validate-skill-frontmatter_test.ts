import { assertEquals } from "jsr:@std/assert@1";
import { join } from "jsr:@std/path@1";

const SCRIPT = new URL("./validate-skill-frontmatter.ts", import.meta.url)
  .pathname;

function writeSkill(dir: string, body: string): string {
  const path = join(dir, "SKILL.md");
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

Deno.test("accepts valid YAML frontmatter with quoted colon", async () => {
  const dir = Deno.makeTempDirSync();
  try {
    const skill = writeSkill(
      dir,
      `---
name: example-skill
description: "Use when a description contains: a colon."
---

# Example Skill
`,
    );
    const { stdout, success } = await runScript(skill);
    assertEquals(success, true);
    assertEquals(stdout.includes("skill frontmatter ok (1 files)"), true);
  } finally {
    Deno.removeSync(dir, { recursive: true });
  }
});

Deno.test("rejects invalid YAML frontmatter", async () => {
  const dir = Deno.makeTempDirSync();
  try {
    const skill = writeSkill(
      dir,
      `---
name: broken-skill
description: Use when a description contains: an unquoted colon.
---

# Broken Skill
`,
    );
    const { stderr, success } = await runScript(skill);
    assertEquals(success, false);
    assertEquals(stderr.includes("invalid YAML frontmatter"), true);
  } finally {
    Deno.removeSync(dir, { recursive: true });
  }
});

Deno.test("rejects missing frontmatter", async () => {
  const dir = Deno.makeTempDirSync();
  try {
    const skill = writeSkill(dir, "# No Frontmatter\n");
    const { stderr, success } = await runScript(skill);
    assertEquals(success, false);
    assertEquals(stderr.includes("missing YAML frontmatter"), true);
  } finally {
    Deno.removeSync(dir, { recursive: true });
  }
});

Deno.test("rejects non-mapping frontmatter", async () => {
  const dir = Deno.makeTempDirSync();
  try {
    const skill = writeSkill(
      dir,
      `---
- name
- description
---

# Broken Skill
`,
    );
    const { stderr, success } = await runScript(skill);
    assertEquals(success, false);
    assertEquals(stderr.includes("frontmatter must be a YAML mapping"), true);
  } finally {
    Deno.removeSync(dir, { recursive: true });
  }
});
