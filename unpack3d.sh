#!/bin/bash
# ./unpack3d.sh PREFIX LIBRARY...   e.g. ./unpack3d.sh /opt/kicad-10.0.8 Package_SO Connector_PinHeader_2.00mm
# LIBRARY is a folder name in 3dmodels/ without the .3dshapes suffix (ls 3dmodels/ to see them).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); . "$here/lib.sh"; P=$1; shift
mkdir -p "$P/usr/share/kicad/3dmodels"
for lib in "$@"; do unpack "$here/3dmodels/kicad-10.0.8-3dmodels-$lib.tar.xz" "$P/usr/share/kicad/3dmodels"; done
