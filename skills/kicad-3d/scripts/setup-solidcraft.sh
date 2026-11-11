#!/bin/sh
# Get a solidcraft-cli binary: clone SolidCraft and build its CLI once, locally.
#
# Usage: setup-solidcraft.sh [-u REPO_URL] [-r REF] [-d DIR] [-s SRC_DIR]
#   -u URL  repository (default: https://github.com/brdmaker/solidcraft)
#   -r REF  branch or tag to build (default: the default branch)
#   -d DIR  install folder (default: $SOLIDCRAFT_HOME or ~/.cache/solidcraft-skill)
#   -s SRC  build an existing checkout instead of cloning
#
# Builds with cargo (rustup is used if the repository pins a toolchain) and
# installs DIR/bin/solidcraft-cli. A first build takes about 20 minutes on 4 cores
# and a few GB of disk; later runs reuse DIR/target and finish in seconds.
# new-3d-model.py finds the binary there, or via $SOLIDCRAFT_CLI.
#
# The binary is built on the machine that uses it and is not redistributed:
# SolidCraft's brand licence (LICENSE-BRAND) allows your own builds but needs the
# maintainers' permission to distribute builds under the SolidCraft name.

set -eu

URL="https://github.com/brdmaker/solidcraft"; REF=""; DIR="${SOLIDCRAFT_HOME:-${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}/solidcraft-skill}"; SRC=""
while getopts "u:r:d:s:h" opt; do
    case "$opt" in
        u) URL="$OPTARG" ;;
        r) REF="$OPTARG" ;;
        d) DIR="$OPTARG" ;;
        s) SRC="$OPTARG" ;;
        *) sed -n '2,16p' "$0"; exit 2 ;;
    esac
done

if [ -n "${SOLIDCRAFT_CLI:-}" ] && [ -x "$SOLIDCRAFT_CLI" ]; then
    echo "$SOLIDCRAFT_CLI"; exit 0
fi

command -v cargo >/dev/null 2>&1 || { echo "error: cargo not found; install Rust from https://rustup.rs" >&2; exit 1; }
command -v git >/dev/null 2>&1 || [ -n "$SRC" ] || { echo "error: git not found" >&2; exit 1; }

if [ -z "$SRC" ]; then
    SRC="$DIR/src"
    if [ ! -d "$SRC/.git" ]; then
        mkdir -p "$DIR"
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
# No debug info and stripped: the default release profile gives a 740 MB binary,
# this gives about 150 MB.
( cd "$SRC" && CARGO_TARGET_DIR="$DIR/target" CARGO_PROFILE_RELEASE_DEBUG=false \
    CARGO_PROFILE_RELEASE_STRIP=symbols cargo build --release -p solidcraft-cli ) >&2

mkdir -p "$DIR/bin"
cp "$DIR/target/release/solidcraft-cli" "$DIR/bin/solidcraft-cli"
"$DIR/bin/solidcraft-cli" commands >/dev/null 2>&1 || { echo "error: the built solidcraft-cli does not run" >&2; exit 1; }
echo "$DIR/bin/solidcraft-cli"
