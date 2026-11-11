#!/usr/bin/env python3
"""Build a simple 3D model (STEP) of a package with SolidCraft's CLI.

Usage: new-3d-model.py KIND NAME -o OUT.step [dimensions] [--script-only]

KIND and the pad dimensions are the same as for the kicad-libraries skill's
new-footprint.py, so the model lines up with a footprint made from the same
numbers. Add the body height and lead sizes from the datasheet.

  chip   --pitch P --pad-w W --body-l L --body-w B --body-h H [--term-l T]
         two end terminals T long (default 0.3 * L, at most 0.5)
  dual   --pins N --pitch P --span S --pad-l L --pad-w W --body-w B --body-l H2
         --body-h H [--lead-t 0.2] [--lead-w W]   gull-wing style flat leads
  quad   --pins N --pitch P --span S --pad-l L --pad-w W --body B --body-h H
         [--epad WxH] [--lead-t 0.05]             QFN style flat terminals
  dip    --pins N [--pitch 2.54] [--row 7.62] --body-w B --body-l L --body-h H
         [--standoff 0.5] [--lead-w 0.5] [--pin-len 3.2]
  row    --pins N [--pitch 2.54] --body-h H [--lead-w 0.64] [--pin-len 3.0]
         [--pin-top 6.0]                          pin header

All lengths are mm. The footprint's y axis points down and the model's up, so
y is flipped here; pin 1 ends up top left in the footprint as usual. The model
is a set of plain boxes: body and leads, one solid each, no colours, no
fillets. It shows the right size and position, not the exact shape.

SolidCraft's CLI is found as $SOLIDCRAFT_CLI, else the one built by
setup-solidcraft.sh. --script-only writes OUT.json and stops.
"""

import argparse
import json
import os
import subprocess
import sys


class Model:
    def __init__(self):
        self.steps = []
        self.n = 0

    def box(self, name, cx, cy, z0, lx, ly, h):
        """Axis-aligned box from height z0 up by h, centred on (cx, cy)."""
        if min(lx, ly, h) <= 0:
            sys.exit("error: %s has a non-positive size (%s x %s x %s)" % (name, lx, ly, h))
        self.steps.append({"command": "solid.box", "params": {
            "length": round(lx, 4), "width": round(ly, 4), "height": round(h, 4),
            "center": [round(cx, 4), round(cy, 4), round(z0 + h / 2, 4)],
            "body_name": name, "operation": "new"}})


def chip(a, m):
    t = a.term_l or min(0.5, 0.3 * a.body_l)
    inner = a.body_l - 2 * t
    if inner <= 0:
        sys.exit("error: terminals are longer than the body")
    m.box("Body", 0, 0, 0, inner, a.body_w, a.body_h)
    for i, sgn in enumerate((-1, 1), 1):
        m.box("Terminal%d" % i, sgn * (a.body_l / 2 - t / 2), 0, 0, t, a.body_w, a.body_h)


def dual(a, m):
    half = a.pins // 2
    lt = a.lead_t
    y0 = -(half - 1) * a.pitch / 2
    hw = a.body_w / 2
    m.box("Body", 0, 0, lt, a.body_w, a.body_l, a.body_h - lt)
    foot = a.span / 2 + a.pad_l / 2 - 0.2           # the lead ends just inside the pad
    for i in range(half):
        y = -(y0 + i * a.pitch)
        for sgn, num in ((-1, i + 1), (1, a.pins - i)):
            x0, x1 = hw - 0.2, foot
            m.box("Lead%d" % num, sgn * (x0 + x1) / 2, y, 0, x1 - x0, a.lead_w or a.pad_w * 0.8, lt)


def quad(a, m):
    n = a.pins // 4
    lt = a.lead_t
    p0 = -(n - 1) * a.pitch / 2
    hw = a.body / 2
    m.box("Body", 0, 0, lt, a.body, a.body, a.body_h - lt)
    tl = 0.4                                         # terminal length along the pad axis
    for i in range(n):
        c = p0 + i * a.pitch
        for num, (x, y, horiz) in (
                (i + 1, (-1, -c, True)), (n + i + 1, (c, 1, False)),
                (3 * n - i, (1, -c, True)), (4 * n - i, (c, -1, False))):
            if horiz:
                m.box("Lead%d" % num, x * (hw - tl / 2), y, 0, tl, a.pad_w * 0.8, lt)
            else:
                m.box("Lead%d" % num, x, -y * (hw - tl / 2), 0, a.pad_w * 0.8, tl, lt)
    if a.epad:
        ew, eh = (float(v) for v in a.epad.lower().split("x"))
        m.box("ThermalPad", 0, 0, 0, ew, eh, lt)


