#!/bin/sh
# Unpack the bundled KiCad symbol and footprint libraries (about 450 MB
# unpacked) into $KICAD_CLI_HOME (default: ~/.cache/kicad-cli-skill), where
# scripts/kicad-cli finds them. Safe to re-run.

set -eu

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${KICAD_CLI_HOME:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/kicad-cli-skill}"

mkdir -p "$BASE"
for lib in kicad-symbols kicad-footprints; do
    if [ -d "$BASE/$lib" ]; then
        echo "$lib already installed in $BASE"
    else
        echo "Unpacking $lib ..." >&2
        tar -xJf "$SKILL_DIR/assets/$lib.tar.xz" -C "$BASE"
    fi
done

echo "Symbols:    $BASE/kicad-symbols"
echo "Footprints: $BASE/kicad-footprints"
