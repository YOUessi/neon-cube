#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT}/.rehearsal"
mkdir -p "$OUT_DIR"

if ! command -v claude >/dev/null 2>&1; then
  echo "Claude Code CLI not found in PATH." >&2
  exit 2
fi

PROMPT_FILE="$ROOT/REHEARSAL_TASK1_PROMPT.md"
STREAM="$OUT_DIR/task1-stream.jsonl"
FINAL="$OUT_DIR/task1-final.txt"
COUNT="$OUT_DIR/task1-tool-count.txt"

echo "Starting independent Task 1 rehearsal in: $ROOT"
echo "Streaming transcript: $STREAM"

set +e
claude -p   --output-format stream-json   --verbose   --allowedTools "Read" "Edit" "Write" "Glob" "Grep" "Bash"   "$(cat "$PROMPT_FILE")"   > "$STREAM"
STATUS=$?
set -e

python3 "$ROOT/tools/count_claude_tools.py" "$STREAM" | tee "$COUNT"

python3 - "$STREAM" > "$FINAL" <<'PY'
import json, sys
path=sys.argv[1]
last=[]
with open(path, encoding="utf-8") as f:
    for line in f:
        try:
            obj=json.loads(line)
        except Exception:
            continue
        if obj.get("type") == "result":
            result=obj.get("result")
            if isinstance(result, str):
                last=[result]
        msg=obj.get("message")
        if isinstance(msg, dict) and msg.get("role")=="assistant":
            parts=[]
            for part in msg.get("content",[]):
                if isinstance(part,dict) and part.get("type")=="text":
                    parts.append(part.get("text",""))
            if parts:
                last=parts
print("\n".join(last))
PY

echo "Claude exit status: $STATUS"
echo "Final response saved to: $FINAL"
exit "$STATUS"
