---
name: kicad-fab-export
description: Produce manufacturing outputs for a KiCad board headlessly - Gerbers for every layer the board uses, Excellon drill files, component placement CSV, BOM and a fabricator-ready zip - with kicad-cli, and export single outputs such as PDF, SVG, DXF, IPC-2581, ODB++ or netlists. Use when preparing a board for a PCB or assembly house.
---

# kicad-fab-export

Needs the `kicad-cli` skill installed next to this one (or `KICAD_CLI` set), and
the libraries from its `scripts/install-libs.sh` so footprints resolve.

## One command: a fabrication package

```
SK=~/.claude/skills/kicad-fab-export       # adjust to where this skill is installed
$SK/scripts/fab-package.sh path/to/board.kicad_pcb
$SK/scripts/fab-package.sh -o out/ -s path/to/root.kicad_sch -n myboard board.kicad_pcb
```

Writes into `<board folder>/fab/` (or `-o`):

| Output | Content |
|---|---|
| `gerbers/` | F.Cu, every inner copper layer the board names, B.Cu, mask, paste, silk, Edge.Cuts, plus a `.gbrjob` |
| `drill/` | Excellon, plated and non-plated in separate files, plus a PDF drill map |
| `NAME-pos.csv` | placement in mm, both sides, DNP parts left out |
| `NAME-bom.csv` | bill of materials from the schematic next to the board (or `-s`) |
| `NAME-gerbers.zip` | gerbers and drill files only, flat, ready to upload |
| `MANIFEST.txt` | every file written |

Inner copper layers are read from the board, so a 4-layer board gets `In1_Cu`
and `In2_Cu` automatically. Tested on a 2-layer and a 4-layer demo board.

Run the `kicad-drc` skill first. This script exports whatever the board
contains and does not check it. Always open the Gerbers in a viewer, or ask the
fabricator's online check, before ordering.

## Single outputs

Use the `kicad-cli` wrapper directly (`scripts/kicad-cli` of that skill):

| Goal | Command |
|---|---|
| Layer PDF | `pcb export pdf -l F.Cu,F.SilkS,Edge.Cuts -o out.pdf board.kicad_pcb` |
| SVG / DXF | `pcb export svg ...` / `pcb export dxf ...` |
| IPC-2581 | `pcb export ipc2581 -o board.xml board.kicad_pcb` |
| ODB++ | `pcb export odb -o board.zip board.kicad_pcb` |
| IPC-D-356 netlist test file | `pcb export ipcd356 -o board.d356 board.kicad_pcb` |
| Specctra DSN (autorouter) | `pcb export specctra -o board.dsn board.kicad_pcb` |
| Schematic PDF | `sch export pdf -o sheet.pdf sheet.kicad_sch` |
| Netlist | `sch export netlist -o board.net sheet.kicad_sch` |
| Stats / stackup | `pcb export stats ...` / `pcb export stackup ...` |

`--help` on any of them lists the options. Many fabricators publish required
settings (Gerber X2 or not, drill units, naming). If one needs something else,
change the flags in `fab-package.sh`: `--no-x2`, `--no-protel-ext`,
`--excellon-units in`, `--format gerber` for drill.

## Assembly houses

Placement columns are `Ref,Val,Package,PosX,PosY,Rot,Side` in mm. Many assembly
services want their own column names or rotation offsets; that conversion is
not done here. For the BOM, add `--fields`, `--group-by` or `--preset` options to
`sch export bom` (see its `--help`) to match a house's template, for example to
include an MPN or LCSC field.

## Limits

- The layer list is fixed (copper, paste, silk, mask, Edge.Cuts). Fab, courtyard
  and user layers are not plotted; add them with `-l` in a direct call.
- Gerber output follows KiCad's defaults, not the board's saved plot settings.
- A variant board (`--variant`) is not exposed by the script; call kicad-cli
  directly with `--variant NAME`.