def dip(a, m):
    half = a.pins // 2
    cx, cy = a.row / 2, (half - 1) * a.pitch / 2
    m.box("Body", 0, 0, a.standoff, a.body_w, a.body_l, a.body_h)
    for i in range(half):
        y = -(i * a.pitch - cy)
        for x, num in ((-cx, i + 1), (cx, a.pins - i)):
            m.box("Pin%d" % num, x, y, -a.pin_len, a.lead_w, a.lead_w * 0.5, a.pin_len + a.standoff)


def row(a, m):
    cy = (a.pins - 1) * a.pitch / 2
    m.box("Body", 0, 0, 0, a.pitch, a.pins * a.pitch, a.body_h)
    for i in range(a.pins):
        y = -(i * a.pitch - cy)
        m.box("PinBelow%d" % (i + 1), 0, y, -a.pin_len, a.lead_w, a.lead_w, a.pin_len)
        m.box("PinAbove%d" % (i + 1), 0, y, a.body_h, a.lead_w, a.lead_w, a.pin_top)


def find_cli():
    env = os.environ.get("SOLIDCRAFT_CLI")
    if env and os.access(env, os.X_OK):
        return env
    base = os.environ.get("SOLIDCRAFT_HOME") or os.path.join(
        os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache"),
        "solidcraft-skill")
    cand = os.path.join(base, "bin", "solidcraft-cli")
    if os.access(cand, os.X_OK):
        return cand
    sys.exit("error: solidcraft-cli not found; run setup-solidcraft.sh or set SOLIDCRAFT_CLI")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("kind", choices=["chip", "dual", "quad", "dip", "row"])
    p.add_argument("name")
    p.add_argument("-o", "--output", required=True)
    p.add_argument("--script-only", action="store_true")
    for k in ("pins",):
        p.add_argument("--" + k, type=int)
    for k in ("pitch", "span", "row", "pad-l", "pad-w", "body-l", "body-w", "body", "body-h",
              "term-l", "lead-t", "lead-w", "standoff", "pin-len", "pin-top"):
        p.add_argument("--" + k, type=float)
    p.add_argument("--epad")
    a = p.parse_args()

    need = {"chip": ["body_l", "body_w", "body_h"],
            "dual": ["pins", "pitch", "span", "pad_l", "pad_w", "body_w", "body_l", "body_h"],
            "quad": ["pins", "pitch", "span", "pad_l", "pad_w", "body", "body_h"],
            "dip": ["pins", "body_w", "body_l", "body_h"],
            "row": ["pins", "body_h"]}[a.kind]
    missing = [k for k in need if getattr(a, k) is None]
    if missing:
        sys.exit("error: %s needs %s" % (a.kind, ", ".join("--" + k.replace("_", "-") for k in missing)))
    if a.kind in ("dual", "quad") and a.pins % (2 if a.kind == "dual" else 4):
        sys.exit("error: bad pin count for %s" % a.kind)
    if a.kind in ("dip", "row"):
        a.pitch = a.pitch or 2.54
        a.row = a.row or 7.62
    if a.kind == "dual":
        a.lead_t = a.lead_t or 0.2
    if a.kind == "quad":
        a.lead_t = a.lead_t or 0.05
    if a.kind == "dip":
        a.standoff = 0.5 if a.standoff is None else a.standoff
        a.lead_w = a.lead_w or 0.5
        a.pin_len = a.pin_len or 3.2
    if a.kind == "row":
        a.lead_w = a.lead_w or 0.64
        a.pin_len = a.pin_len or 3.0
        a.pin_top = a.pin_top or 6.0

    m = Model()
    {"chip": chip, "dual": dual, "quad": quad, "dip": dip, "row": row}[a.kind](a, m)

    out = os.path.abspath(a.output)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    script = os.path.splitext(out)[0] + ".json"
    with open(script, "w") as fh:
        json.dump(m.steps, fh, indent=1)
    if a.script_only:
        print(script)
        return
    r = subprocess.run([find_cli(), "run", script, "--out", out, "--quiet"],
                       capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(out):
        sys.exit("error: solidcraft-cli failed:\n" + (r.stderr or r.stdout)[-1500:])
    os.remove(script)
    print(out)


if __name__ == "__main__":
    main()
