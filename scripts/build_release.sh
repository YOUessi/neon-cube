#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/bootstrap_godot.sh" >/dev/null
"$ROOT/scripts/bootstrap_export_templates.sh" >/dev/null
GODOT="$("$ROOT/scripts/godot_bin.sh")"

rm -rf "$ROOT/dist"
mkdir -p "$ROOT/dist"

echo "== Export Linux x86_64 =="
"$GODOT" --headless --path "$ROOT" --export-release "Linux" "$ROOT/dist/neon-cube.x86_64"
chmod +x "$ROOT/dist/neon-cube.x86_64"

if [[ ! -s "$ROOT/dist/neon-cube.x86_64" ]]; then
  echo "Release executable was not produced." >&2
  exit 1
fi

echo "Release build: PASS"
ls -lh "$ROOT/dist/neon-cube.x86_64"
