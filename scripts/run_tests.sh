#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/bootstrap_godot.sh" >/dev/null
GODOT="$("$ROOT/scripts/godot_bin.sh")"

TESTS=(
  "tests/test_cube_gravity.gd"
  "tests/test_face_transitions.gd"
  "tests/test_player_contract.gd"
  "tests/test_project_smoke.gd"
)

for test_file in "${TESTS[@]}"; do
  echo "== $test_file =="
  "$GODOT" --headless --path "$ROOT" --script "$test_file"
done

echo "Headless test suite: PASS"
