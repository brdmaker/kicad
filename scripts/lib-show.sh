#!/bin/sh
# Show details of one library part.
#
# Usage: lib-show.sh [-s|-f] Library:Name
#   -s / -f   force symbol or footprint (default: show whichever exists)
#
# Symbols: properties (reference, value, default footprint, datasheet,
# description, keywords), pin count and the file path.
# Footprints: description, tags, pad count, 3D model path and the file path.

set -eu
. "$(dirname "$0")/_env.sh"

KINDS="sf"
while getopts "sfh" opt; do
    case "$opt" in
        s) KINDS="s" ;;
        f) KINDS="f" ;;
        *) sed -n '2,9p' "$0"; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || { sed -n '2,9p' "$0"; exit 2; }
case "$1" in *:*) ;; *) echo "error: expected Library:Name, got '$1'" >&2; exit 2 ;; esac
LIB="${1%%:*}"; NAME="${1#*:}"
need_libs

FOUND=0
SF="$SYM_DIR/$LIB.kicad_symdir/$NAME.kicad_sym"
if [ "${KINDS#*s}" != "$KINDS" ] && [ -f "$SF" ]; then
    FOUND=1
    echo "Symbol $LIB:$NAME"
    for p in Reference Value Footprint Datasheet Description ki_keywords; do
        v="$(grep -m1 -oE "\\(property \"$p\" \"[^\"]*\"" "$SF" | sed -E 's/^[^"]*"[^"]*" "//; s/"$//')"
        [ -z "$v" ] || printf '  %-12s %s\n' "$p" "$v"
    done
    echo "  pins         $(grep -cE '^\s+\(pin ' "$SF")"
    echo "  file         $SF"
fi

FF="$FP_DIR/$LIB.pretty/$NAME.kicad_mod"
if [ "${KINDS#*f}" != "$KINDS" ] && [ -f "$FF" ]; then
    FOUND=1
    echo "Footprint $LIB:$NAME"
    for p in descr tags; do
        v="$(grep -m1 -oE "^\s+\($p \"[^\"]*\"" "$FF" | sed -E 's/^[^"]*"//; s/"$//')"
        [ -z "$v" ] || printf '  %-12s %s\n' "$p" "$v"
    done
    echo "  pads         $(grep -cE '^\s+\(pad ' "$FF")"
    m="$(grep -m1 -oE '\(model "[^"]*"' "$FF" | sed -E 's/^[^"]*"//; s/"$//')"
    [ -z "$m" ] || echo "  3d model     $m"
    echo "  file         $FF"
fi

[ "$FOUND" -eq 1 ] || { echo "not found: $1" >&2; exit 1; }
