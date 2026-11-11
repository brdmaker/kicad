#!/bin/sh
# Get a solidcraft-cli binary for new-3d-model.py.
#
# Usage: setup-solidcraft.sh [-d DIR] [-t TAG] [-b [-u REPO_URL] [-r REF] [-s SRC_DIR]]
#   -d DIR  install folder (default: $SOLIDCRAFT_HOME or ~/.cache/solidcraft-skill)
#   -t TAG  release to download, e.g. v0.30.1 (default: the latest release)
#   -b      build from source instead of downloading (needs cargo; about 20
#           minutes on 4 cores and a few GB of disk the first time)
#   -u URL  with -b: repository (default https://github.com/tangency-labs/solidcraft)
#   -r REF  with -b: branch or tag to build
#   -s SRC  with -b: build an existing checkout instead of cloning
#
# Default: download the official Linux package from the project's GitHub
# releases (about 100 MB), take solidcraft-cli out of it and install it as
# DIR/bin/solidcraft-cli. Nothing is stored in this skill: each user downloads
# the binary from the project itself. A set $SOLIDCRAFT_CLI is used as is.
# Prints the path of the binary.

set -eu

DIR="${SOLIDCRAFT_HOME:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/solidcraft-skill}"
TAG=""; BUILD=0; URL="https://github.com/tangency-labs/solidcraft"; REF=""; SRC=""
while getopts "d:t:bu:r:s:h" opt; do
    case "$opt" in
        d) DIR="$OPTARG" ;;
        t) TAG="$OPTARG" ;;
        b) BUILD=1 ;;
        u) URL="$OPTARG" ;;
        r) REF="$OPTARG" ;;
        s) SRC="$OPTARG" ;;
        *) sed -n '2,19p' "$0"; exit 2 ;;
    esac
done

if [ -n "${SOLIDCRAFT_CLI:-}" ] && [ -x "$SOLIDCRAFT_CLI" ]; then
    echo "$SOLIDCRAFT_CLI"; exit 0
fi

check_runs() {
    "$1" --version >/dev/null 2>&1 || { echo "error: $1 does not run (missing system libraries?)" >&2; exit 1; }
}

mkdir -p "$DIR/bin"

if [ "$BUILD" -eq 0 ]; then
    [ "$(uname -s)" = "Linux" ] || { echo "error: the download is for Linux; use -b to build, or set SOLIDCRAFT_CLI" >&2; exit 1; }
    case "$(uname -m)" in
        x86_64|amd64) ARCH=x86_64 ;;
        aarch64|arm64) ARCH=aarch64 ;;
        *) echo "error: no prebuilt package for $(uname -m); use -b" >&2; exit 1 ;;
    esac
    BASE="https://github.com/tangency-labs/solidcraft/releases"
    if [ -n "$TAG" ]; then LINK="$BASE/download/$TAG"; else LINK="$BASE/latest/download"; fi
    WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
    echo "Downloading solidcraft-linux-$ARCH.deb ${TAG:+($TAG) }..." >&2
    if ! LAST="$(curl -fsSL --max-time 900 -w '%{url_effective}' -o "$WORK/pkg.deb" "$LINK/solidcraft-linux-$ARCH.deb" 2>"$WORK/err")"; then
        cat "$WORK/err" >&2
        HOST="$(printf '%s' "${LAST:-$LINK}" | sed -E 's#^[a-z]+://([^/:?]+).*#\1#')"
        # the sandbox's egress proxy refuses hosts that are not on the allowed list
        if curl -sS -I --max-time 30 -o /dev/null "${LAST:-$LINK}" 2>&1 | grep -q 'CONNECT tunnel failed'; then
            echo "error: the network proxy blocked the host '$HOST'" >&2
            echo "NETWORK_BLOCKED host=$HOST" >&2
        else
            echo "error: download failed from $LINK (offline, or no such release)" >&2
        fi
        exit 1
    fi
    mkdir "$WORK/x"
    if command -v dpkg-deb >/dev/null 2>&1; then
        dpkg-deb --fsys-tarfile "$WORK/pkg.deb" | tar -x -C "$WORK/x" ./usr/bin/solidcraft-cli
    elif command -v ar >/dev/null 2>&1; then
        # a .deb is an ar archive holding data.tar.{gz,xz,zst}
        ( cd "$WORK" && ar x pkg.deb && ls data.tar.* >/dev/null )
        tar -x -C "$WORK/x" -f "$WORK"/data.tar.* ./usr/bin/solidcraft-cli
    else
        echo "error: need dpkg-deb or ar to unpack the package" >&2; exit 1
    fi
    [ -f "$WORK/x/usr/bin/solidcraft-cli" ] || { echo "error: solidcraft-cli not found in the package" >&2; exit 1; }
    cp "$WORK/x/usr/bin/solidcraft-cli" "$DIR/bin/solidcraft-cli"
    chmod +x "$DIR/bin/solidcraft-cli"
    check_runs "$DIR/bin/solidcraft-cli"
    echo "$("$DIR/bin/solidcraft-cli" --version 2>&1 | head -n 1)" >&2
    echo "$DIR/bin/solidcraft-cli"
    exit 0
fi

# ---- build from source ----
command -v cargo >/dev/null 2>&1 || { echo "error: cargo not found; install Rust from https://rustup.rs" >&2; exit 1; }
if [ -z "$SRC" ]; then
    command -v git >/dev/null 2>&1 || { echo "error: git not found" >&2; exit 1; }
    SRC="$DIR/src"
    if [ ! -d "$SRC/.git" ]; then
        # LFS objects are not needed for the CLI
        if [ -n "$REF" ]; then
            GIT_LFS_SKIP_SMUDGE=1 git clone --quiet --depth 1 --branch "$REF" "$URL" "$SRC"
        else
            GIT_LFS_SKIP_SMUDGE=1 git clone --quiet --depth 1 "$URL" "$SRC"
        fi
    fi
fi
[ -f "$SRC/Cargo.toml" ] || { echo "error: $SRC is not a SolidCraft checkout" >&2; exit 1; }

echo "Building solidcraft-cli from $SRC (first build is slow) ..." >&2
# No debug info and stripped: the default release profile gives a 740 MB binary.
( cd "$SRC" && CARGO_TARGET_DIR="$DIR/target" CARGO_PROFILE_RELEASE_DEBUG=false \
    CARGO_PROFILE_RELEASE_STRIP=symbols cargo build --release -p solidcraft-cli ) >&2
cp "$DIR/target/release/solidcraft-cli" "$DIR/bin/solidcraft-cli"
check_runs "$DIR/bin/solidcraft-cli"
echo "$DIR/bin/solidcraft-cli"
