#!/usr/bin/env python3
"""docs-architect 診断用の事実収集スクリプト。

repo を走査してドキュメント関連の「事実」を JSON で出力する。
判定・解釈はしない (stage / 種別の判定は呼び出し側の LLM が行う)。

Usage: python3 docs_inventory.py [repo-root]
依存: python3 標準ライブラリ + git (任意。無くても動く)
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

DOC_EXTS = {".md", ".mdx", ".rst", ".adoc", ".txt"}
DOC_DIR_NAMES = {
    "docs", "doc", "documentation", "website", "contribute", "guide",
    "guides", "wiki", "handbook", "specs", "adr", "rfcs", "runbooks",
}
SKIP_DIRS = {
    ".git", "node_modules", "vendor", "target", "dist", "build", "out",
    ".next", ".nuxt", "__pycache__", ".venv", "venv", "Library", "obj",
    ".tox", "coverage", ".cache", "third_party",
}
ROOT_DOC_PATTERNS = [
    "README", "CONTRIBUTING", "CHANGELOG", "CHANGES", "HISTORY", "LICENSE",
    "COPYING", "SECURITY", "CODE_OF_CONDUCT", "GOVERNANCE", "MAINTAINERS",
    "AUTHORS", "SUPPORT", "AGENTS", "CLAUDE", "GEMINI", "AI_POLICY",
    "DEVELOPMENT", "BUILDING", "INSTALL", "RELEASE", "UPGRADING", "GUIDE",
    "FAQ", "ADVANCED", "PLAN", "ROADMAP", "ONBOARDING", "PERMISSIONS",
    "FEDERATION", "PHILOSOPHY", "WORKFLOW", "STYLE", "TESTING",
]
GENERATOR_MARKERS = {
    "docusaurus": ["docusaurus.config.js", "docusaurus.config.ts"],
    "mkdocs": ["mkdocs.yml", "mkdocs.yaml"],
    "sphinx": ["docs/conf.py", "doc/conf.py", "docs/source/conf.py"],
    "mdbook": ["book.toml", "guide/book.toml"],
    "vitepress": [".vitepress", "docs/.vitepress"],
    "hugo": ["hugo.toml", "config.toml+content", "hugo.yaml"],
    "jekyll": ["_config.yml"],
    "nextra": ["theme.config.tsx", "theme.config.jsx"],
    "starlight/astro": ["astro.config.mjs", "astro.config.ts"],
}
PROJECT_SIGNALS = [
    # (キー, 存在を確認するパス)
    ("package_json", "package.json"),
    ("pyproject", "pyproject.toml"),
    ("setup_py", "setup.py"),
    ("cargo_toml", "Cargo.toml"),
    ("go_mod", "go.mod"),
    ("gemfile", "Gemfile"),
    ("csproj_or_sln", None),  # glob で別途
    ("dockerfile", "Dockerfile"),
    ("docker_compose", "docker-compose.yml"),
    ("docker_compose_yaml", "docker-compose.yaml"),
    ("compose_yaml", "compose.yaml"),
    ("devcontainer", ".devcontainer"),
    ("helm_chart", "chart"),
    ("k8s_dir", "k8s"),
    ("env_example", ".env.example"),
    ("env_sample", ".env.sample"),
    ("github_dir", ".github"),
    ("issue_templates", ".github/ISSUE_TEMPLATE"),
    ("pr_template", ".github/PULL_REQUEST_TEMPLATE.md"),
    ("workflows", ".github/workflows"),
    ("codeowners", ".github/CODEOWNERS"),
    ("llms_txt", "llms.txt"),
    ("openapi_json", "openapi.json"),
    ("openapi_yaml", "openapi.yaml"),
    ("migrations_dir", "migrations"),
    ("db_dir", "db/migrate"),
]

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s#]+)(?:#[^)]*)?\)")


def run_git(args, cwd):
    try:
        r = subprocess.run(
            ["git"] + args, cwd=cwd, capture_output=True, text=True, timeout=30
        )
        return r.stdout.strip() if r.returncode == 0 else None
    except Exception:
        return None


def file_info(path: Path, root: Path, use_git: bool):
    rel = str(path.relative_to(root))
    info = {"path": rel, "bytes": path.stat().st_size}
    if use_git:
        ts = run_git(["log", "-1", "--format=%cs", "--", rel], root)
        if ts:
            info["last_commit"] = ts
    return info


def collect_doc_files(root: Path):
    """doc 拡張子のファイルを列挙 (SKIP_DIRS を除外)。"""
    results = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")]
        # ドット始まりでも .github / .devcontainer 等は見たい
        for special in (".github", ".devcontainer", ".vitepress"):
            sp = Path(dirpath) / special
            if sp.is_dir() and special not in dirnames:
                dirnames.append(special)
        for fn in filenames:
            p = Path(dirpath) / fn
            stem_upper = p.stem.upper()
            is_doc_ext = p.suffix.lower() in DOC_EXTS
            is_root_doc = any(stem_upper.startswith(pat) for pat in ROOT_DOC_PATTERNS)
            if is_doc_ext or (p.parent == root and is_root_doc):
                if p.suffix.lower() == ".txt" and not is_root_doc and "docs" not in dirpath.lower():
                    continue  # 雑多な .txt は doc ディレクトリ/ルート慣習名のみ採用
                results.append(p)
    return results


STATIC_ROOTS = ["static", "website/static", "docs/public", "public", "docs/static"]


def check_links(doc_files, root: Path, limit=4000):
    """Markdown のリンク先の存在を検査 (http/anchor/mailto は対象外)。

    - 相対リンク: ファイルシステムで存在検査 → broken に分類
    - サイト絶対 (/path): 代表的な static ルートを探し、見つからなければ
      site_absolute_unverified に分類 (ビルド時解決のため broken と断定しない)
    """
    broken, site_unverified, checked = [], [], 0
    for p in doc_files:
        if p.suffix.lower() not in (".md", ".mdx"):
            continue
        try:
            text = p.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for m in LINK_RE.finditer(text):
            target = m.group(1)
            if re.match(r"^(https?:|mailto:|tel:|//|<|\{)", target):
                continue
            if checked >= limit:
                return {
                    "checked": checked, "broken": broken,
                    "site_absolute_unverified": site_unverified, "truncated": True,
                }
            checked += 1
            rel_in = str(p.relative_to(root))
            if target.startswith("/"):
                if not any((root / s / target.lstrip("/")).exists() for s in STATIC_ROOTS):
                    site_unverified.append({"in": rel_in, "target": target})
                continue
            t = (p.parent / target).resolve()
            if not t.exists():
                broken.append({"in": rel_in, "target": target})
    return {
        "checked": checked, "broken": broken,
        "site_absolute_unverified": site_unverified, "truncated": False,
    }


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    use_git = run_git(["rev-parse", "--is-inside-work-tree"], root) == "true"

    doc_files = collect_doc_files(root)
    doc_files_info = [file_info(p, root, use_git) for p in sorted(doc_files)[:300]]

    # ルート直下の doc ファイル
    root_docs = [i for i in doc_files_info if "/" not in i["path"]]

    # doc 系トップディレクトリ (慣習名) と、全トップディレクトリの分布
    # 注: doc_files_info は 300 件キャップだが、分布は全件 (doc_files) から数える
    doc_dirs, top_dirs = {}, {}
    for p in doc_files:
        rel = p.relative_to(root)
        top = rel.parts[0] if len(rel.parts) > 1 else "(root)"
        top_dirs.setdefault(top, {"files": 0, "bytes": 0})
        top_dirs[top]["files"] += 1
        top_dirs[top]["bytes"] += p.stat().st_size
        if top.lower() in DOC_DIR_NAMES or top == ".github":
            doc_dirs[top] = top_dirs[top]
    top_dirs = dict(
        sorted(top_dirs.items(), key=lambda kv: kv[1]["files"], reverse=True)[:15]
    )

    # ジェネレータ検出
    generators = []
    for name, markers in GENERATOR_MARKERS.items():
        for m in markers:
            if "+" in m:  # hugo: config.toml と content/ の併存
                a, b = m.split("+")
                if (root / a).exists() and (root / b).is_dir():
                    generators.append({"generator": name, "marker": m})
                continue
            hits = list(root.glob(m)) or list(root.glob(f"*/{m}"))
            if hits:
                generators.append({"generator": name, "marker": str(hits[0].relative_to(root))})
                break

    # プロジェクトシグナル
    signals = {}
    for key, rel in PROJECT_SIGNALS:
        if rel is None:
            signals[key] = bool(list(root.glob("*.sln")) or list(root.glob("**/*.csproj")))
            continue
        signals[key] = (root / rel).exists()
    # monorepo シグナル
    pkg = root / "package.json"
    if pkg.exists():
        try:
            pj = json.loads(pkg.read_text())
            signals["npm_workspaces"] = bool(pj.get("workspaces"))
            signals["package_private"] = bool(pj.get("private"))
            signals["package_bin"] = bool(pj.get("bin"))
        except Exception:
            pass
    signals["pnpm_workspace"] = (root / "pnpm-workspace.yaml").exists()
    signals["cargo_workspace_members"] = (root / "crates").is_dir() or (root / "packages").is_dir()
    # AGENTS/CLAUDE の関係 (正本一元化の判定材料)
    # 注: symlink の場合 per-path の git log は別履歴になりうるため、resolved target を併記する
    claude, agents = root / "CLAUDE.md", root / "AGENTS.md"
    if claude.exists():
        signals["claude_md_is_symlink"] = claude.is_symlink()
        if claude.is_symlink():
            signals["claude_md_symlink_target"] = os.readlink(claude)
        try:
            head = claude.read_text(encoding="utf-8", errors="ignore")[:200].strip()
            signals["claude_md_is_import_only"] = head == "@AGENTS.md"
        except Exception:
            pass
    if agents.exists():
        signals["agents_md_is_symlink"] = agents.is_symlink()
        if agents.is_symlink():
            signals["agents_md_symlink_target"] = os.readlink(agents)

    # 鮮度比較用: repo 全体とコードの最終コミット
    activity = {}
    if use_git:
        activity["repo_last_commit"] = run_git(["log", "-1", "--format=%cs"], root)
        activity["commits_last_year"] = run_git(
            ["rev-list", "--count", "--since=1 year ago", "HEAD"], root
        )

    readme = next((i for i in root_docs if i["path"].upper().startswith("README")), None)

    # broken リンクのサブツリー層別 (vendored fork / 一次 docs を区別して解釈するための材料)
    links = check_links(doc_files, root)
    broken_by_top = {}
    for b in links["broken"]:
        parts = b["in"].split("/")
        top = parts[0] if len(parts) > 1 else "(root)"
        broken_by_top[top] = broken_by_top.get(top, 0) + 1
    links["broken_by_top"] = dict(
        sorted(broken_by_top.items(), key=lambda kv: kv[1], reverse=True)
    )

    out = {
        "root": str(root),
        "git": use_git,
        "activity": activity,
        "readme": readme,
        "root_doc_files": root_docs,
        "doc_dirs": doc_dirs,
        "doc_top_dirs": top_dirs,
        "doc_file_count": len(doc_files),
        "doc_files": doc_files_info,
        "generators": generators,
        "signals": signals,
        "links": links,
    }
    json.dump(out, sys.stdout, ensure_ascii=False, indent=1)
    print()


if __name__ == "__main__":
    main()
