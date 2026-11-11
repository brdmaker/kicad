#!/bin/sh
# Install KiCad's global symbol and footprint library tables for headless use.
#
# Without them, kicad-cli finds only the libraries a project lists itself, and
# DRC/ERC report 'The current configuration does not include the footprint
# library ...' for every standard footprint. The tables come from the library
# snapshots (run install-libs.sh first) and point at ${KICAD10_SYMBOL_DIR} /
# ${KICAD10_FOOTPRINT_DIR}, which scripts/kicad-cli sets.
#
# Usage: setup-global-libs.sh [-f]
#   -f   overwrite tables that already exist (default: keep them)
# Writes to ${XDG_CONFIG_HOME:-~/.config}/kicad/<major.minor>/.

set -eu
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${KICAD_CLI_HOME:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/kicad-cli-skill}"

FORCE=0
while getopts "fh" opt; do
    case "$opt" in
        f) FORCE=1 ;;
        *) sed -n '2,15p' "$0"; exit 2 ;;
    esac
done

SYM="${KICAD10_SYMBOL_DIR:-${KICAD_SYMBOL_DIR:-$BASE/kicad-symbols}}"
FP="${KICAD10_FOOTPRINT_DIR:-${KICAD_FOOTPRINT_DIR:-$BASE/kicad-footprints}}"
[ -f "$SYM/sym-lib-table" ] && [ -f "$FP/fp-lib-table" ] || {
    echo "error: library tables not found in $SYM and $FP; run scripts/install-libs.sh first" >&2
    exit 1
}

VER="$("$SKILL_DIR/scripts/kicad-cli" version 2>/dev/null | tail -n 1 | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')"
[ -n "$VER" ] || { echo "error: could not read the kicad-cli version" >&2; exit 1; }
CFG="${XDG_CONFIG_HOME:-${HOME:-/tmp}/.config}/kicad/$VER"
mkdir -p "$CFG"

for pair in "sym-lib-table:$SYM" "fp-lib-table:$FP"; do
    t="${pair%%:*}"; src="${pair#*:}/$t"
    if [ -f "$CFG/$t" ] && [ "$FORCE" -eq 0 ]; then
        echo "kept existing $CFG/$t (use -f to replace)"
    else
        cp "$src" "$CFG/$t"
        echo "installed $CFG/$t ($(grep -c '(lib (name' "$CFG/$t") libraries)"
    fi
done
