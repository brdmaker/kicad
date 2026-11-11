# Sourced by the other scripts: locate a kicad-cli runner.
# Order: $KICAD_CLI, the sibling kicad-cli skill, ~/.claude/skills/kicad-cli, PATH.
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

find_cli() {
    for c in "${KICAD_CLI:-}" "$SKILL_DIR/../kicad-cli/scripts/kicad-cli" \
             "${HOME:-/tmp}/.claude/skills/kicad-cli/scripts/kicad-cli"; do
        [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
    done
    command -v kicad-cli && return 0
    echo "error: kicad-cli not found; install the kicad-cli skill or set KICAD_CLI" >&2
    return 1
}
