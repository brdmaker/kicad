#!/bin/sh
# Check a generated footprint or symbol by round-tripping it through kicad-cli.
#
# Usage: verify-part.sh [-w] [-s OUT.svg] fp  FILE.kicad_mod
#        verify-part.sh [-w] [-s OUT.svg] sym FILE.kicad_sym
#   -w         replace FILE with the version kicad-cli re-saved (canonical format)
#   -s OUT.svg copy the rendered image there so it can be looked at
#
# Fails when kicad-cli cannot read the file or renders nothing. Passing does
# not mean the land pattern or pinout is right; compare with the datasheet.

set -eu
. "$(dirname "$0")/_env.sh"

WRITE=0; SVG=""
while getopts "ws:h" opt; do
    case "$opt" in
        w) WRITE=1 ;;
        s) SVG="$OPTARG" ;;
        *) sed -n '2,11p' "$0"; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -eq 2 ] || { sed -n '2,11p' "$0"; exit 2; }
KIND="$1"; FILE="$2"
[ -f "$FILE" ] || { echo "error: no such file: $FILE" >&2; exit 1; }
CLI="$(find_cli)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
NAME="$(basename "$FILE")"

case "$KIND" in
    fp)
        mkdir "$T/in.pretty" "$T/svg"
        cp "$FILE" "$T/in.pretty/$NAME"
        "$CLI" fp upgrade --force -o "$T/up.pretty" "$T/in.pretty" >"$T/log" 2>&1 || { cat "$T/log" >&2; exit 1; }
        [ -f "$T/up.pretty/$NAME" ] || { echo "error: kicad-cli did not re-save $NAME" >&2; cat "$T/log" >&2; exit 1; }
        "$CLI" fp export svg -o "$T/svg" "$T/up.pretty" >>"$T/log" 2>&1 || { cat "$T/log" >&2; exit 1; }
        ;;
    sym)
        mkdir "$T/svg"
        "$CLI" sym upgrade --force -o "$T/up.kicad_sym" "$FILE" >"$T/log" 2>&1 || { cat "$T/log" >&2; exit 1; }
        [ -f "$T/up.kicad_sym" ] || { echo "error: kicad-cli did not re-save $NAME" >&2; cat "$T/log" >&2; exit 1; }
        "$CLI" sym export svg -o "$T/svg" "$T/up.kicad_sym" >>"$T/log" 2>&1 || { cat "$T/log" >&2; exit 1; }
        ;;
    *) sed -n '2,11p' "$0"; exit 2 ;;
esac

OUT="$(find "$T/svg" -name '*.svg' -size +0 | head -n 1)"
[ -n "$OUT" ] || { echo "error: kicad-cli rendered no image" >&2; cat "$T/log" >&2; exit 1; }
[ -z "$SVG" ] || cp "$OUT" "$SVG"
if [ "$WRITE" -eq 1 ]; then
    if [ "$KIND" = fp ]; then cp "$T/up.pretty/$NAME" "$FILE"; else cp "$T/up.kicad_sym" "$FILE"; fi
fi
echo "ok: $FILE"
