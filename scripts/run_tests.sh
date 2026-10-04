#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/bootstrap_godot.sh" >/dev/null
GODOT="$("$ROOT/scripts/godot_bin.sh")"

TESTS=(
  "tests/test_cube_gravity.gd"
  "tests/test_face_transitions.gd"
  "tests/test_player_contract.gd"
  "tests/test_weapon_system.gd"
  "tests/test_enemy_routing.gd"
  "tests/test_campaign.gd"
  "tests/test_project_smoke.gd"
)

for test_file in "${TESTS[@]}"; do
  echo "== $test_file =="
  log="$(mktemp)"
  set +e
  "$GODOT" --headless --path "$ROOT" --script "$test_file" 2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
  set -e
  if [[ $status -ne 0 ]]; then
    echo "$test_file failed with exit code $status" >&2
    rm -f "$log"
    exit "$status"
  fi
  if grep -Eq '(^|[[:space:]])(SCRIPT ERROR|ERROR):' "$log"; then
    echo "$test_file emitted Godot ERROR output." >&2
    rm -f "$log"
    exit 1
  fi
  rm -f "$log"
done

echo "Headless test suite: PASS"
