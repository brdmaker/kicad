#!/bin/sh
# Render PNG pictures of a board in 3D, headlessly.
#
# Usage: render-board.sh [-o OUTDIR] [-v VIEWS] [-w WIDTH] BOARD.kicad_pcb
#   -o OUTDIR  where the images go (default: BOARD's folder/renders)
#   -v VIEWS   comma list from: top bottom iso front back left right
#              (default: top,bottom,iso)
#   -w WIDTH   image width in pixels, height is 2/3 of it (default 1600)
#
# Writes OUTDIR/NAME-VIEW.png. In the headless build these renders show the
# board, copper, pads and silkscreen; component bodies did not appear in tests
# even with the models available. Use board-3d.sh (STEP/GLB) when the
# components matter.

set -eu
. "$(dirname "$0")/_cli.sh"

OUT=""; VIEWS="top,bottom,iso"; W=1600
while getopts "o:v:w:h" opt; do
    case "$opt" in
        o) OUT="$OPTARG" ;;
        v) VIEWS="$OPTARG" ;;
        w) W="$OPTARG" ;;
        *) sed -n '2,14p' "$0"; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || { sed -n '2,14p' "$0"; exit 2; }
PCB="$1"
[ -f "$PCB" ] || { echo "error: no such file: $PCB" >&2; exit 2; }
CLI="$(find_cli)" || exit 2
NAME="$(basename "${PCB%.kicad_pcb}")"
[ -n "$OUT" ] || OUT="$(dirname "$PCB")/renders"
mkdir -p "$OUT"
H=$((W * 2 / 3))

for v in $(echo "$VIEWS" | tr ',' ' '); do
    case "$v" in
        iso) ARGS="--side top --rotate -45,0,45 --perspective" ;;
        top|bottom|front|back|left|right) ARGS="--side $v" ;;
        *) echo "error: unknown view '$v'" >&2; exit 2 ;;
    esac
    # shellcheck disable=SC2086
    "$CLI" pcb render $ARGS --quality high -w "$W" -h "$H" -o "$OUT/$NAME-$v.png" "$PCB" >/dev/null 2>&1 || true
    [ -s "$OUT/$NAME-$v.png" ] && echo "$OUT/$NAME-$v.png" || echo "error: render of view '$v' failed" >&2
done
