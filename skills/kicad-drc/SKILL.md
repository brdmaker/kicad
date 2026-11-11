---
name: kicad-drc
description: Run KiCad design rule checks (DRC) and electrical rule checks (ERC) headlessly on a project, board or schematic and get a short summary with counts, example violations and a pass/fail exit code. Use to validate a PCB or schematic before export, in a generator loop, or in CI, without opening KiCad.
---

# kicad-drc

Runs `kicad-cli sch erc` and `kicad-cli pcb drc` through the `kicad-cli` skill and
summarises the JSON reports. Needs the `kicad-cli` skill installed next to this
one (or `KICAD_CLI` pointing at a runner).

```
SK=~/.claude/skills/kicad-drc          # adjust to where this skill is installed
$SK/scripts/check.sh path/to/project   # ERC on the root schematic, DRC on every board
$SK/scripts/check.sh board.kicad_pcb   # one file
$SK/scripts/check.sh -s -n 5 project/  # strict (warnings fail), 5 examples per type
```

Exit status: `0` clean (warnings allowed unless `-s`), `1` errors or unconnected
items, `2` bad usage or the tool failed. JSON reports are kept in
`<project>/checks/` (`-o DIR` to move them) for anything the summary hides.

Zones are refilled in memory before DRC so results match what the editor shows;
the board file is never modified (`-R` skips the refill).

## Set up the libraries first

Run the `kicad-cli` skill's `scripts/install-libs.sh` once. It also installs the
global library tables. Without them every standard footprint is reported as
`The current configuration does not include the footprint library ...`, which
buries the real findings. On the pic_programmer demo, DRC went from 58 warnings
to 0 and ERC from 64 to 3 once the tables were in place. The summary marks these
as `[library setup]` and tells you when that is the cause.

## Reading the result

- `error` findings and `unconnected` items fail the run. Fix the design, rerun.
- `warning` findings (silk overlap, `wired_implicit_power`, ...) are reported but
  pass unless `-s`.
- `schematic parity` lists differences between schematic and board (missing
  footprints, net changes). It only fills when the schematic is next to the board.
- Positions are in mm, as in the editor, with Y pointing down.

## Custom rules and severity

Project rules live in `<name>.kicad_dru` and the severity of each check in the
`.kicad_pro` file (`board.design_settings.rule_severities`). The checker honours
both, so a team's rules are applied without any extra flags. To prove the
pipeline catches problems, a rule such as
`(rule "t" (constraint clearance (min 3mm)))` in a scratch copy produces many
clearance errors and a non-zero exit.

## Limits

- Checks only what KiCad's rule engine checks. It does not validate a land
  pattern against a datasheet or a pinout against a part.
- ERC needs the root schematic. For a directory it takes the one named like the
  `.kicad_pro`; pass the sheet explicitly otherwise.
- Runs one board at a time per call; for several boards pass several paths.
