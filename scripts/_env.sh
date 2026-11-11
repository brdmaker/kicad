# Sourced by the other scripts: resolves the library directories.
# Honours KICAD_SYMBOL_DIR / KICAD_FOOTPRINT_DIR (and KICAD10_ forms), else
# uses the copies unpacked by install-libs.sh into $KICAD_LIBS_HOME
# (default: ~/.cache/kicad-libs-skill).

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${KICAD_LIBS_HOME:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/kicad-libs-skill}"
SYM_DIR="${KICAD_SYMBOL_DIR:-${KICAD10_SYMBOL_DIR:-$BASE/kicad-symbols}}"
FP_DIR="${KICAD_FOOTPRINT_DIR:-${KICAD10_FOOTPRINT_DIR:-$BASE/kicad-footprints}}"

need_libs() {
    if [ ! -d "$SYM_DIR" ] || [ ! -d "$FP_DIR" ]; then
        echo "error: libraries not found; run $SKILL_DIR/scripts/install-libs.sh first" >&2
        exit 1
    fi
}
