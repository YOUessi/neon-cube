#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/bootstrap_godot.sh" >/dev/null
GODOT="$("$ROOT/scripts/godot_bin.sh")"

echo "== Godot =="
"$GODOT" --version

echo "== Import resources =="
"$GODOT" --headless --path "$ROOT" --import

echo "== Parse project scripts =="
while IFS= read -r -d '' script; do
  rel="${script#$ROOT/}"
  echo "check-only: $rel"
  "$GODOT" --headless --path "$ROOT" --check-only --script "$script"
done < <(find "$ROOT/scripts" "$ROOT/tests" -type f -name '*.gd' -print0 | sort -z)

echo "== Main-scene startup smoke =="
"$GODOT" --headless --path "$ROOT" --quit-after 12

echo "Project validation: PASS"
