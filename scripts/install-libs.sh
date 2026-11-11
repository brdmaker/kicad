#!/bin/sh
# Unpack the bundled KiCad symbol and footprint libraries (about 450 MB
# unpacked) into $KICAD_LIBS_HOME (default: ~/.cache/kicad-libs-skill).
# Safe to re-run.

set -eu
. "$(dirname "$0")/_env.sh"

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
