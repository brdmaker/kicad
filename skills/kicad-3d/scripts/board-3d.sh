#!/bin/sh
# Export a board to a 3D file, fetching the component models it needs first.
#
# Usage: board-3d.sh [-f FORMAT] [-o OUT] [-F] BOARD.kicad_pcb [-- EXTRA kicad-cli ARGS]
#   -f FORMAT  step (default), stpz, glb, stl, vrml, ply, brep, xao, u3d, 3dpdf
#   -o OUT     output file (default: BOARD's folder/NAME.<ext>)
#   -F         do not fetch 3D models (use what KICAD10_3DMODEL_DIR already has)
#   everything after -- goes to kicad-cli, e.g. -- --board-only
#              or -- --include-tracks --include-pads --include-zones
#
# Models are sparse-cloned from the official kicad-packages3D repository, only
# the libraries the board references (kicad-cli skill: fetch-3d-models.sh).
# STEP exports substitute STEP models for VRML ones (--subst-models).

set -eu
. "$(dirname "$0")/_cli.sh"

FMT=step; OUT=""; FETCH=1
while getopts "f:o:Fh" opt; do
    case "$opt" in
        f) FMT="$OPTARG" ;;
        o) OUT="$OPTARG" ;;
        F) FETCH=0 ;;
        *) sed -n '2,15p' "$0"; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -ge 1 ] || { sed -n '2,15p' "$0"; exit 2; }
PCB="$1"; shift
[ "${1:-}" != "--" ] || shift
[ -f "$PCB" ] || { echo "error: no such file: $PCB" >&2; exit 2; }
CLI="$(find_cli)" || exit 2

case "$FMT" in
    step|stpz|glb|stl|vrml|ply|brep|xao|u3d|3dpdf) ;;
    *) echo "error: unknown format '$FMT'" >&2; exit 2 ;;
esac
case "$FMT" in
    step) EXT=step ;; stpz) EXT=stpz ;; 3dpdf) EXT=pdf ;; *) EXT="$FMT" ;;
esac
[ -n "$OUT" ] || OUT="${PCB%.kicad_pcb}.$EXT"

[ "$FETCH" -eq 0 ] || fetch_models "$PCB"

# STEP-like exports cannot use VRML (.wrl) models, and --subst-models only works
# when the .wrl file exists, but the official model repository holds STEP files
# only. Boards made with older KiCad versions reference .wrl, so for these
# formats export from a throwaway copy of the project (symlinks to every file
# except the board) whose board points at the .step models instead.
WORK="$PCB"
EXTRA=""
case "$FMT" in
    step|stpz|brep|xao)
        TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
        SRC="$(cd "$(dirname "$PCB")" && pwd)"; BASE="$(basename "$PCB")"
        find "$SRC" -mindepth 1 -maxdepth 1 ! -name "$BASE" -exec ln -s {} "$TMPD"/ \;
        sed -E 's/(\(model "[^"]*)\.(wrl|WRL)"/\1.step"/' "$PCB" > "$TMPD/$BASE"
        WORK="$TMPD/$BASE"
        EXTRA="--subst-models"
        ;;
    glb) EXTRA="--subst-models" ;;
esac

LOG="$(mktemp)"
# shellcheck disable=SC2086
"$CLI" pcb export "$FMT" --force $EXTRA -o "$OUT" "$@" "$WORK" >"$LOG" 2>&1 || true
MISSING="$(grep -c 'Could not add 3D model' "$LOG" || true)"
grep -v 'schema file' "$LOG" | grep -v -e 'Could not add 3D model' -e 'File not found' -e 'Cannot use VRML' | tail -n 3 || true
rm -f "$LOG"
if [ "${MISSING:-0}" -gt 0 ]; then
    echo "warning: $MISSING component model(s) could not be loaded and are missing from the output" >&2
fi
[ -s "$OUT" ] || { echo "error: no output written to $OUT" >&2; exit 1; }
echo "$OUT ($(wc -c < "$OUT") bytes)"
