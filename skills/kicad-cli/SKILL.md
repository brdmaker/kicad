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
  `scripts/install-libs.sh` once (about 450 MB unpacked). It also installs the
  global library tables (`scripts/setup-global-libs.sh`) into
  `~/.config/kicad/<version>/`. Do not skip this for DRC, ERC, netlists or
  anything that resolves library parts: without the tables, every standard
  footprint is reported as missing. On the pic_programmer demo DRC went from 58
  warnings to 0 and ERC from 64 to 3 after setup.
- **3D models** are not bundled. `scripts/fetch-3d-models.sh board.kicad_pcb`
  sparse-clones only the `.3dshapes` libraries a design uses into
  `~/.cache/kicad-packages3D` (`-n` for a dry run, `-d DIR` to choose the
  location) and prints an `export` line for every `KICADn_3DMODEL_DIR` name the
  design uses. `scripts/kicad-cli` picks the default location up automatically.
  Several hundred MB is normal for a medium board.
- **Older boards lose their components silently.** Boards made with older KiCad
  versions reference `.wrl` models, but the model repository holds only `.step`
  files, and `pcb export step` does not fall back. On the video demo board the
  plain export was identical to a board-only export (1.5 MB, 171 of 189 models
  "not found") and only a copy pointing at the `.step` files gave the full
  16.8 MB. Use the `kicad-3d` skill's `board-3d.sh`, which handles this and
  reports how many models were missing.

Existing `KICAD_SYMBOL_DIR`, `KICAD_FOOTPRINT_DIR` and `KICAD_3DMODEL_DIR`
(and their `KICAD10_` forms) are respected and not overridden.

## Related skills

| Task | Skill |
|---|---|
| DRC / ERC with a summary and exit code | `kicad-drc` |
| Gerbers, drill, placement, BOM, zip for a fabricator | `kicad-fab-export` |
| STEP / GLB export with component models, renders, 3D bodies for new parts | `kicad-3d` |
| Search libraries, create a missing symbol and footprint | `kicad-libraries` |

## Limits to know about

- This is a development build (10.99). It reads current KiCad files, but files
  saved by it may not open in older stable KiCad releases.
- There is no Python `pcbnew` module in this build. For scripting use the IPC
  API client (`pip install kicad-python`), which needs a running KiCad.
- **Autorouting is half covered.** `pcb export specctra` writes the DSN, but this
  CLI cannot import the router's routed result (SES), and without Python
  `pcbnew` there is no scripted way to do it here. In the current workflow that
  step still goes through the older KiCad bundle's raw `_pcbnew` module, outside
  these skills: export the DSN here, route externally, then import the SES with
  that bundle and bring the board back for DRC and export.
- The system libraries wxWidgets, OpenCascade, Boost and others must be
  installed. If any are missing, `scripts/kicad-cli` lists them and prints the
  apt command for Debian/Ubuntu 24.04.
- `HOME` must be set (the script sets it if empty). A harmless "schema file not
  found" message may appear on every run.
- Linux x86_64 only.

## Install

All the KiCad skills live in one branch. Clone it and run the installer, which
links each skill into `~/.claude/skills/`:

```
git clone --depth 1 --branch claude-skills https://github.com/brdmaker/kicad ~/kicad-skills
~/kicad-skills/install.sh
```
