#!/bin/sh
# Download a datasheet PDF into a KiCad project and record where it came from.
#
# Usage: fetch-datasheet.sh [-p PROJECT_DIR] [-n NAME] URL
#   -p DIR   project directory (default: current directory); the file goes to
#            DIR/datasheets/NAME.pdf
#   -n NAME  file name without .pdf (default: taken from the URL)
#
# The download is rejected unless it is a PDF, so an HTML landing page or a
# login wall is reported instead of being stored under a .pdf name. Use the
# direct link to the PDF, not the product page. Each success adds a line to
# DIR/datasheets/SOURCES.md. Prints the stored path.

set -eu

PROJ="."; NAME=""
while getopts "p:n:h" opt; do
    case "$opt" in
        p) PROJ="$OPTARG" ;;
        n) NAME="$OPTARG" ;;
        *) sed -n '2,14p' "$0"; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -eq 1 ] || { sed -n '2,14p' "$0"; exit 2; }
URL="$1"
case "$URL" in http://*|https://*) ;; *) echo "error: not an http(s) URL: $URL" >&2; exit 2 ;; esac

if [ -z "$NAME" ]; then
    NAME="$(basename "${URL%%[?#]*}" | sed -E 's/\.pdf$//I; s/[^A-Za-z0-9._-]+/_/g')"
    [ -n "$NAME" ] || NAME="datasheet"
fi
NAME="$(printf '%s' "$NAME" | sed -E 's/[^A-Za-z0-9._-]+/_/g')"

DIR="$PROJ/datasheets"
mkdir -p "$DIR"
TMP="$(mktemp "$DIR/.dl.XXXXXX")"

# Some vendors refuse requests without a browser-like agent.
# -w prints the last URL tried, which is the host to blame after a redirect.
ERR="$(mktemp)"
trap 'rm -f "$TMP" "$ERR"' EXIT
rc=0
LAST="$(curl -fsSL --max-time 180 -A "Mozilla/5.0 (X11; Linux x86_64)" -w '%{url_effective}' \
        -o "$TMP" "$URL" 2>"$ERR")" || rc=$?
if [ "$rc" -ne 0 ]; then
    cat "$ERR" >&2
    HOST="$(printf '%s' "${LAST:-$URL}" | sed -E 's#^[a-z]+://([^/:?]+).*#\1#')"
    # The sandbox's egress proxy refuses hosts that are not on the environment's
    # allowed list. With -f curl reports that as a plain 403, so probe the failing
    # host again without -f, where it shows as 'CONNECT tunnel failed'.
    if curl -sS -I --max-time 30 -o /dev/null "${LAST:-$URL}" 2>&1 | grep -q 'CONNECT tunnel failed'; then
        echo "error: the network proxy blocked the host '$HOST'" >&2
        echo "NETWORK_BLOCKED host=$HOST" >&2
        echo "hint: in Claude Code on the web, ask the user to allow this host (see the kicad-libraries skill, step 1), then run this again" >&2
    else
        echo "error: download failed (curl exit $rc): $URL" >&2
    fi
    exit 1
fi
if [ "$(head -c 5 "$TMP")" != "%PDF-" ]; then
    echo "error: $URL did not return a PDF (probably a web page); find the direct PDF link" >&2
    exit 1
fi

mv "$TMP" "$DIR/$NAME.pdf"
trap - EXIT
printf -- '- %s.pdf  <-  %s  (fetched %s)\n' "$NAME" "$URL" "$(date -u +%Y-%m-%d)" >> "$DIR/SOURCES.md"
echo "$DIR/$NAME.pdf"
