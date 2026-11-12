#!/bin/sh
# Install the Freerouting autorouter from the fork's prebuilt "binaries" branch.
#
# Usage: setup-freerouting.sh [-d DIR] [-u REPO_URL] [-B BRANCH] [-A] [-V]
#   -d DIR     install folder (default: $FREEROUTING_HOME or ~/.cache/freerouting-skill)
#   -u URL     repository (default https://github.com/brdmaker/freerouting)
#   -B BRANCH  branch with the binaries (default: binaries)
#   -A         accept files whose hashes differ from freerouting.sha256 (a newer build);
#              the new hashes are printed so they can be pinned
#   -V         after installing, run the bundled JRE once to check it starts
#
# The branch holds freerouting.jar (needs Java 25) and a minimal JRE 25. Both are
# executable code from the fork, so their SHA-256 hashes are checked against the
# pins in ../freerouting.sha256 BEFORE anything is unpacked, and nothing is run
# unless -V is given. The JRE is unpacked into DIR/rt (the archive is checked to
# hold only rt/ entries first) and DIR/bin/freerouting starts the jar headless:
#
#   DIR/bin/freerouting -de board.dsn -do board.ses -mp 20
#
# Prints the launcher's path.

set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
PINS="$HERE/../freerouting.sha256"
DIR="${FREEROUTING_HOME:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/freerouting-skill}"
URL="https://github.com/brdmaker/freerouting"; BRANCH="binaries"; ACCEPT=0; VERIFY=0
while getopts "d:u:B:AVh" opt; do
    case "$opt" in
        d) DIR="$OPTARG" ;;
        u) URL="$OPTARG" ;;
        B) BRANCH="$OPTARG" ;;
        A) ACCEPT=1 ;;
        V) VERIFY=1 ;;
        *) sed -n '2,21p' "$0"; exit 2 ;;
    esac
done

[ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || { echo "error: the prebuilt JRE is Linux x86_64 only" >&2; exit 1; }
for t in git tar xz sha256sum; do
    command -v "$t" >/dev/null 2>&1 || { echo "error: $t is required" >&2; exit 1; }
done

SRC="$DIR/src"
rm -rf "$SRC"
mkdir -p "$DIR"
echo "Fetching branch $BRANCH ..." >&2
GIT_LFS_SKIP_SMUDGE=1 git clone --quiet --depth 1 --branch "$BRANCH" "$URL" "$SRC" 2>"$DIR/.err" \
    || { cat "$DIR/.err" >&2; echo "error: could not fetch branch '$BRANCH' from $URL" >&2; exit 1; }
rm -f "$DIR/.err"

JAR="$SRC/freerouting.jar"; JRE="$SRC/linux-x64/jre25-freerouting-linux-x64.tar.xz"
[ -f "$JAR" ] && [ -f "$JRE" ] || { echo "error: branch '$BRANCH' lacks freerouting.jar or the JRE archive" >&2; exit 1; }

# 1. hashes against the pins, before anything is unpacked
ok=1
for rel in freerouting.jar linux-x64/jre25-freerouting-linux-x64.tar.xz; do
    have="$(sha256sum "$SRC/$rel" | awk '{print $1}')"
    want="$(grep -v '^#' "$PINS" | awk -v f="$rel" '$2 == f {print $1}')"
    if [ "$have" = "$want" ]; then
        echo "ok       $rel $have" >&2
    else
        echo "MISMATCH $rel" >&2
        echo "  pinned:  ${want:-none}" >&2
        echo "  fetched: $have" >&2
        ok=0
    fi
done
if [ "$ok" -eq 0 ] && [ "$ACCEPT" -eq 0 ]; then
    echo "error: the files differ from the pinned hashes; not installing. Review the branch, then" >&2
    echo "       run again with -A to accept it (and update freerouting.sha256)." >&2
    rm -rf "$SRC"
    exit 1
fi

# 2. the archive may only hold rt/ entries, with no absolute or .. paths
if tar -tJf "$JRE" | grep -qvE '^rt(/|$)' || tar -tJf "$JRE" | grep -qE '(^|/)\.\.(/|$)'; then
    echo "error: the JRE archive has entries outside rt/; not unpacking" >&2
    rm -rf "$SRC"; exit 1
fi

rm -rf "$DIR/rt"
tar -C "$DIR" -xJf "$JRE"
cp "$JAR" "$DIR/freerouting.jar"
mkdir -p "$DIR/bin"
cat > "$DIR/bin/freerouting" <<LAUNCH
#!/bin/sh
# Runs Freerouting headless with the bundled JRE 25. Usage: freerouting -de in.dsn -do out.ses [-mp passes]
exec "$DIR/rt/bin/java" -Djava.awt.headless=true -jar "$DIR/freerouting.jar" --gui.enabled=false "\$@"
LAUNCH
chmod +x "$DIR/bin/freerouting"
rm -rf "$SRC"

if [ "$VERIFY" -eq 1 ]; then
    "$DIR/rt/bin/java" -version 2>&1 | head -n 2 >&2 || { echo "error: the bundled JRE does not start" >&2; exit 1; }
fi
echo "$DIR/bin/freerouting"
