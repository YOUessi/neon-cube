#!/usr/bin/env python3
import json
import sys
from collections import Counter

if len(sys.argv) != 2:
    raise SystemExit("usage: count_claude_tools.py transcript.jsonl")

seen_ids = set()
anonymous = 0
by_name = Counter()

def walk(value):
    global anonymous
    if isinstance(value, dict):
        if value.get("type") == "tool_use":
            tool_id = value.get("id")
            name = value.get("name", "<unknown>")
            if tool_id:
                if tool_id not in seen_ids:
                    seen_ids.add(tool_id)
                    by_name[name] += 1
            else:
                anonymous += 1
                by_name[name] += 1
        for child in value.values():
            walk(child)
    elif isinstance(value, list):
        for child in value:
            walk(child)

with open(sys.argv[1], encoding="utf-8") as f:
    for raw in f:
        try:
            walk(json.loads(raw))
        except json.JSONDecodeError:
            pass

total = len(seen_ids) + anonymous
print(f"TOTAL_TOOL_CALLS={total}")
for name, count in by_name.most_common():
    print(f"{name}={count}")
