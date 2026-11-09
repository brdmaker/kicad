# KiCad binaries and libraries (orphan branch `binaries`)

KiCad **10.0.8** (Debian 13 build from the official `kicad/kicad:10.0.8-amd64-full` image),
repacked so a session can fetch it and run `kicad-cli` without Docker or a PPA. Nothing here is
built by us; KiCad is GPLv3 (see https://www.kicad.org, source: the `main` branch of this repo's
upstream). This branch has no history in common with the source branches.

| file | what |
|---|---|
| `kicad-10.0.8-runtime.tar.xz` | `kicad-cli`, the Python `pcbnew` module, every shared library they need (366 files, found from the ELF dependencies) and the image's glibc and loader |
| `kicad-10.0.8-data.tar.xz` | `usr/share/kicad`: symbols, footprints, templates, resources (no 3D models, no demos) |
| `3dmodels/kicad-10.0.8-3dmodels-<Library>.tar.xz` | one archive per 3D model library (STEP files, 105 libraries, 3.4 GB unpacked, 0.26 GB packed) |
| `install.sh`, `unpack3d.sh`, `kicad-cli`, `lib.sh` | install, unpack single 3D libraries, wrapper |
| `SHA256SUMS` | checksums of every archive (`sha256sum -c SHA256SUMS`) |

## Use

    git clone --depth 1 --branch binaries https://github.com/brdmaker/kicad kicad-bin
    cd kicad-bin && ./install.sh /opt/kicad-10.0.8          # add --all-3d for every 3D model
    ./unpack3d.sh /opt/kicad-10.0.8 Package_SO Connector_PinHeader_2.00mm   # or just the ones needed
    /opt/kicad-10.0.8/kicad-cli version

The wrapper starts `kicad-cli` through the bundle's own `ld-linux`, with `KICAD10_*_DIR` pointed at
the unpacked data, because the host's glibc is older than the bundle's. Needs bash, tar, xz.

## What it is for

Netlist export, ERC, DRC, plots, STEP/3D export and PCB scripting (`pcbnew` Python) of the
brdmaker boards (brdmot `ebaz4205/1.0/8x485`, hardware/*). The 8x485 files are KiCad 10 format
(`version 20260306`), which Ubuntu's KiCad 7 can not read.

## Provenance

Pulled from Docker Hub (`kicad/kicad:10.0.8-amd64-full`), layers unpacked, then repacked with
`tar | xz`; no file was changed. The GUI binaries (`kicad`, `pcbnew`, ...) are not included.
Update: pull a newer tag the same way and replace the archives.
