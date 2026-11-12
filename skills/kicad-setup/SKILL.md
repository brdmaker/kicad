---
name: kicad-setup
description: Install and check the toolchain the KiCad skills need - the bundled KiCad 10 kicad-cli and its system libraries, the official symbol and footprint libraries with the global library tables, SolidCraft's CLI for 3D bodies, and the Freerouting autorouter. Use first on a new machine or session, when another kicad skill reports something missing, or to diagnose why DRC, exports or routing fail.
---

# kicad-setup

One command sets up everything; one command says what is missing.

```
SK=~/.claude/skills/kicad-setup            # adjust to where this skill is installed
$SK/scripts/doctor.sh                      # report only, changes nothing
$SK/scripts/setup.sh                       # set up everything
$SK/scripts/setup.sh libs solidcraft       # or only some steps
```

`doctor.sh` exits 0 when KiCad, the libraries and SolidCraft are usable (Freerouting
is optional). `setup.sh` runs the steps in dependency order, keeps going when one
fails, ends with the doctor, and exits with the number of failed steps. On an
empty machine the whole run took about 22 seconds with a normal connection.

Needs Linux x86_64 and `git curl tar xz sha256sum python3`. Nothing else: no
Java, no Rust, no KiCad install.

## The four parts

| Step | What it installs | From | Where | On disk |
|---|---|---|---|---|
| `kicad` | KiCad 10.99 `kicad-cli` | the `kicad-cli` skill's own tarball | `~/.cache/kicad-cli-skill/` | 217 MB |
| `libs` | official symbol and footprint libraries, and the global `sym-lib-table` / `fp-lib-table` | the same skill | `~/.cache/kicad-cli-skill/` and `~/.config/kicad/10.99/` | 457 MB |
| `solidcraft` | `solidcraft-cli` | newest `bin-cli-*` branch of `brdmaker/solidcraft`, over git, checksum verified | `~/.cache/solidcraft-skill/` | 148 MB |
| `freerouting` | Freerouting and a minimal JRE 25 | `binaries` branch of `brdmaker/freerouting`, hashes pinned | `~/.cache/freerouting-skill/` | 124 MB |

Each step can be run on its own through the script it delegates to:
`kicad-cli/scripts/kicad-cli version`, `kicad-cli/scripts/install-libs.sh`,
`kicad-3d/scripts/setup-solidcraft.sh`, `scripts/setup-freerouting.sh`.

### 1. kicad-cli
The first run of `kicad-cli/scripts/kicad-cli` unpacks the bundle and checks its
system libraries (wxWidgets, OpenCascade, Boost, ...). If any is missing it lists
them and prints the apt command for Debian/Ubuntu 24.04. Install those packages,
then run it again. The doctor shows the same finding as `runtime libs`.

### 2. Libraries and global tables
Do not skip the tables. Without `~/.config/kicad/10.99/sym-lib-table` and
`fp-lib-table`, headless DRC and ERC report every standard footprint as missing;
on the pic_programmer demo that was 58 DRC warnings that vanished once the tables
were in place. `libs` installs both. 3D models are not part of this step; they are
fetched per board by `kicad-3d/scripts/board-3d.sh`.

### 3. SolidCraft CLI
Used by `kicad-3d/scripts/new-3d-model.py` to build a package body when the
library has no 3D model. The default is the prebuilt branch of the fork, verified
against its `SHA256SUMS`; the official release and a source build are fallbacks
(`setup-solidcraft.sh -R` / `-b`). The branch also supplies SolidCraft's agent
skills, copied to `~/.cache/solidcraft-skill/skills/`.

### 4. Freerouting
The autorouter, for boards whose routing is not done. It is a Java program; the
fork's branch holds the jar, which needs Java 25, together with a minimal JRE 25,
so the system Java is not used (a plain Java 21 cannot run it).

```
~/.cache/freerouting-skill/bin/freerouting -de board.dsn -do board.ses -mp 20
```

Make the DSN with `kicad-cli pcb export specctra -o board.dsn board.kicad_pcb`
(see the `kicad-cli` skill). `-mp` is the maximum number of routing passes.

**Trust.** The jar and the JRE are executable code from the fork, so
`setup-freerouting.sh` does these in order, and runs nothing unless `-V` is given:
1. Compares the SHA-256 of both files with the pins in `freerouting.sha256`
   (build of master `099368c6`, branch commit `bbbdf127`) and stops on a mismatch.
2. Checks that the JRE archive holds only `rt/` entries, with no absolute or `..`
   paths, then unpacks it.
3. Writes a launcher, `bin/freerouting`, that starts the jar headless.

A newer build of the branch is refused until someone has looked at it; then use
`-A` to accept it and replace the pins. `doctor.sh` checks the installed jar
against the pins and starts the JRE only with `-r`.

**Not verified here.** In the session where this skill was written, running the
downloaded Freerouting was blocked by the environment's permission check, so the
jar and JRE were inspected, hash-checked and unpacked but never started. The
fork's README reports routing of two test boards with this exact JRE. Run
`setup-freerouting.sh -V` and a first routing job yourself before relying on it.

**After routing.** This toolchain exports the DSN and runs the router; importing
the routed SES back into the board is not possible with this `kicad-cli`, and
there is no Python `pcbnew` in this build. That step still goes through the older
KiCad bundle's raw `_pcbnew` module, outside these skills.

## Network access

| Host | Used for | When |
|---|---|---|
| `github.com` | the `brdmaker/solidcraft` and `brdmaker/freerouting` branches (git) | steps 3 and 4 |
| `gitlab.com` | the official 3D model library | when a board needs models |
| `release-assets.githubusercontent.com` | the SolidCraft release package | only the `-R` fallback |

A step that is refused by the sandbox's network policy prints
`NETWORK_BLOCKED host=<name>`. In Claude Code on the web, ask the user to allow
that host as described in step 1 of the `kicad-libraries` skill (`get_environment`,
one sentence of explanation, then `update_environment` with `add_allowed_hosts`),
and run the step again.

## Where things live

| Variable | Default | Meaning |
|---|---|---|
| `KICAD_CLI_HOME` | `~/.cache/kicad-cli-skill` | bundle and libraries |
| `SOLIDCRAFT_HOME` | `~/.cache/solidcraft-skill` | SolidCraft binary and skills |
| `FREEROUTING_HOME` | `~/.cache/freerouting-skill` | jar, JRE, launcher |
| `SOLIDCRAFT_CLI` | unset | use this solidcraft-cli instead of installing one |
| `KICAD_3DMODEL_CACHE` | `~/.cache/kicad-packages3D` | fetched 3D models |
| `XDG_CACHE_HOME`, `XDG_CONFIG_HOME` | `~/.cache`, `~/.config` | roots for the above |

## After setup

| Task | Skill |
|---|---|
| Find or create a part | `kicad-libraries` |
| ERC and DRC | `kicad-drc` |
| Gerbers, drill, BOM, zip | `kicad-fab-export` |
| STEP/GLB, renders, 3D bodies | `kicad-3d` |
| Any other `kicad-cli` command | `kicad-cli` |

## Limits

- Linux x86_64 only. The prebuilt SolidCraft branch and the JRE are x86_64; the
  SolidCraft release fallback also covers aarch64, the rest does not.
- Setup uses about 940 MB of disk in total (measured on a fresh install); about half of it is the libraries.
- The KiCad build is a 10.99 development version; boards saved by it may not open
  in older stable releases.
