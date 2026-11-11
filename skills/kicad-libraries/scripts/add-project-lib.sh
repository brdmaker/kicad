#!/bin/sh
# Register project-local libraries in a KiCad project's library tables.
#
# Usage: add-project-lib.sh PROJECT_DIR NAME
#   Makes sure PROJECT_DIR/sym-lib-table lists NAME -> ${KIPRJMOD}/NAME.kicad_sym
#   and PROJECT_DIR/fp-lib-table lists NAME -> ${KIPRJMOD}/NAME.pretty, creating
#   the tables when missing. Rows already present are left alone.
#   Only the rows whose file or directory exists are added.

set -eu
[ $# -eq 2 ] || { sed -n '2,9p' "$0"; exit 2; }
PROJ="$1"; NAME="$2"
[ -d "$PROJ" ] || { echo "error: no such directory: $PROJ" >&2; exit 1; }

add() {
    # add TABLE_FILE ROOT_TAG URI
    tbl="$1"; tag="$2"; uri="$3"
    row="  (lib (name \"$NAME\")(type \"KiCad\")(uri \"$uri\")(options \"\")(descr \"project specific\"))"
    if [ ! -f "$tbl" ]; then
        printf '(%s\n  (version 7)\n%s\n)\n' "$tag" "$row" > "$tbl"
        echo "created $tbl"
    elif grep -qF "(name \"$NAME\")" "$tbl"; then
        echo "$tbl already lists $NAME"
    else
        # insert before the final closing parenthesis
        tmp="$(mktemp)"
        awk -v row="$row" '{ lines[NR] = $0 } END {
            last = NR; while (last > 0 && lines[last] !~ /^\)/) last--
            for (i = 1; i <= NR; i++) { if (i == last) print row; print lines[i] } }' "$tbl" > "$tmp"
        cat "$tmp" > "$tbl"; rm -f "$tmp"
        echo "updated $tbl"
    fi
}

[ -f "$PROJ/$NAME.kicad_sym" ] && add "$PROJ/sym-lib-table" sym_lib_table "\${KIPRJMOD}/$NAME.kicad_sym"
[ -d "$PROJ/$NAME.pretty" ] && add "$PROJ/fp-lib-table" fp_lib_table "\${KIPRJMOD}/$NAME.pretty"
exit 0
