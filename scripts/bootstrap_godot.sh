#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${ROOT}/.tools"
DEFAULT_VERSION="4.3-stable"
VERSION="${GODOT_VERSION:-$DEFAULT_VERSION}"

resolve_existing() {
  if [[ -n "${GODOT_BIN:-}" && -x "${GODOT_BIN}" ]]; then
    printf '%s\n' "${GODOT_BIN}"
    return 0
  fi
  if command -v godot >/dev/null 2>&1; then
    command -v godot
    return 0
  fi
  if command -v godot4 >/dev/null 2>&1; then
    command -v godot4
    return 0
  fi
  if [[ -x "${TOOLS_DIR}/godot" ]]; then
    printf '%s\n' "${TOOLS_DIR}/godot"
    return 0
  fi
  return 1
}

if GODOT="$(resolve_existing)"; then
  echo "Using Godot: $GODOT"
  "$GODOT" --version
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required to bootstrap Godot." >&2
  exit 2
fi
if ! command -v unzip >/dev/null 2>&1; then
  echo "unzip is required to bootstrap Godot." >&2
  exit 2
fi

OS="$(uname -s)"
ARCH="$(uname -m)"
mkdir -p "$TOOLS_DIR"
ZIP="$TOOLS_DIR/godot.zip"

case "$OS" in
  Linux)
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
      echo "Automatic Linux bootstrap currently supports x86_64 only (got $ARCH)." >&2
      exit 2
    fi
    ASSET="Godot_v${VERSION}_linux.x86_64.zip"
    URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}/${ASSET}"

    echo "Godot was not found in PATH."
    echo "Downloading pinned Linux editor build: $URL"
    curl --fail --location --retry 3 --output "$ZIP" "$URL"

    rm -f "$TOOLS_DIR"/Godot_v*_linux.x86_64 "$TOOLS_DIR/godot"
    unzip -q -o "$ZIP" -d "$TOOLS_DIR"
    FOUND="$(find "$TOOLS_DIR" -maxdepth 1 -type f -name 'Godot_v*_linux.x86_64' | head -n 1)"
    if [[ -z "$FOUND" ]]; then
      echo "Downloaded archive did not contain the expected Godot Linux binary." >&2
      exit 2
    fi
    mv "$FOUND" "$TOOLS_DIR/godot"
    chmod +x "$TOOLS_DIR/godot"
    ;;

  Darwin)
    ASSET="Godot_v${VERSION}_macos.universal.zip"
    URL="https://github.com/godotengine/godot-builds/releases/download/${VERSION}/${ASSET}"

    echo "Godot was not found in PATH."
    echo "Downloading pinned macOS universal editor build: $URL"
    curl --fail --location --retry 3 --output "$ZIP" "$URL"

    rm -rf "$TOOLS_DIR/Godot.app" "$TOOLS_DIR/godot"
    unzip -q -o "$ZIP" -d "$TOOLS_DIR"
    if [[ ! -x "$TOOLS_DIR/Godot.app/Contents/MacOS/Godot" ]]; then
      echo "Downloaded archive did not contain the expected Godot.app bundle." >&2
      exit 2
    fi

    # Keep the app bundle intact and expose a stable repository-local executable.
    ln -s "Godot.app/Contents/MacOS/Godot" "$TOOLS_DIR/godot"
    ;;

  *)
    echo "Automatic Godot bootstrap does not support OS: $OS ($ARCH)." >&2
    exit 2
    ;;
esac

rm -f "$ZIP"

echo "Installed Godot: $TOOLS_DIR/godot"
"$TOOLS_DIR/godot" --version
