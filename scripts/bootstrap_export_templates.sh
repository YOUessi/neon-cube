#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${GODOT_VERSION:-4.3-stable}"
ENGINE_VERSION_DIR="${GODOT_TEMPLATE_DIR_VERSION:-4.3.stable}"
TARGET="$HOME/.local/share/godot/export_templates/$ENGINE_VERSION_DIR"

if [[ -f "$TARGET/linux_release.x86_64" ]]; then
  echo "Godot export templates already installed: $TARGET"
  exit 0
fi

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 2; }
command -v unzip >/dev/null 2>&1 || { echo "unzip is required" >&2; exit 2; }

mkdir -p "$TARGET"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ARCHIVE="$TMP/export_templates.tpz"
URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}/Godot_v${VERSION}_export_templates.tpz"

echo "Downloading Godot export templates: $URL"
curl --fail --location --retry 3 --output "$ARCHIVE" "$URL"
unzip -q "$ARCHIVE" -d "$TMP/unpacked"

if [[ ! -f "$TMP/unpacked/templates/linux_release.x86_64" ]]; then
  echo "Expected Linux export template missing." >&2
  exit 2
fi

cp -a "$TMP/unpacked/templates/." "$TARGET/"
chmod +x "$TARGET/linux_release.x86_64" "$TARGET/linux_debug.x86_64" 2>/dev/null || true
echo "Installed export templates: $TARGET"
