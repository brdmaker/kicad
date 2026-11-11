# KiCad skills for Claude Code

Skills that drive KiCad headlessly from Claude Code, built on a bundled
`kicad-cli` (KiCad 10.99 development build, Linux x86_64).

| Skill | What it does |
|---|---|
| `kicad-cli` | The bundled `kicad-cli` with library setup and 3D model fetching |
| `kicad-libraries` | Search the official symbol and footprint libraries; create a missing part (datasheet, symbol, footprint) |
| `kicad-drc` | ERC and DRC with a short summary and an exit code |
| `kicad-fab-export` | Gerbers, drill, placement, BOM and a fabricator zip |
| `kicad-3d` | STEP/GLB export with component models, renders, simple 3D bodies via SolidCraft's CLI |

## Install

    git clone --depth 1 --branch claude-skills https://github.com/brdmaker/kicad ~/kicad-skills
    ~/kicad-skills/install.sh            # links skills/* into ~/.claude/skills
    ~/.claude/skills/kicad-cli/scripts/install-libs.sh   # once: libraries and global tables (about 450 MB)

The skills find each other as siblings in the skills folder. Runtime packages
(wxWidgets, OpenCascade, Boost and others) must be installed; the wrapper lists
what is missing. The branch is about 75 MB, mostly the compressed binaries.

## Notes

- Everything here was run against the bundled build. Generated symbols and
  footprints still need checking against the part's datasheet.
- SolidCraft's CLI is built locally by `kicad-3d/scripts/setup-solidcraft.sh`
  and is not part of this repository.
- KiCad itself is GPLv3 and its libraries are CC-BY-SA 4.0 with an exception for
  use in designs; see the upstream repositories for the exact terms.
