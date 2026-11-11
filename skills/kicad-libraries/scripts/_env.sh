# Sourced by the other scripts: resolves the library directories.
# Honours KICAD_SYMBOL_DIR / KICAD_FOOTPRINT_DIR (and KICAD10_ forms), else
# uses the copies unpacked by install-libs.sh into $KICAD_LIBS_HOME. The default
# location is the one the kicad-cli skill uses, so both skills share one copy
# (KICAD_CLI_HOME, else ~/.cache/kicad-cli-skill).

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${KICAD_LIBS_HOME:-${KICAD_CLI_HOME:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/kicad-cli-skill}}"
SYM_DIR="${KICAD_SYMBOL_DIR:-${KICAD10_SYMBOL_DIR:-$BASE/kicad-symbols}}"
FP_DIR="${KICAD_FOOTPRINT_DIR:-${KICAD10_FOOTPRINT_DIR:-$BASE/kicad-footprints}}"

need_libs() {
    if [ ! -d "$SYM_DIR" ] || [ ! -d "$FP_DIR" ]; then
        echo "error: libraries not found; run $SKILL_DIR/scripts/install-libs.sh first" >&2
        exit 1
    fi
}

# find_cli : print the path of a kicad-cli runner, or fail.
# Order: $KICAD_CLI, the sibling kicad-cli skill, ~/.claude/skills/kicad-cli, PATH.
find_cli() {
    for c in "${KICAD_CLI:-}" "$SKILL_DIR/../kicad-cli/scripts/kicad-cli" \
             "${HOME:-/tmp}/.claude/skills/kicad-cli/scripts/kicad-cli"; do
        [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
    done
    command -v kicad-cli && return 0
    echo "error: kicad-cli not found; install the kicad-cli skill or set KICAD_CLI" >&2
    return 1
}
