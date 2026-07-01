#!/usr/bin/env python3
"""
Claude Code Usage Statistics Aggregator
Transcript JSONL から全ツール使用を集計
"""

import json
import sys
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pathlib import Path


def parse_timestamp(ts_str: str) -> datetime | None:
    """タイムスタンプをパース（timezone-naive に変換）"""
    if not ts_str:
        return None
    try:
        # ISO format with timezone
        if "+" in ts_str or ts_str.endswith("Z"):
            ts_str = ts_str.replace("Z", "+00:00")
            dt = datetime.fromisoformat(ts_str)
            # timezone-naive に変換（ローカル時間として比較するため）
            return dt.replace(tzinfo=None)
        return datetime.fromisoformat(ts_str)
    except ValueError:
        return None


def get_period_start(period: str) -> datetime:
    """期間の開始日時を取得"""
    now = datetime.now()
    if period == "today":
        return now.replace(hour=0, minute=0, second=0, microsecond=0)
    elif period == "week":
        return now - timedelta(days=7)
    elif period == "month":
        return now - timedelta(days=30)
    return datetime.min


def extract_all_entries(jsonl_path: Path, start: datetime) -> tuple[list[dict], list[dict]]:
    """Transcript JSONL から tool_use と assistant メッセージを抽出"""
    tool_records = []
    assistant_records = []
    try:
        with open(jsonl_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    ts = parse_timestamp(entry.get("timestamp", ""))
                    if ts and ts < start:
                        continue

                    session_id = entry.get("sessionId", "")
                    cwd = entry.get("cwd", "")
                    message = entry.get("message", {})
                    content = message.get("content", [])
                    model = message.get("model", "")
                    usage = message.get("usage", {})
                    entry_type = entry.get("type", "")

                    # assistant メッセージからモデル・トークン情報を抽出
                    if entry_type == "assistant" and model:
                        has_thinking = False
                        if isinstance(content, list):
                            has_thinking = any(
                                isinstance(item, dict) and item.get("type") == "thinking"
                                for item in content
                            )
                        assistant_records.append({
                            "timestamp": ts,
                            "session_id": session_id,
                            "cwd": cwd,
                            "model": model,
                            "usage": usage,
                            "has_thinking": has_thinking,
                            "file": str(jsonl_path),
                        })

                    if not isinstance(content, list):
                        continue

                    for item in content:
                        if isinstance(item, dict) and item.get("type") == "tool_use":
                            tool_name = item.get("name", "unknown")
                            tool_input = item.get("input", {})
                            tool_records.append({
                                "timestamp": ts,
                                "session_id": session_id,
                                "cwd": cwd,
                                "model": model,
                                "tool_name": tool_name,
                                "tool_input": tool_input,
                                "file": str(jsonl_path),
                            })
                except json.JSONDecodeError:
                    continue
    except (OSError, IOError):
        pass
    return tool_records, assistant_records


def extract_tool_uses(jsonl_path: Path, start: datetime) -> list[dict]:
    """Transcript JSONL から tool_use を抽出（後方互換性のため維持）"""
    tool_records, _ = extract_all_entries(jsonl_path, start)
    return tool_records


def load_all_records(period: str) -> list[dict]:
    """全 transcript から tool records を読み込む"""
    projects_dir = Path.home() / ".claude" / "projects"
    if not projects_dir.exists():
        return []

    start = get_period_start(period)
    records = []

    for jsonl_file in projects_dir.rglob("*.jsonl"):
        records.extend(extract_tool_uses(jsonl_file, start))

    return sorted(records, key=lambda r: r.get("timestamp") or datetime.min)


def load_all_entries(period: str) -> tuple[list[dict], list[dict]]:
    """全 transcript から tool と assistant の両方を読み込む"""
    projects_dir = Path.home() / ".claude" / "projects"
    if not projects_dir.exists():
        return [], []

    start = get_period_start(period)
    all_tool_records = []
    all_assistant_records = []

    for jsonl_file in projects_dir.rglob("*.jsonl"):
        tool_records, assistant_records = extract_all_entries(jsonl_file, start)
        all_tool_records.extend(tool_records)
        all_assistant_records.extend(assistant_records)

    all_tool_records.sort(key=lambda r: r.get("timestamp") or datetime.min)
    all_assistant_records.sort(key=lambda r: r.get("timestamp") or datetime.min)
    return all_tool_records, all_assistant_records


def aggregate_by_tool(records: list[dict]) -> Counter:
    """ツール別の使用回数を集計"""
    return Counter(r.get("tool_name", "unknown") for r in records)


def aggregate_by_skill(records: list[dict]) -> Counter:
    """Skill別の使用回数を集計（Skill + SlashCommand両方対応）"""
    skills = []
    for r in records:
        tool_name = r.get("tool_name", "")
        tool_input = r.get("tool_input", {})

        if tool_name == "Skill":
            # 新形式: {"name":"Skill", "input":{"skill":"orchestrator"}}
            skill_name = tool_input.get("skill", "unknown")
            skills.append(skill_name)
        elif tool_name == "SlashCommand":
            # 旧形式: {"name":"SlashCommand", "input":{"command":"/orchestrator"}}
            command = tool_input.get("command", "")
            # /プレフィックスを除去して正規化
            skill_name = command.lstrip("/") if command else "unknown"
            skills.append(skill_name)
    return Counter(skills)


def aggregate_by_subagent(records: list[dict]) -> Counter:
    """サブエージェント(Task)別の使用回数を集計"""
    subagents = []
    for r in records:
        if r.get("tool_name") == "Task":
            subagent_type = r.get("tool_input", {}).get("subagent_type", "unknown")
            subagents.append(subagent_type)
    return Counter(subagents)


def aggregate_by_session(records: list[dict]) -> dict:
    """セッション別の統計を集計"""
    sessions = defaultdict(lambda: {"count": 0, "tools": Counter()})
    for r in records:
        sid = r.get("session_id", "unknown")
        sessions[sid]["count"] += 1
        sessions[sid]["tools"][r.get("tool_name", "unknown")] += 1
    return dict(sessions)


def aggregate_by_file(records: list[dict]) -> Counter:
    """編集/読取ファイル別の使用回数を集計"""
    files = []
    for r in records:
        tool = r.get("tool_name", "")
        tool_input = r.get("tool_input", {})
        if tool in ("Read", "Write", "Edit"):
            fp = tool_input.get("file_path", "")
            if fp:
                files.append(fp)
    return Counter(files)


def aggregate_by_mcp(records: list[dict]) -> Counter:
    """MCPサーバー別の使用回数を集計"""
    mcp_servers = []
    for r in records:
        tool = r.get("tool_name", "")
        if tool.startswith("mcp__"):
            parts = tool.split("__")
            server = parts[1] if len(parts) > 1 else "unknown"
            mcp_servers.append(server)
    return Counter(mcp_servers)


def aggregate_by_model(assistant_records: list[dict]) -> Counter:
    """モデル別の使用回数を集計"""
    return Counter(r.get("model", "unknown") for r in assistant_records)


def aggregate_tokens(assistant_records: list[dict]) -> dict:
    """トークン使用量を集計"""
    totals = defaultdict(lambda: {
        "input_tokens": 0,
        "output_tokens": 0,
        "cache_read": 0,
        "cache_creation": 0,
        "requests": 0,
    })
    for r in assistant_records:
        model = r.get("model", "unknown")
        usage = r.get("usage", {})
        totals[model]["input_tokens"] += usage.get("input_tokens", 0)
        totals[model]["output_tokens"] += usage.get("output_tokens", 0)
        totals[model]["cache_read"] += usage.get("cache_read_input_tokens", 0)
        totals[model]["cache_creation"] += usage.get("cache_creation_input_tokens", 0)
        totals[model]["requests"] += 1
    return dict(totals)


def aggregate_by_web(records: list[dict]) -> dict:
    """WebSearch/WebFetch使用統計を集計"""
    web_stats = {
        "WebSearch": {"count": 0, "queries": []},
        "WebFetch": {"count": 0, "urls": []},
    }
    for r in records:
        tool = r.get("tool_name", "")
        tool_input = r.get("tool_input", {})
        if tool == "WebSearch":
            web_stats["WebSearch"]["count"] += 1
            query = tool_input.get("query", "")
            if query:
                web_stats["WebSearch"]["queries"].append(query)
        elif tool == "WebFetch":
            web_stats["WebFetch"]["count"] += 1
            url = tool_input.get("url", "")
            if url:
                web_stats["WebFetch"]["urls"].append(url)
    return web_stats


def aggregate_by_project(records: list[dict]) -> Counter:
    """プロジェクト（cwd）別の使用回数を集計"""
    projects = []
    for r in records:
        cwd = r.get("cwd", "unknown")
        # パスを短縮表示用に処理
        if cwd.startswith(str(Path.home())):
            cwd = "~" + cwd[len(str(Path.home())):]
        projects.append(cwd)
    return Counter(projects)


def aggregate_thinking(assistant_records: list[dict]) -> dict:
    """Extended thinking使用統計を集計"""
    total = len(assistant_records)
    with_thinking = sum(1 for r in assistant_records if r.get("has_thinking"))
    by_model = defaultdict(lambda: {"total": 0, "with_thinking": 0})
    for r in assistant_records:
        model = r.get("model", "unknown")
        by_model[model]["total"] += 1
        if r.get("has_thinking"):
            by_model[model]["with_thinking"] += 1
    return {
        "total_requests": total,
        "with_thinking": with_thinking,
        "thinking_rate": (with_thinking / total * 100) if total > 0 else 0,
        "by_model": dict(by_model),
    }


def aggregate_by_hour(records: list[dict]) -> Counter:
    """時間帯別の使用回数を集計"""
    hours = []
    for r in records:
        ts = r.get("timestamp")
        if ts:
            hours.append(ts.hour)
    return Counter(hours)


def format_ranking(counter: Counter, title: str, limit: int = 10) -> str:
    """ランキング形式で出力"""
    if not counter:
        return f"\n### {title}\nNo data\n"

    lines = [f"\n### {title}"]
    total = sum(counter.values())
    for i, (name, count) in enumerate(counter.most_common(limit), 1):
        pct = (count / total) * 100 if total > 0 else 0
        bar = "█" * int(pct / 5)
        lines.append(f"{i:2}. {name}: {count} ({pct:.1f}%) {bar}")
    lines.append(f"\nTotal: {total}")
    return "\n".join(lines)


def format_tokens(n: int) -> str:
    """トークン数を読みやすい形式に変換"""
    if n >= 1_000_000_000:
        return f"{n / 1_000_000_000:.1f}B"
    elif n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    elif n >= 1_000:
        return f"{n / 1_000:.1f}K"
    return str(n)


def format_hour_chart(hour_counts: Counter) -> str:
    """時間帯別使用量を棒グラフで表示"""
    if not hour_counts:
        return "No data"
    max_count = max(hour_counts.values()) if hour_counts else 1
    lines = []
    for hour in range(24):
        count = hour_counts.get(hour, 0)
        bar_len = int((count / max_count) * 20) if max_count > 0 else 0
        bar = "█" * bar_len
        lines.append(f"{hour:02d}:00 | {bar} {count}")
    return "\n".join(lines)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Claude Code usage statistics")
    parser.add_argument(
        "--period",
        choices=["today", "week", "month", "all"],
        default="all",
        help="Period to aggregate",
    )
    parser.add_argument(
        "--type",
        choices=[
            "tools", "skills", "subagents", "sessions", "files", "mcp",
            "models", "tokens", "web", "projects", "thinking", "hourly",
            "summary", "full",
        ],
        default="summary",
        help="Aggregation type",
    )
    parser.add_argument("--limit", type=int, default=10, help="Ranking limit")
    parser.add_argument("--json", action="store_true", help="Output as JSON")

    args = parser.parse_args()

    # 新しい集計タイプは両方のデータが必要
    need_assistant = args.type in ("models", "tokens", "thinking", "full", "summary")
    if need_assistant:
        records, assistant_records = load_all_entries(args.period)
    else:
        records = load_all_records(args.period)
        assistant_records = []

    if not records:
        print(f"No records found for period: {args.period}")
        sys.exit(0)

    period_label = {
        "today": "Today",
        "week": "Last 7 days",
        "month": "Last 30 days",
        "all": "All time",
    }[args.period]

    if args.type == "summary":
        print(f"# Claude Code Usage Statistics ({period_label})")
        print(f"Total tool calls: {len(records)}")
        print(f"Total API requests: {len(assistant_records)}")
        print(format_ranking(aggregate_by_tool(records), "Tools", args.limit))
        print(format_ranking(aggregate_by_skill(records), "Skills", args.limit))
        print(format_ranking(aggregate_by_model(assistant_records), "Models", args.limit))
    elif args.type == "full":
        print(f"# Claude Code Full Statistics ({period_label})")
        print(f"Total tool calls: {len(records)}")
        print(f"Total API requests: {len(assistant_records)}")
        print(format_ranking(aggregate_by_tool(records), "Tools", args.limit))
        print(format_ranking(aggregate_by_skill(records), "Skills", args.limit))
        print(format_ranking(aggregate_by_subagent(records), "Subagents (Task)", args.limit))
        print(format_ranking(aggregate_by_mcp(records), "MCP Servers", args.limit))
        print(format_ranking(aggregate_by_model(assistant_records), "Models", args.limit))
        print(format_ranking(aggregate_by_project(records), "Projects", args.limit))
        # トークン
        token_stats = aggregate_tokens(assistant_records)
        print("\n### Token Usage")
        for model, stats in token_stats.items():
            total = stats["input_tokens"] + stats["output_tokens"] + stats["cache_read"] + stats["cache_creation"]
            print(f"  {model}: {format_tokens(total)} total")
        # thinking
        thinking_stats = aggregate_thinking(assistant_records)
        print(f"\n### Extended Thinking")
        print(f"  Usage rate: {thinking_stats['thinking_rate']:.1f}% ({thinking_stats['with_thinking']}/{thinking_stats['total_requests']})")
    elif args.type == "tools":
        result = aggregate_by_tool(records)
        if args.json:
            print(json.dumps(dict(result), indent=2))
        else:
            print(f"# Tool Usage ({period_label})")
            print(format_ranking(result, "Tools", args.limit))
    elif args.type == "skills":
        result = aggregate_by_skill(records)
        if args.json:
            print(json.dumps(dict(result), indent=2))
        else:
            print(f"# Skill Usage ({period_label})")
            print(format_ranking(result, "Skills", args.limit))
    elif args.type == "subagents":
        result = aggregate_by_subagent(records)
        if args.json:
            print(json.dumps(dict(result), indent=2))
        else:
            print(f"# Subagent Usage ({period_label})")
            print(format_ranking(result, "Subagents", args.limit))
    elif args.type == "sessions":
        result = aggregate_by_session(records)
        if args.json:
            print(json.dumps(result, indent=2, default=dict))
        else:
            print(f"# Session Statistics ({period_label})")
            print(f"Total sessions: {len(result)}")
            for sid, data in sorted(result.items(), key=lambda x: -x[1]["count"])[:args.limit]:
                short_id = sid[:8] if sid else "unknown"
                print(f"\n**{short_id}...**: {data['count']} calls")
                for tool, cnt in data["tools"].most_common(5):
                    print(f"  - {tool}: {cnt}")
    elif args.type == "files":
        result = aggregate_by_file(records)
        if args.json:
            print(json.dumps(dict(result), indent=2))
        else:
            print(f"# File Access ({period_label})")
            print(format_ranking(result, "Files", args.limit))
    elif args.type == "mcp":
        result = aggregate_by_mcp(records)
        if args.json:
            print(json.dumps(dict(result), indent=2))
        else:
            print(f"# MCP Server Usage ({period_label})")
            print(format_ranking(result, "MCP Servers", args.limit))
    elif args.type == "models":
        result = aggregate_by_model(assistant_records)
        if args.json:
            print(json.dumps(dict(result), indent=2))
        else:
            print(f"# Model Usage ({period_label})")
            print(format_ranking(result, "Models", args.limit))
    elif args.type == "tokens":
        result = aggregate_tokens(assistant_records)
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"# Token Usage ({period_label})")
            for model, stats in sorted(result.items(), key=lambda x: -x[1]["output_tokens"]):
                print(f"\n### {model}")
                print(f"  Requests: {stats['requests']}")
                print(f"  Input:  {format_tokens(stats['input_tokens'])}")
                print(f"  Output: {format_tokens(stats['output_tokens'])}")
                print(f"  Cache read: {format_tokens(stats['cache_read'])}")
                print(f"  Cache creation: {format_tokens(stats['cache_creation'])}")
    elif args.type == "web":
        result = aggregate_by_web(records)
        if args.json:
            print(json.dumps(result, indent=2, default=list))
        else:
            print(f"# Web Usage ({period_label})")
            print(f"\n### WebSearch: {result['WebSearch']['count']} calls")
            query_counter = Counter(result["WebSearch"]["queries"])
            for query, cnt in query_counter.most_common(args.limit):
                print(f"  - \"{query[:50]}...\" ({cnt})" if len(query) > 50 else f"  - \"{query}\" ({cnt})")
            print(f"\n### WebFetch: {result['WebFetch']['count']} calls")
            # URLはドメインで集計
            from urllib.parse import urlparse
            domains = [urlparse(url).netloc for url in result["WebFetch"]["urls"] if url]
            domain_counter = Counter(domains)
            for domain, cnt in domain_counter.most_common(args.limit):
                print(f"  - {domain}: {cnt}")
    elif args.type == "projects":
        result = aggregate_by_project(records)
        if args.json:
            print(json.dumps(dict(result), indent=2))
        else:
            print(f"# Project Usage ({period_label})")
            print(format_ranking(result, "Projects", args.limit))
    elif args.type == "thinking":
        result = aggregate_thinking(assistant_records)
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"# Extended Thinking Usage ({period_label})")
            print(f"Total requests: {result['total_requests']}")
            print(f"With thinking: {result['with_thinking']} ({result['thinking_rate']:.1f}%)")
            print("\n### By Model")
            for model, stats in result["by_model"].items():
                rate = (stats["with_thinking"] / stats["total"] * 100) if stats["total"] > 0 else 0
                print(f"  {model}: {stats['with_thinking']}/{stats['total']} ({rate:.1f}%)")
    elif args.type == "hourly":
        result = aggregate_by_hour(records)
        if args.json:
            print(json.dumps(dict(result), indent=2))
        else:
            print(f"# Hourly Usage ({period_label})")
            print(format_hour_chart(result))


if __name__ == "__main__":
    main()
