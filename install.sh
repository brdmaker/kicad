#!/bin/bash
# Install the KiCad 10.0.8 bundle from this branch.
#   ./install.sh [PREFIX] [--all-3d]     default PREFIX=/opt/kicad-10.0.8
# Unpacks the runtime (kicad-cli, its libraries and its own glibc), the symbol/footprint/template
# data, and writes PREFIX/kicad-cli. 3D models are optional: --all-3d unpacks all of them, or
# unpack single libraries with ./unpack3d.sh PREFIX Package_SO Connector_PinHeader_2.00mm
# Needs bash, tar, xz. The bundle runs on its own glibc, so any x86-64 Linux will do.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); . "$here/lib.sh"
P=${1:-/opt/kicad-10.0.8}; all3d=0; [ "${2:-}" = "--all-3d" ] && all3d=1
mkdir -p "$P"
unpack "$here/kicad-10.0.8-runtime.tar.xz" "$P"
unpack "$here/kicad-10.0.8-data.tar.xz" "$P"
mkdir -p "$P/usr/share/kicad/3dmodels"
if [ "$all3d" = 1 ]; then
  for a in "$here"/3dmodels/*.tar.xz "$here"/3dmodels/*.tar.xz.part-00; do
    [ -e "$a" ] || continue; unpack "${a%.part-00}" "$P/usr/share/kicad/3dmodels"
  done
fi
# KiCad finds its _*.kiface modules next to the loader it was started by (lib/x86_64-linux-gnu)
for k in "$P"/usr/bin/*.kiface; do ln -sf "../../usr/bin/$(basename "$k")" "$P/lib/x86_64-linux-gnu/$(basename "$k")"; done
install -m 755 "$here/kicad-cli" "$P/kicad-cli"
echo "installed: $P/kicad-cli version"
