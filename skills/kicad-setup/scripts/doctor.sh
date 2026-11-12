#!/bin/sh
# Report what is set up for the KiCad skills, without changing anything.
#
# Usage: doctor.sh [-r]
#   -r   also start the bundled Freerouting JRE once (java -version) to prove it runs
#
# Exit status: 0 when KiCad, the libraries and SolidCraft are usable, 1 otherwise.
# Freerouting is reported but optional (only autorouting needs it). Freerouting is
# checked by file and hash and is NOT run unless -r is given.

set -u
. "$(dirname "$0")/_sibling.sh"
RUNFR=0
while getopts "rh" opt; do
    case "$opt" in r) RUNFR=1 ;; *) sed -n '2,9p' "$0"; exit 2 ;; esac
done

BAD=0
row() { printf '%-16s %-8s %s\n' "$1" "$2" "$3"; }

# --- tools every script uses
missing=""
for t in git curl tar xz sha256sum python3; do command -v "$t" >/dev/null 2>&1 || missing="$missing $t"; done
if [ -z "$missing" ]; then row "basic tools" ok "git curl tar xz sha256sum python3"; else row "basic tools" MISSING "$missing"; BAD=1; fi

# --- KiCad CLI
CLI="$CLI_SKILL/scripts/kicad-cli"
if [ -x "$CLI" ]; then
    if [ -x "$KICAD_BASE/kicad-cli-linux-x86_64/bin/kicad-cli" ]; then
        v="$("$CLI" version 2>/dev/null | tail -n 1)"
        if [ -n "$v" ]; then row "kicad-cli" ok "$v  ($KICAD_BASE)"; else row "kicad-cli" BROKEN "does not run; see runtime libraries"; BAD=1; fi
        ml="$(LD_LIBRARY_PATH="$KICAD_BASE/kicad-cli-linux-x86_64/lib" ldd "$KICAD_BASE/kicad-cli-linux-x86_64/bin/kicad-cli" 2>/dev/null | grep -c 'not found' || true)"
        if [ "${ml:-0}" -eq 0 ]; then row "runtime libs" ok "all system libraries found"; else row "runtime libs" MISSING "$ml; run $CLI version for the list and apt command"; BAD=1; fi
    else
        row "kicad-cli" "not set" "run setup.sh kicad (unpacks the bundle on first use)"; BAD=1
    fi
else
    row "kicad-cli" MISSING "the kicad-cli skill is not installed next to this one"; BAD=1
fi

# --- libraries and global tables
ns=0; nf=0
[ -d "$KICAD_BASE/kicad-symbols" ] && ns="$(find "$KICAD_BASE/kicad-symbols" -maxdepth 1 \( -name '*.kicad_symdir' -o -name '*.kicad_sym' \) | wc -l)"
[ -d "$KICAD_BASE/kicad-footprints" ] && nf="$(find "$KICAD_BASE/kicad-footprints" -maxdepth 1 -name '*.pretty' | wc -l)"
if [ "$ns" -gt 0 ] && [ "$nf" -gt 0 ]; then row "libraries" ok "$ns symbol libs, $nf footprint libs"; else row "libraries" "not set" "run setup.sh libs"; BAD=1; fi
VER=""
[ -x "$CLI" ] && VER="$("$CLI" version 2>/dev/null | tail -n 1 | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')"
CFG="${XDG_CONFIG_HOME:-${HOME:-/tmp}/.config}/kicad/${VER:-?}"
if [ -f "$CFG/sym-lib-table" ] && [ -f "$CFG/fp-lib-table" ]; then row "global tables" ok "$CFG"; else row "global tables" "not set" "run setup.sh libs (without them DRC/ERC report every footprint as missing)"; BAD=1; fi
P3D="${KICAD_3DMODEL_CACHE:-$CACHE/kicad-packages3D}"
if [ -d "$P3D/.git" ]; then row "3d models" info "$(find "$P3D" -maxdepth 1 -name '*.3dshapes' | wc -l) libraries fetched in $P3D (fetched per board on demand)"; else row "3d models" info "none fetched yet (fetched per board on demand)"; fi

# --- SolidCraft
SCB="${SOLIDCRAFT_CLI:-$SC_BASE/bin/solidcraft-cli}"
if [ -x "$SCB" ]; then
    v="$("$SCB" --version 2>&1 | head -n 1)"
    if [ -n "$v" ]; then row "solidcraft-cli" ok "$v  ($SCB)"; else row "solidcraft-cli" BROKEN "$SCB does not run"; BAD=1; fi
else
    row "solidcraft-cli" "not set" "run setup.sh solidcraft"; BAD=1
fi

# --- Freerouting (optional)
PINS="$SKILL_DIR/freerouting.sha256"
if [ -f "$FR_BASE/freerouting.jar" ] && [ -x "$FR_BASE/bin/freerouting" ] && [ -x "$FR_BASE/rt/bin/java" ]; then
    have="$(sha256sum "$FR_BASE/freerouting.jar" | awk '{print $1}')"
    want="$(grep -v '^#' "$PINS" 2>/dev/null | awk '$2 == "freerouting.jar" {print $1}')"
    if [ "$have" = "$want" ]; then note="jar hash matches the pin"; else note="jar hash differs from the pin (accepted newer build?)"; fi
    if [ "$RUNFR" -eq 1 ]; then
        j="$("$FR_BASE/rt/bin/java" -version 2>&1 | head -n 1)" && note="$note; JRE runs: $j"
    else
        note="$note; not run (use -r)"
    fi
    row "freerouting" ok "$note  ($FR_BASE)"
else
    row "freerouting" "not set" "optional; run setup.sh freerouting for autorouting"
fi

echo
if [ "$BAD" -eq 0 ]; then echo "Ready: KiCad, libraries and SolidCraft are set up."; else echo "Not ready: run setup.sh for the items above."; fi
exit "$BAD"
