---
name: kicad-libraries
description: Look up parts in the official KiCad symbol and footprint libraries without installing KiCad, and create what is missing. Use to find a symbol or footprint by name, description or keyword, to check pins, pads, default footprint, datasheet and 3D model reference, or, when a part is not in the libraries, to fetch its datasheet into the project and model the symbol, footprint and 3D body as a project-local library using kicad-cli to verify them. Bundles an offline snapshot of kicad-symbols and kicad-footprints.
---

# kicad-libraries

An offline snapshot of the official KiCad libraries (kicad-symbols and
kicad-footprints, `master`, 22,928 symbols and 155 footprint libraries) with
search and lookup scripts. Everything runs with `sh`, `grep`, `find` and `awk`.

Scripts are in this skill's `scripts/` directory.

```
SK=~/.claude/skills/kicad-libraries     # adjust to where this skill is installed
$SK/scripts/install-libs.sh             # once: unpacks about 450 MB into ~/.cache/kicad-cli-skill (shared with the kicad-cli skill)
```

Set `KICAD_LIBS_HOME` to change the location. If `KICAD_SYMBOL_DIR` and
`KICAD_FOOTPRINT_DIR` (or their `KICAD10_` forms) are already set, those are
used instead and `install-libs.sh` is not needed.

## Find a part

```
$SK/scripts/lib-search.sh [-s|-f] [-d] [-n MAX] PATTERN
```

- `PATTERN` is a case-insensitive extended regex matched against the part name,
  so `'^R_0603'` anchors to the name.
- `-d` also matches descriptions, keywords and tags. Use it when you know what a
  part does but not what it is called (`-d 'buck converter'`).
- `-s` symbols only, `-f` footprints only. Default: both.
- Output is `Library:Name`, a tab, then the description.

Examples:

```
$SK/scripts/lib-search.sh '^R_0603_1608Metric$'
$SK/scripts/lib-search.sh -s LM358
$SK/scripts/lib-search.sh -d -n 10 'USB-C receptacle'
```

## Inspect a part

```
$SK/scripts/lib-show.sh [-s|-f] Library:Name
```

For a symbol it prints reference, value, default footprint, datasheet,
description, keywords, pin count and file path. For a footprint it prints
description, tags, pad count, 3D model reference and file path. Without
`-s`/`-f` it shows whichever exists.

```
$SK/scripts/lib-show.sh Device:R
$SK/scripts/lib-show.sh -f Resistor_SMD:R_0603_1608Metric
```

## How the library is laid out

- A symbol `Device:R` is the file `kicad-symbols/Device.kicad_symdir/R.kicad_sym`
  (one file per symbol in this snapshot, not one file per library).
- A footprint `Resistor_SMD:R_0603_1608Metric` is
  `kicad-footprints/Resistor_SMD.pretty/R_0603_1608Metric.kicad_mod`.
- Footprint 3D models are referenced as `${KICAD10_3DMODEL_DIR}/<Lib>.3dshapes/<name>.step`.
  The models themselves are not bundled; the `kicad-cli` skill has a script that
  fetches them for a design.

## Choosing a part

1. Search for the symbol, then run `lib-show.sh` on it. A non-empty `Footprint`
   field is the suggested footprint; many generic symbols leave it empty.
2. If it is empty, search footprints by package (`-f '0603'`, `-f 'SOIC-8'`)
   and confirm the pad count equals the symbol's pin count.
3. Check the footprint description for the package dimensions before relying on it.

## When the part is not in the libraries

Search with `-d` and a few spellings of the part number and function first. If
nothing fits, build the part inside the project, never inside the library
snapshot. The steps below were each run against `kicad-cli`; what they cannot
check is correctness against the datasheet, so that stays your job.

All paths are relative to the project folder; `PROJ` is its name and
`PROJ_parts` the project library (`PROJ_parts.kicad_sym`, `PROJ_parts.pretty/`).

1. **Datasheet.** Find the manufacturer's direct PDF link (web search for
   `<part number> datasheet pdf`), then
   `scripts/fetch-datasheet.sh -p PROJECT_DIR -n PARTNUMBER URL`.
   It stores `datasheets/PARTNUMBER.pdf`, refuses anything that is not a PDF and
   logs the source in `datasheets/SOURCES.md`. If the host is blocked or needs a
   login, ask the user for the file. Do not invent dimensions or pinouts.
2. **Read it.** Take the pin table and the recommended land pattern (not the
   package outline alone) from the PDF, and write the numbers with page
   references in `datasheets/PARTNUMBER-notes.md` before generating anything.
3. **Symbol.** Write a pin table (`number,name,type[,side]`) and run
   `scripts/new-symbol.py NAME --pins pins.csv -o PROJECT_DIR/PROJ_parts.kicad_sym
   --footprint PROJ_parts:FPNAME --datasheet datasheets/PARTNUMBER.pdf --description "..."`.
   It places pins by electrical type and replaces an earlier symbol of the same
   name. Run `new-symbol.py --help` for the pin types and layout rules.
4. **Footprint.** `scripts/new-footprint.py KIND FPNAME -o PROJECT_DIR/PROJ_parts.pretty ...`
   with `KIND` one of `chip`, `dual`, `quad` (optional thermal pad), `dip`, `row`,
   and the pad dimensions from the land pattern. Pin 1 is top left. Anything
   else (BGA, odd shapes): copy the nearest library footprint with
   `lib-show.sh` for its path, edit it, and keep the file format.
5. **Verify with kicad-cli.** `scripts/verify-part.sh -w -s out.svg fp FILE`
   (and `sym FILE`) round-trips the file through `kicad-cli upgrade`, renders it,
   and with `-w` replaces your file with KiCad's canonical re-save. Open the SVG
   and look at it: pad count, pad 1, orientation, courtyard.
   `scripts/check-pins.py LIB.kicad_sym SYMBOL FOOTPRINT.kicad_mod` confirms every
   pin has a pad and the reverse. A thermal pad with no symbol pin shows up here;
   decide whether it is a ground pin or should be listed as pin `EP`.
6. **Register the library.** `scripts/add-project-lib.sh PROJECT_DIR PROJ_parts`
   adds both to the project's `sym-lib-table` and `fp-lib-table` with
   `${KIPRJMOD}` paths.
7. **3D model.** The `kicad-3d` skill's `scripts/new-3d-model.py` builds a simple
   body plus leads as a STEP file with SolidCraft's CLI. Generate the footprint
   with `--model '${KIPRJMOD}/3dshapes/FPNAME.step'` or edit the `(model ...)`
   line.
8. **Check the design** with the `kicad-drc` skill.

Generated land patterns use the dimensions you give them. They are not
IPC-calculated, have a fixed 0.25 mm courtyard (0.5 mm for through hole) and a
simple silkscreen. Say so when handing a part to the user, and tell them which
datasheet page the numbers came from.

## Limits

- A snapshot taken when this skill was built. It does not update itself and may
  be older than the current official libraries.
- Search is text matching, not ranking. Broad patterns return up to `-n` results
  in alphabetical order, so narrow the pattern or raise `-n`.
- 3D models are not included in the snapshot. The `kicad-cli` skill's `fetch-3d-models.sh` fetches the ones a design uses.
- Libraries are CC-BY-SA 4.0 with an exception for use in designs. Check each
  library repository's license file before redistributing the libraries
  themselves.

## Install

```
git clone --depth 1 --branch claude-skill/kicad-libraries \
    https://github.com/brdmaker/kicad ~/.claude/skills/kicad-libraries
```
