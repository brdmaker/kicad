#!/bin/sh
# Set up the KiCad toolchain used by the other skills, then run the doctor.
#
# Usage: setup.sh [kicad] [libs] [solidcraft] [freerouting] [all]
#   kicad        unpack the bundled kicad-cli and check its system libraries
#   libs         unpack the symbol/footprint libraries and install the global library tables
#   solidcraft   install solidcraft-cli (prebuilt branch of the fork, checksum verified)
#   freerouting  install Freerouting and its JRE (pinned hashes; nothing is run)
#   all          everything above (the default)
# Steps run in dependency order whatever the argument order. A failing step does
# not stop the others; the exit status is the number of failed steps. A step that
# prints NETWORK_BLOCKED host=... needs that host allowed (see the SKILL.md).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/_sibling.sh"

WANT=""
for a in "$@"; do
    case "$a" in
        all) WANT="kicad libs solidcraft freerouting" ;;
        kicad|libs|solidcraft|freerouting) WANT="$WANT $a" ;;
        *) sed -n '2,13p' "$0"; exit 2 ;;
    esac
done
[ -n "$WANT" ] || WANT="kicad libs solidcraft freerouting"

FAILED=0
step() {
    # step NAME COMMAND...
    name="$1"; shift
    echo "== $name"
    if "$@"; then echo "   done"; else echo "   FAILED: $name"; FAILED=$((FAILED + 1)); fi
    echo
}
want() { case " $WANT " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

if want kicad; then
    step "kicad-cli" sh -c '"$1" version' _ "$CLI_SKILL/scripts/kicad-cli"
fi
if want libs; then
    step "libraries and global tables" "$CLI_SKILL/scripts/install-libs.sh"
fi
if want solidcraft; then
    step "solidcraft-cli" "$TD_SKILL/scripts/setup-solidcraft.sh"
fi
if want freerouting; then
    step "freerouting" "$HERE/setup-freerouting.sh"
fi

echo "== doctor"
"$HERE/doctor.sh" || true
exit "$FAILED"
