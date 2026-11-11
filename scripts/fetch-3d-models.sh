#!/bin/sh
# Fetch only the KiCad 3D model directories that a design references.
#
# Usage: fetch-3d-models.sh [-d CLONE_DIR] [-u REPO_URL] [-n] FILE_OR_DIR...
#
#   FILE_OR_DIR  .kicad_pcb / .kicad_mod files, or directories searched
#                recursively for them
#   -d DIR       where the sparse clone lives
#                (default: $KICAD_3DMODEL_CACHE or ~/.cache/kicad-packages3D)
#   -u URL       packages3D repository to clone
#   -n           dry run: only list the model directories needed
#
# On success the clone path is printed last as an export line, so it can be
# used as:  eval "$(fetch-3d-models.sh board.kicad_pcb | tail -n 1)"
# The design's own variable name (e.g. KICAD8_3DMODEL_DIR) is exported along with
# KICAD10_3DMODEL_DIR.

set -eu

URL="https://gitlab.com/kicad/libraries/kicad-packages3D.git"
DEST="${KICAD_3DMODEL_CACHE:-${HOME:-/tmp}/.cache/kicad-packages3D}"
DRY=0

while getopts "d:u:nh" opt; do
    case "$opt" in
        d) DEST="$OPTARG" ;;
        u) URL="$OPTARG" ;;
        n) DRY=1 ;;
        *) sed -n '2,16p' "$0"; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

[ $# -ge 1 ] || { sed -n '2,16p' "$0"; exit 2; }

# Collect the files to scan
FILES=$(for p in "$@"; do
    if [ -d "$p" ]; then
        find "$p" -type f \( -name '*.kicad_pcb' -o -name '*.kicad_mod' \)
    elif [ -f "$p" ]; then
        echo "$p"
    else
        echo "error: no such file or directory: $p" >&2
        exit 1
    fi
done)

[ -n "$FILES" ] || { echo "error: no .kicad_pcb or .kicad_mod files found" >&2; exit 1; }

# Model references look like: (model "${KICAD10_3DMODEL_DIR}/Lib.3dshapes/Part.step"
# Keep the library directory name and the variable name.
REFS=$(printf '%s\n' "$FILES" | tr '\n' '\0' | xargs -0 grep -hoE '\$\{KICAD[0-9]*_3DMODEL_DIR\}/[^"/]+\.3dshapes/' 2>/dev/null | sort -u || true)

if [ -z "$REFS" ]; then
    echo "No 3D model references to library paths found." >&2
    exit 0
fi

VAR=$(printf '%s\n' "$REFS" | sed -E 's/^\$\{(KICAD[0-9]*_3DMODEL_DIR)\}.*/\1/' | sort -u | tail -n 1)
DIRS=$(printf '%s\n' "$REFS" | sed -E 's#^\$\{[^}]*\}/([^/]+)/$#\1#' | sort -u)

echo "Model libraries referenced: $(printf '%s\n' "$DIRS" | wc -l)" >&2
printf '%s\n' "$DIRS" | sed 's/^/  /' >&2

if [ "$DRY" -eq 1 ]; then
    exit 0
fi

if [ ! -d "$DEST/.git" ]; then
    mkdir -p "$(dirname "$DEST")"
    git clone --quiet --depth 1 --filter=blob:none --sparse "$URL" "$DEST"
fi

# add is idempotent; it only downloads what is not already checked out
# shellcheck disable=SC2086
git -C "$DEST" sparse-checkout add $DIRS

# Warn about references that did not resolve in the repository
for d in $DIRS; do
    [ -d "$DEST/$d" ] || echo "warning: $d not found in $URL" >&2
done

# Also set the current-version name so a newer KiCad resolves the same path
echo "export $VAR=\"$DEST\" KICAD10_3DMODEL_DIR=\"$DEST\""
