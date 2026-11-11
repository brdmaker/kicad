#!/bin/sh
# Run ERC and DRC on a KiCad project, headlessly, and print a short summary.
#
# Usage: check.sh [-o OUTDIR] [-n EXAMPLES] [-s] [-R] PATH...
#   PATH       a project directory, or .kicad_sch / .kicad_pcb / .kicad_pro files
#   -o OUTDIR  where the JSON reports go (default: PATH's folder/checks)
#   -n N       examples shown per finding type (default 3)
#   -s         strict: warnings also fail the run
#   -R         do not refill zones before DRC (default refills in memory only;
#              the board file is never modified)
#
# For a directory the root schematic is the one named like the .kicad_pro file,
# and every .kicad_pcb in it is checked. Exit status: 0 clean (warnings allowed
# unless -s), 1 errors or unconnected items found, 2 bad usage or tool failure.

set -eu
. "$(dirname "$0")/_cli.sh"

OUT=""; N=3; STRICT=0; REFILL="--refill-zones"
while getopts "o:n:sRh" opt; do
    case "$opt" in
        o) OUT="$OPTARG" ;;
        n) N="$OPTARG" ;;
        s) STRICT=1 ;;
        R) REFILL="" ;;
        *) sed -n '2,15p' "$0"; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -ge 1 ] || { sed -n '2,15p' "$0"; exit 2; }
CLI="$(find_cli)" || exit 2
HERE="$(cd "$(dirname "$0")" && pwd)"

SCH=""; PCB=""
for p in "$@"; do
    if [ -d "$p" ]; then
        pro="$(find "$p" -maxdepth 1 -name '*.kicad_pro' | head -n 1)"
        if [ -n "$pro" ] && [ -f "${pro%.kicad_pro}.kicad_sch" ]; then
            SCH="$SCH ${pro%.kicad_pro}.kicad_sch"
        elif [ -z "$pro" ]; then
            SCH="$SCH $(find "$p" -maxdepth 1 -name '*.kicad_sch' | head -n 1)"
        fi
        PCB="$PCB $(find "$p" -maxdepth 1 -name '*.kicad_pcb')"
    else
        case "$p" in
            *.kicad_sch) SCH="$SCH $p" ;;
            *.kicad_pcb) PCB="$PCB $p" ;;
            *.kicad_pro) [ -f "${p%.kicad_pro}.kicad_sch" ] && SCH="$SCH ${p%.kicad_pro}.kicad_sch"
                         [ -f "${p%.kicad_pro}.kicad_pcb" ] && PCB="$PCB ${p%.kicad_pro}.kicad_pcb" ;;
            *) echo "error: not a KiCad file or directory: $p" >&2; exit 2 ;;
        esac
    fi
done
SCH="$(echo $SCH)"; PCB="$(echo $PCB)"   # trim
[ -n "$SCH$PCB" ] || { echo "error: no .kicad_sch or .kicad_pcb found" >&2; exit 2; }

STATUS=0
run() {
    # run KIND FILE : kicad-cli report, then summary
    kind="$1"; file="$2"
    [ -f "$file" ] || { echo "error: no such file: $file" >&2; STATUS=2; return; }
    dir="${OUT:-$(dirname "$file")/checks}"
    mkdir -p "$dir"
    json="$dir/$(basename "${file%.*}")-$kind.json"
    if [ "$kind" = erc ]; then
        "$CLI" sch erc --format json --severity-all -o "$json" "$file" >"$json.log" 2>&1 || true
    else
        # shellcheck disable=SC2086
        "$CLI" pcb drc --format json --severity-all $REFILL -o "$json" "$file" >"$json.log" 2>&1 || true
    fi
    if [ ! -s "$json" ]; then
        echo "error: kicad-cli produced no $kind report for $file:" >&2
        cat "$json.log" >&2
        STATUS=2; return
    fi
    rm -f "$json.log"
    rc=0
    python3 -I "$HERE/summarize.py" "$kind" "$json" -n "$N" || rc=$?
    [ "$rc" -le 1 ] || STATUS=2
    [ "$rc" -ne 1 ] || { [ "$STATUS" -ne 0 ] || STATUS=1; }
    if [ "$STRICT" -eq 1 ] && [ "$rc" -eq 0 ]; then
        python3 -I - "$json" <<'PY' || { [ "$STATUS" -ne 0 ] || STATUS=1; }
import json, sys
d = json.load(open(sys.argv[1]))
v = list(d.get("violations", [])) + [x for s in d.get("sheets", []) for x in s.get("violations", [])]
sys.exit(1 if any(x["severity"] == "warning" for x in v) else 0)
PY
    fi
    echo "report: $json"
    echo
}

for f in $SCH; do run erc "$f"; done
for f in $PCB; do run drc "$f"; done
exit "$STATUS"
