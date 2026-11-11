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

# find_fetch : the 3D model fetcher from the kicad-cli skill.
find_fetch() {
    for c in "$SKILL_DIR/../kicad-cli/scripts/fetch-3d-models.sh" \
             "${HOME:-/tmp}/.claude/skills/kicad-cli/scripts/fetch-3d-models.sh"; do
        [ -x "$c" ] && { echo "$c"; return 0; }
    done
    return 1
}

# fetch_models BOARD_OR_DIR... : fetch the 3D model libraries a design uses and
# export KICAD10_3DMODEL_DIR (and the design's own variable) for this process.
# Failure to fetch is a warning: the export still runs without those models.
fetch_models() {
    fetch="$(find_fetch)" || { echo "warning: fetch-3d-models.sh not found; models must already be available" >&2; return 0; }
    if line="$("$fetch" "$@" | tail -n 1)" && [ "${line#export }" != "$line" ]; then
        eval "$line"
    else
        echo "warning: could not fetch 3D models; exporting without the missing ones" >&2
    fi
}
