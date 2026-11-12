# KiCad skills for Claude Code

Skills that drive KiCad headlessly from Claude Code, built on a bundled
`kicad-cli` (KiCad 10.99 development build, Linux x86_64).

| Skill | What it does |
|---|---|
| `kicad-setup` | Install and check everything: kicad-cli, libraries and global tables, SolidCraft CLI, Freerouting (`doctor.sh`, `setup.sh`) |
| `kicad-cli` | The bundled `kicad-cli` with library setup and 3D model fetching |
| `kicad-libraries` | Search the official symbol and footprint libraries; create a missing part (datasheet, symbol, footprint) |
| `kicad-drc` | ERC and DRC with a short summary and an exit code |
| `kicad-fab-export` | Gerbers, drill, placement, BOM and a fabricator zip |
| `kicad-3d` | STEP/GLB export with component models, renders, simple 3D bodies via SolidCraft's CLI |

## Install

    git clone --depth 1 --branch claude-skills https://github.com/brdmaker/kicad ~/kicad-skills
    ~/kicad-skills/install.sh            # links skills/* into ~/.claude/skills
    ~/.claude/skills/kicad-setup/scripts/setup.sh        # kicad-cli, libraries, SolidCraft CLI, Freerouting (about 940 MB on disk)
    ~/.claude/skills/kicad-setup/scripts/doctor.sh       # check what is set up

The skills find each other as siblings in the skills folder. Runtime packages
(wxWidgets, OpenCascade, Boost and others) must be installed; the wrapper lists
what is missing. The branch is about 75 MB, mostly the compressed binaries.

## Notes

- Freerouting is hash-pinned and unpacked by `kicad-setup`, but was never started in the session that wrote it (the environment blocked running it); run `setup-freerouting.sh -V` first.
- Everything else here was run against the bundled build. Generated symbols and
  footprints still need checking against the part's datasheet.
- SolidCraft's CLI is fetched by `kicad-3d/scripts/setup-solidcraft.sh` from the
  prebuilt `bin-cli-*` branch of `brdmaker/solidcraft` (checksum verified), with
  the official release as a fallback. It is not part of this repository.
- Datasheet and release downloads go through the sandbox's network policy. When
  a host is blocked, the scripts print `NETWORK_BLOCKED host=...` and the skills
  tell Claude to ask the user to allow that host.
- Not covered: importing an autorouter's SES result. The CLI cannot do it and
  this build has no Python `pcbnew`; that step still goes through the older
  KiCad bundle's `_pcbnew` module.
- KiCad itself is GPLv3 and its libraries are CC-BY-SA 4.0 with an exception for
  use in designs; see the upstream repositories for the exact terms.
