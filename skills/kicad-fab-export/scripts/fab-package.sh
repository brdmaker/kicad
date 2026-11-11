#!/bin/sh
# Produce a manufacturing package for a KiCad board, headlessly.
#
# Usage: fab-package.sh [-o OUTDIR] [-s SCHEMATIC] [-n NAME] BOARD.kicad_pcb
#   -o OUTDIR     output folder (default: BOARD's folder/fab)
#   -s SCH        schematic for the bill of materials (default: BOARD name with
#                 .kicad_sch, used when it exists)
#   -n NAME       base name of the outputs (default: the board's name)
#
# Writes into OUTDIR:
#   gerbers/          copper (all layers the board uses), mask, paste, silk, Edge.Cuts
#   drill/            Excellon files, PTH and NPTH separate, plus a drill map (PDF)
#   NAME-pos.csv      component placement (mm), SMD and through-hole, DNP excluded
#   NAME-bom.csv      bill of materials, when a schematic is available
#   NAME-gerbers.zip  gerbers/ and drill/ ready to upload to a fabricator
#   MANIFEST.txt      every file written
# Run DRC first (the kicad-drc skill); this script does not check the design.

set -eu
. "$(dirname "$0")/_cli.sh"

OUT=""; SCH=""; NAME=""
while getopts "o:s:n:h" opt; do
    case "$opt" in
        o) OUT="$OPTARG" ;;
        s) SCH="$OPTARG" ;;
        n) NAME="$OPTARG" ;;
        *) sed -n '2,19p' "$0"; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || { sed -n '2,19p' "$0"; exit 2; }
PCB="$1"
[ -f "$PCB" ] || { echo "error: no such file: $PCB" >&2; exit 2; }
CLI="$(find_cli)" || exit 2

[ -n "$NAME" ] || NAME="$(basename "${PCB%.kicad_pcb}")"
[ -n "$OUT" ] || OUT="$(dirname "$PCB")/fab"
[ -n "$SCH" ] || { [ -f "${PCB%.kicad_pcb}.kicad_sch" ] && SCH="${PCB%.kicad_pcb}.kicad_sch" || true; }

# Copper layers actually present: F.Cu, B.Cu and any In<N>.Cu named in the board
INNER="$(grep -oE '"In[0-9]+\.Cu"' "$PCB" | tr -d '"' | sort -t n -k 2 -n -u | tr '\n' ',' | sed 's/,$//')"
LAYERS="F.Cu${INNER:+,$INNER},B.Cu,F.Paste,B.Paste,F.SilkS,B.SilkS,F.Mask,B.Mask,Edge.Cuts"

rm -rf "$OUT/gerbers" "$OUT/drill"
mkdir -p "$OUT/gerbers" "$OUT/drill"

echo "Gerbers ($LAYERS)"
"$CLI" pcb export gerbers -l "$LAYERS" --subtract-soldermask -o "$OUT/gerbers/" "$PCB" >"$OUT/.log" 2>&1 \
    || { cat "$OUT/.log" >&2; exit 1; }

echo "Drill"
"$CLI" pcb export drill --format excellon --excellon-separate-th --generate-map --map-format pdf \
    -o "$OUT/drill/" "$PCB" >>"$OUT/.log" 2>&1 || { cat "$OUT/.log" >&2; exit 1; }

echo "Placement"
"$CLI" pcb export pos --format csv --units mm --side both --exclude-dnp \
    -o "$OUT/$NAME-pos.csv" "$PCB" >>"$OUT/.log" 2>&1 || { cat "$OUT/.log" >&2; exit 1; }

if [ -n "$SCH" ] && [ -f "$SCH" ]; then
    echo "BOM from $SCH"
    "$CLI" sch export bom -o "$OUT/$NAME-bom.csv" "$SCH" >>"$OUT/.log" 2>&1 || { cat "$OUT/.log" >&2; exit 1; }
else
    echo "BOM skipped (no schematic found; pass -s)"
fi
rm -f "$OUT/.log"

# Zip gerbers and drill files only, flat, as fabricators expect
python3 -I - "$OUT" "$NAME" <<'PY'
import os, sys, zipfile
out, name = sys.argv[1:3]
with zipfile.ZipFile(os.path.join(out, name + "-gerbers.zip"), "w", zipfile.ZIP_DEFLATED) as z:
    for sub in ("gerbers", "drill"):
        for f in sorted(os.listdir(os.path.join(out, sub))):
            if f.lower().endswith((".pdf", ".svg", ".ps", ".dxf")):
                continue  # maps and reports are for people, not the fabricator
            z.write(os.path.join(out, sub, f), f)
PY

( cd "$OUT" && find . -type f ! -name MANIFEST.txt | sed 's#^\./##' | sort ) > "$OUT/MANIFEST.txt"
echo
echo "Wrote $(wc -l < "$OUT/MANIFEST.txt") files to $OUT:"
sed 's/^/  /' "$OUT/MANIFEST.txt"
