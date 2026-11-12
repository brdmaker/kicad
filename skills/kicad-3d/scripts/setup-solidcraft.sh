#!/bin/sh
# Get a solidcraft-cli binary for new-3d-model.py.
#
# Usage: setup-solidcraft.sh [-d DIR] [-B BRANCH] [-u REPO_URL] [-R [-t TAG]] [-b [-r REF] [-s SRC]]
#   -d DIR     install folder (default: $SOLIDCRAFT_HOME or ~/.cache/solidcraft-skill)
#   -u URL     repository holding the prebuilt branch (default https://github.com/brdmaker/solidcraft)
#   -B BRANCH  prebuilt branch to use (default: the newest bin-cli-* branch)
#   -R         use the official release package from github.com/tangency-labs/solidcraft
#              instead of the prebuilt branch
#   -t TAG     with -R: release tag, e.g. v0.30.1 (default: latest)
#   -b         build from source instead (needs cargo; about 20 minutes on 4 cores)
#   -r REF     with -b: branch or tag to build
#   -s SRC     with -b: build an existing checkout instead of cloning
#
# Default order:
#   1. $SOLIDCRAFT_CLI, if it names an executable, is used as is.
#   2. The prebuilt branch of the fork (an orphan branch with solidcraft-cli.gz and
#      SHA256SUMS, fetched over git; checksum verified, Linux x86_64 only). The
#      branch also carries SolidCraft's agent skills, copied to DIR/skills.
#   3. The official release package (Linux x86_64 or aarch64).
# Installs DIR/bin/solidcraft-cli and prints its path.

set -eu

DIR="${SOLIDCRAFT_HOME:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/solidcraft-skill}"
URL="https://github.com/brdmaker/solidcraft"; BRANCH=""; TAG=""; REF=""; SRC=""
MODE=branch
while getopts "d:u:B:Rt:br:s:h" opt; do
    case "$opt" in
        d) DIR="$OPTARG" ;;
        u) URL="$OPTARG" ;;
        B) BRANCH="$OPTARG" ;;
        R) MODE=release ;;
        t) TAG="$OPTARG" ;;
        b) MODE=build ;;
        r) REF="$OPTARG" ;;
        s) SRC="$OPTARG" ;;
        *) sed -n '2,22p' "$0"; exit 2 ;;
    esac
done

if [ -n "${SOLIDCRAFT_CLI:-}" ] && [ -x "$SOLIDCRAFT_CLI" ]; then
    echo "$SOLIDCRAFT_CLI"; exit 0
fi

mkdir -p "$DIR/bin"

check_runs() {
    "$1" --version >/dev/null 2>&1 || { echo "error: $1 does not run (missing system libraries?)" >&2; return 1; }
}

# A refusal by the sandbox's egress proxy gets a marker the skills act on.
report_download_failure() {
    # report_download_failure URL LAST_URL ERRFILE
    cat "$3" >&2
    host="$(printf '%s' "${2:-$1}" | sed -E 's#^[a-z]+://([^/:?]+).*#\1#')"
    if curl -sS -I --max-time 30 -o /dev/null "${2:-$1}" 2>&1 | grep -q 'CONNECT tunnel failed'; then
        echo "error: the network proxy blocked the host '$host'" >&2
        echo "NETWORK_BLOCKED host=$host" >&2
    else
        echo "error: download failed: $1" >&2
    fi
}

from_branch() {
    [ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ] || { echo "note: the prebuilt branch is Linux x86_64 only" >&2; return 1; }
    command -v git >/dev/null 2>&1 || { echo "error: git not found" >&2; return 1; }
    br="$BRANCH"
    if [ -z "$br" ]; then
        # names carry an ISO date, so a plain sort finds the newest
        br="$(git ls-remote --heads "$URL" 'refs/heads/bin-cli-*' 2>"$DIR/.err" | sed 's#.*refs/heads/##' | sort | tail -n 1)"
        [ -n "$br" ] || { cat "$DIR/.err" >&2; echo "note: no bin-cli-* branch found in $URL" >&2; return 1; }
    fi
    pre="$DIR/prebuilt"
    rm -rf "$pre"
    echo "Fetching prebuilt branch $br ..." >&2
    GIT_LFS_SKIP_SMUDGE=1 git clone --quiet --depth 1 --branch "$br" "$URL" "$pre" 2>"$DIR/.err" \
        || { cat "$DIR/.err" >&2; echo "error: could not fetch branch '$br' from $URL" >&2; return 1; }
    [ -f "$pre/linux-x86_64/solidcraft-cli.gz" ] && [ -f "$pre/linux-x86_64/SHA256SUMS" ] \
        || { echo "error: branch '$br' has no linux-x86_64/solidcraft-cli.gz with SHA256SUMS" >&2; return 1; }
    ( cd "$pre/linux-x86_64" && grep ' solidcraft-cli.gz$' SHA256SUMS | sha256sum -c - >/dev/null 2>&1 ) \
        || { echo "error: checksum of solidcraft-cli.gz does not match SHA256SUMS; not installing" >&2; return 1; }
    gunzip -c "$pre/linux-x86_64/solidcraft-cli.gz" > "$DIR/bin/solidcraft-cli.new"
    chmod +x "$DIR/bin/solidcraft-cli.new"
    check_runs "$DIR/bin/solidcraft-cli.new" || { rm -f "$DIR/bin/solidcraft-cli.new"; return 1; }
    mv "$DIR/bin/solidcraft-cli.new" "$DIR/bin/solidcraft-cli"
    if [ -d "$pre/skills" ]; then
        rm -rf "$DIR/skills"; cp -r "$pre/skills" "$DIR/skills"
    fi
    rm -rf "$pre" "$DIR/.err"
    echo "branch $br: $("$DIR/bin/solidcraft-cli" --version 2>&1 | head -n 1)" >&2
    return 0
}

