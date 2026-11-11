#!/bin/sh
# Link every skill in this repository into a Claude Code skills folder.
#
# Usage: install.sh [-d SKILLS_DIR] [-f]
#   -d DIR  target folder (default: $CLAUDE_SKILLS_DIR or ~/.claude/skills)
#   -f      replace an existing skill folder of the same name
#
# Links (not copies) are used, so `git pull` here updates the skills. The skills
# find each other as siblings in the target folder.

set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="${CLAUDE_SKILLS_DIR:-${HOME:-/tmp}/.claude/skills}"
FORCE=0
while getopts "d:fh" opt; do
    case "$opt" in
        d) DEST="$OPTARG" ;;
        f) FORCE=1 ;;
        *) sed -n '2,10p' "$0"; exit 2 ;;
    esac
done

mkdir -p "$DEST"
for s in "$HERE"/skills/*/; do
    name="$(basename "$s")"
    target="$DEST/$name"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "${s%/}" ]; then
        echo "ok       $name (already linked)"
    elif [ -e "$target" ] || [ -L "$target" ]; then
        if [ "$FORCE" -eq 1 ]; then
            rm -rf "$target"
            ln -s "${s%/}" "$target"
            echo "replaced $name"
        else
            echo "skipped  $name ($target exists; use -f to replace)"
        fi
    else
        ln -s "${s%/}" "$target"
        echo "linked   $name"
    fi
done
