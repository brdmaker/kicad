#!/bin/sh
# Search the KiCad libraries.
#
# Usage: lib-search.sh [-s|-f] [-d] [-n MAX] PATTERN
#   -s    symbols only      -f    footprints only   (default: both)
#   -d    also match the description and keywords/tags, not just the name
#   -n N  print at most N results per kind (default 50)
#   PATTERN is a case-insensitive extended regular expression.
#
# Output: Library:Name, tab, description. A Library:Name can be passed to
# lib-show.sh.

set -eu
. "$(dirname "$0")/_env.sh"

KINDS="sf"; DEEP=0; MAX=50
while getopts "sfdn:h" opt; do
    case "$opt" in
        s) KINDS="s" ;;
        f) KINDS="f" ;;
        d) DEEP=1 ;;
        n) MAX="$OPTARG" ;;
        *) sed -n '2,11p' "$0"; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || { sed -n '2,11p' "$0"; exit 2; }
PAT="$1"
need_libs

# by_name EXT : filter file paths on stdin, keeping those whose name (without
# EXT) matches PATTERN case-insensitively, so ^ and $ anchor to the part name
by_name() {
    awk -v ext="$1" -v pat="$(printf '%s' "$PAT" | tr '[:upper:]' '[:lower:]')" '{
        n = $0; sub(/.*\//, "", n); sub(ext "$", "", n)
        if (tolower(n) ~ pat) print
    }'
}

# prop FILE NAME : value of a symbol property
prop() { grep -m1 -oE "\\(property \"$2\" \"[^\"]*\"" "$1" | sed -E 's/^[^"]*"[^"]*" "//; s/"$//'; }

if [ "${KINDS#*s}" != "$KINDS" ]; then
    echo "== Symbols"
    {
        find "$SYM_DIR" -type f -name '*.kicad_sym' | by_name .kicad_sym
        if [ "$DEEP" -eq 1 ]; then
            find "$SYM_DIR" -type f -name '*.kicad_sym' -print0 |
                xargs -0 grep -liE "\\(property \"(Description|ki_keywords)\" \"[^\"]*(${PAT})" || true
        fi
    } | sort -u | head -n "$MAX" | while read -r f; do
        lib="$(basename "$(dirname "$f")" .kicad_symdir)"
        printf '%s:%s\t%s\n' "$lib" "$(basename "$f" .kicad_sym)" "$(prop "$f" Description)"
    done
fi

if [ "${KINDS#*f}" != "$KINDS" ]; then
    echo "== Footprints"
    {
        find "$FP_DIR" -type f -name '*.kicad_mod' | by_name .kicad_mod
        if [ "$DEEP" -eq 1 ]; then
            find "$FP_DIR" -type f -name '*.kicad_mod' -print0 |
                xargs -0 grep -liE "^\s+\((descr|tags) \"[^\"]*(${PAT})" || true
        fi
    } | sort -u | head -n "$MAX" | while read -r f; do
        lib="$(basename "$(dirname "$f")" .pretty)"
        d="$(grep -m1 -oE '^\s+\(descr "[^"]*"' "$f" | sed -E 's/^[^"]*"//; s/"$//' | cut -c1-100)"
        printf '%s:%s\t%s\n' "$lib" "$(basename "$f" .kicad_mod)" "$d"
    done
fi