from_release() {
    [ "$(uname -s)" = Linux ] || { echo "error: the release download is for Linux; use -b to build, or set SOLIDCRAFT_CLI" >&2; return 1; }
    case "$(uname -m)" in
        x86_64|amd64) ARCH=x86_64 ;;
        aarch64|arm64) ARCH=aarch64 ;;
        *) echo "error: no prebuilt package for $(uname -m); use -b" >&2; return 1 ;;
    esac
    BASE="https://github.com/tangency-labs/solidcraft/releases"
    if [ -n "$TAG" ]; then LINK="$BASE/download/$TAG"; else LINK="$BASE/latest/download"; fi
    WORK="$(mktemp -d)"
    echo "Downloading solidcraft-linux-$ARCH.deb ${TAG:+($TAG) }..." >&2
    if ! LAST="$(curl -fsSL --max-time 900 -w '%{url_effective}' -o "$WORK/pkg.deb" "$LINK/solidcraft-linux-$ARCH.deb" 2>"$WORK/err")"; then
        report_download_failure "$LINK/solidcraft-linux-$ARCH.deb" "$LAST" "$WORK/err"
        rm -rf "$WORK"; return 1
    fi
    mkdir "$WORK/x"
    if command -v dpkg-deb >/dev/null 2>&1; then
        dpkg-deb --fsys-tarfile "$WORK/pkg.deb" | tar -x -C "$WORK/x" ./usr/bin/solidcraft-cli
    elif command -v ar >/dev/null 2>&1; then
        # a .deb is an ar archive holding data.tar.{gz,xz,zst}
        ( cd "$WORK" && ar x pkg.deb )
        tar -x -C "$WORK/x" -f "$WORK"/data.tar.* ./usr/bin/solidcraft-cli
    else
        echo "error: need dpkg-deb or ar to unpack the package" >&2; rm -rf "$WORK"; return 1
    fi
    [ -f "$WORK/x/usr/bin/solidcraft-cli" ] || { echo "error: solidcraft-cli not found in the package" >&2; rm -rf "$WORK"; return 1; }
    cp "$WORK/x/usr/bin/solidcraft-cli" "$DIR/bin/solidcraft-cli"
    chmod +x "$DIR/bin/solidcraft-cli"
    rm -rf "$WORK"
    check_runs "$DIR/bin/solidcraft-cli" || return 1
    echo "release: $("$DIR/bin/solidcraft-cli" --version 2>&1 | head -n 1)" >&2
    return 0
}

from_source() {
    command -v cargo >/dev/null 2>&1 || { echo "error: cargo not found; install Rust from https://rustup.rs" >&2; return 1; }
    src="$SRC"
    if [ -z "$src" ]; then
        command -v git >/dev/null 2>&1 || { echo "error: git not found" >&2; return 1; }
        src="$DIR/src"
        if [ ! -d "$src/.git" ]; then
            # LFS objects are not needed for the CLI
            if [ -n "$REF" ]; then
                GIT_LFS_SKIP_SMUDGE=1 git clone --quiet --depth 1 --branch "$REF" "$URL" "$src"
            else
                GIT_LFS_SKIP_SMUDGE=1 git clone --quiet --depth 1 "$URL" "$src"
            fi
        fi
    fi
    [ -f "$src/Cargo.toml" ] || { echo "error: $src is not a SolidCraft checkout" >&2; return 1; }
    echo "Building solidcraft-cli from $src (first build is slow) ..." >&2
    # No debug info and stripped: the default release profile gives a 740 MB binary.
    ( cd "$src" && CARGO_TARGET_DIR="$DIR/target" CARGO_PROFILE_RELEASE_DEBUG=false \
        CARGO_PROFILE_RELEASE_STRIP=symbols cargo build --release -p solidcraft-cli ) >&2
    cp "$DIR/target/release/solidcraft-cli" "$DIR/bin/solidcraft-cli"
    check_runs "$DIR/bin/solidcraft-cli"
}

case "$MODE" in
    branch)
        if [ -n "$BRANCH" ]; then
            from_branch || exit 1                        # an explicit branch is not second-guessed
        else
            from_branch || { echo "Falling back to the official release package." >&2; from_release || exit 1; }
        fi ;;
    release) from_release || exit 1 ;;
    build) from_source || exit 1 ;;
esac
echo "$DIR/bin/solidcraft-cli"
