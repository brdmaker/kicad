---
name: kicad-cli
description: Run KiCad's command-line tool (kicad-cli) without installing KiCad. Use for headless PCB and schematic work, such as DRC and ERC, Gerber/drill/PDF/SVG/STEP/BOM/position exports, Specctra DSN export for autorouters, converting Eagle/Altium/PADS boards to KiCad, and exporting footprints and symbols. Bundles a Linux x86_64 build with the official symbol and footprint libraries, and fetches 3D models on demand.
---

# kicad-cli

A prebuilt KiCad 10.99 (development) `kicad-cli` for Linux x86_64. Always run it
through `scripts/kicad-cli` in this skill directory; it unpacks the bundle on
first use and sets the library paths. Arguments are passed straight through.

```
SK=~/.claude/skills/kicad-cli      # adjust to where this skill is installed
$SK/scripts/kicad-cli --help
$SK/scripts/kicad-cli pcb drc -o drc.rpt board.kicad_pcb
```

## Common tasks

| Goal | Command |
|---|---|
| Design rule check | `pcb drc -o report.rpt board.kicad_pcb` |
| Electrical rule check | `sch erc -o report.rpt sheet.kicad_sch` |
| Gerbers | `pcb export gerbers -o out/ board.kicad_pcb` |
| Drill files | `pcb export drill -o out/ board.kicad_pcb` |
| Pick-and-place | `pcb export pos -o board.pos board.kicad_pcb` |
| PDF / SVG plot | `pcb export pdf -l F.Cu,Edge.Cuts -o board.pdf board.kicad_pcb` |
| 3D STEP | `pcb export step --subst-models -o board.step board.kicad_pcb` |
| Specctra DSN for an autorouter | `pcb export specctra -o board.dsn board.kicad_pcb` |
| Convert a foreign board | `pcb import --format eagle -o out.kicad_pcb in.brd` |
| BOM | `sch export bom -o bom.csv sheet.kicad_sch` |
| Footprint SVGs | `fp export svg -o out/ lib.pretty` |

Run `scripts/kicad-cli <group> <command> --help` for the options. Groups: `pcb`,
`sch`, `fp`, `sym`, `jobset`, `version`.

## Libraries

- **Symbols and footprints** (official libraries, snapshot): run
  `scripts/install-libs.sh` once (about 450 MB unpacked). Needed for ERC,
  footprint and netlist work that resolves library parts.
- **3D models** are not bundled. Before exporting STEP/VRML/GLB for a design,
  run `scripts/fetch-3d-models.sh board.kicad_pcb`. It sparse-clones only the
  `.3dshapes` libraries the design uses into `~/.cache/kicad-packages3D`
  (`-n` for a dry run, `-d DIR` to choose the location). `scripts/kicad-cli`
  picks that location up automatically. Several hundred MB is normal for a
  medium board.

Existing `KICAD_SYMBOL_DIR`, `KICAD_FOOTPRINT_DIR` and `KICAD_3DMODEL_DIR`
(and their `KICAD10_` forms) are respected and not overridden.

## Limits to know about

- This is a development build (10.99). It reads current KiCad files, but files
  saved by it may not open in older stable KiCad releases.
- There is no Python `pcbnew` module in this build. For scripting use the IPC
  API client (`pip install kicad-python`), which needs a running KiCad.
- A Specctra **SES import** (routed result from an autorouter) is not available
  in the CLI; only DSN export is.
- The system libraries wxWidgets, OpenCascade, Boost and others must be
  installed. If any are missing, `scripts/kicad-cli` lists them and prints the
  apt command for Debian/Ubuntu 24.04.
- `HOME` must be set (the script sets it if empty). A harmless "schema file not
  found" message may appear on every run.
- Linux x86_64 only.

## Install

Clone the branch into the skills directory:

```
git clone --depth 1 --branch claude-skill/kicad-cli \
    https://github.com/brdmaker/kicad ~/.claude/skills/kicad-cli
```
