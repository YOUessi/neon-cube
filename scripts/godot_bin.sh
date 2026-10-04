#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -n "${GODOT_BIN:-}" && -x "${GODOT_BIN}" ]]; then
  printf '%s\n' "${GODOT_BIN}"
elif command -v godot >/dev/null 2>&1; then
  command -v godot
elif command -v godot4 >/dev/null 2>&1; then
  command -v godot4
elif [[ -x "${ROOT}/.tools/godot" ]]; then
  printf '%s\n' "${ROOT}/.tools/godot"
else
  echo "Godot not found. Run ./scripts/bootstrap_godot.sh first or set GODOT_BIN." >&2
  exit 2
fi
