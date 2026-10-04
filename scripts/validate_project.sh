#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/bootstrap_godot.sh" >/dev/null
GODOT="$("$ROOT/scripts/godot_bin.sh")"

run_clean() {
  local label="$1"
  shift
  local log
  log="$(mktemp)"
  echo "== $label =="
  set +e
  "$@" 2>&1 | tee "$log"
  local status=${PIPESTATUS[0]}
  set -e
  if [[ $status -ne 0 ]]; then
    echo "$label failed with exit code $status" >&2
    rm -f "$log"
    exit "$status"
  fi
  if grep -Eq '(^|[[:space:]])(SCRIPT ERROR|ERROR):' "$log"; then
    echo "$label emitted Godot ERROR output." >&2
    rm -f "$log"
    exit 1
  fi
  rm -f "$log"
}

echo "== Godot =="
"$GODOT" --version

run_clean "Import resources" "$GODOT" --headless --path "$ROOT" --import

echo "== Parse project scripts =="
while IFS= read -r -d '' script; do
  rel="${script#$ROOT/}"
  run_clean "check-only: $rel" "$GODOT" --headless --path "$ROOT" --check-only --script "$script"
done < <(find "$ROOT/scripts" "$ROOT/tests" -type f -name '*.gd' -print0 | sort -z)

run_clean "Main-scene startup smoke" "$GODOT" --headless --path "$ROOT" --quit-after 12

echo "Project validation: PASS"
