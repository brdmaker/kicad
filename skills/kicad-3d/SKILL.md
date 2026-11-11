---
name: kicad-3d
description: Headless 3D work for KiCad boards - export STEP/GLB/STL/VRML with the component models actually included (fetching only the models a board uses), render PNG views, and build simple STEP models of packages that are missing from the 3D library by driving SolidCraft's CLI. Use for mechanical hand-off, enclosure design, or giving a custom footprint a 3D body.
---

# kicad-3d

Needs the `kicad-cli` skill installed next to this one (or `KICAD_CLI` set). The
3D body generator also needs SolidCraft's CLI (see below).

```
SK=~/.claude/skills/kicad-3d               # adjust to where this skill is installed
$SK/scripts/board-3d.sh board.kicad_pcb              # STEP with components
$SK/scripts/board-3d.sh -f glb -o board.glb board.kicad_pcb
$SK/scripts/board-3d.sh board.kicad_pcb -- --board-only      # bare board
$SK/scripts/render-board.sh -v top,iso board.kicad_pcb       # PNG views
```

## Export a board with its components

`scripts/board-3d.sh [-f FORMAT] [-o OUT] [-F] BOARD [-- EXTRA ARGS]`

Formats: `step` (default), `stpz`, `glb`, `stl`, `vrml`, `ply`, `brep`, `xao`,
`u3d`, `3dpdf`. Extra arguments after `--` go to `kicad-cli pcb export`, for
example `--include-tracks --include-pads --include-zones`, `--no-dnp`,
`--component-filter 'U*,J*'` or `--board-only`.

What it does first:
1. Fetches only the model libraries the board references from the official
   kicad-packages3D repository into `~/.cache/kicad-packages3D` (`-F` skips this).
2. For STEP-like formats, exports from a throwaway copy of the project in which
   the board's `.wrl` model references point at the `.step` files. This matters:
   the model repository holds STEP only, `--subst-models` needs the `.wrl` to
   exist, and boards from older KiCad versions reference `.wrl`. Without this
   step, the video demo board exported with no components at all (1.5 MB instead
   of 16.8 MB, 171 of 189 models "not found") and `kicad-cli` still reported
   success. Your project files are never modified.

It prints how many component models could not be loaded. Treat a non-zero
number as a finding: the part has no model in the library, or its path is wrong.
Boards that already reference `.step` files load directly.

## Render pictures

`scripts/render-board.sh [-o DIR] [-v top,bottom,iso,front,back,left,right] [-w PX] BOARD`

Writes `NAME-VIEW.png` (default views: top, bottom, iso; about 5 s each on the
demo board). In this headless build the renders show the board,
copper, pads and silkscreen. Component bodies did not appear in tests, even
with the models present and the board's references rewritten to `.step`. Use
STEP or GLB export for anything where the components matter.

## Model a missing package

When a footprint has no 3D model (a part made with the `kicad-libraries` skill,
or one the library lacks):

1. Get SolidCraft's CLI once: `scripts/setup-solidcraft.sh`. It downloads the
   official Linux package from SolidCraft's GitHub releases (about 100 MB, a few
   seconds), takes `solidcraft-cli` out of it and keeps it in
   `~/.cache/solidcraft-skill`. It needs `github.com` and
   `release-assets.githubusercontent.com` to be reachable; if the network policy
   blocks them, request access the same way as for datasheets (see the
   `kicad-libraries` skill). Set `SOLIDCRAFT_CLI` to use an existing binary,
   `-t TAG` to pin a release, or `-b` to build from source instead (about 20
   minutes). The binary is downloaded from the project by each user and is not
   stored in this repository. The scripts here were checked with release 0.30.1
   and with a 0.40.0-rc.4 source build; both gave identical models.
2. `scripts/new-3d-model.py KIND NAME -o PROJECT/3dshapes/NAME.step ...` with the
   same pad dimensions as the footprint plus the body height and lead sizes from
   the datasheet's package drawing. Kinds: `chip`, `dual`, `quad`, `dip`, `row`.
   `new-3d-model.py --help` lists every option.
3. Point the footprint at it: `(model "${KIPRJMOD}/3dshapes/NAME.step" ...)`, or
   pass `--model` to `new-footprint.py`.
4. Check it in the board: `board-3d.sh` should report no missing models, and the
   STEP grows by the model's solids.

The model is a set of plain boxes, one solid per body and lead, no colours or
fillets. It has the right size and position, which is what clearance and
enclosure checks need, but it is not a realistic picture. For a
better-looking model, drive SolidCraft's CLI directly with a longer script
(`solidcraft-cli run script.json --out part.step`; the commands are the ones in
SolidCraft's own modelling skill), or import a manufacturer's STEP.

Checked against hand-computed sizes with SolidCraft's `eval`, and loaded by
KiCad in a test board (a footprint with the model exported at 63.6 KB against
9.1 KB for the same footprint without it).

## Limits

- STEP export with many models can take minutes and tens of MB.
- The model fetcher downloads whole libraries, not single parts; a medium board
  pulled 650 MB.
- Component bodies are absent from headless PNG renders (see above).
- Generated bodies are blocky approximations, and the footprint orientation
  convention is assumed: pin 1 top left, model origin at the footprint origin.
