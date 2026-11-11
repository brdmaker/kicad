---
name: kicad-libraries
description: Look up parts in the official KiCad symbol and footprint libraries without installing KiCad. Use to find a symbol or footprint by name, description or keyword (resistors, connectors, MCUs, ICs), to check its pins, pads, default footprint, datasheet and 3D model reference, or to get the library file path for use in a design. Bundles an offline snapshot of kicad-symbols and kicad-footprints.
---

# kicad-libraries

An offline snapshot of the official KiCad libraries (kicad-symbols and
kicad-footprints, `master`, 22,928 symbols and 155 footprint libraries) with
search and lookup scripts. Everything runs with `sh`, `grep`, `find` and `awk`.

Scripts are in this skill's `scripts/` directory.

```
SK=~/.claude/skills/kicad-libraries     # adjust to where this skill is installed
$SK/scripts/install-libs.sh             # once: unpacks about 450 MB into ~/.cache/kicad-libs-skill
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

## Limits

- A snapshot taken when this skill was built. It does not update itself and may
  be older than the current official libraries.
- Search is text matching, not ranking. Broad patterns return up to `-n` results
  in alphabetical order, so narrow the pattern or raise `-n`.
- 3D models are not included.
- Libraries are CC-BY-SA 4.0 with an exception for use in designs. Check each
  library repository's license file before redistributing the libraries
  themselves.

## Install

```
git clone --depth 1 --branch claude-skill/kicad-libraries \
    https://github.com/brdmaker/kicad ~/.claude/skills/kicad-libraries
```
