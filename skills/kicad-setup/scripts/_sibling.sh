# Sourced by the other scripts: locations of the sibling skills and the caches.
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS="$(cd "$SKILL_DIR/.." && pwd)"
CLI_SKILL="$SKILLS/kicad-cli"
TD_SKILL="$SKILLS/kicad-3d"
CACHE="${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}"
KICAD_BASE="${KICAD_CLI_HOME:-$CACHE/kicad-cli-skill}"
SC_BASE="${SOLIDCRAFT_HOME:-$CACHE/solidcraft-skill}"
FR_BASE="${FREEROUTING_HOME:-$CACHE/freerouting-skill}"
