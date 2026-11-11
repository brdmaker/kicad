#!/usr/bin/env python3
"""Generate a KiCad schematic symbol from a pin table and add it to a library.

Usage: new-symbol.py NAME --pins PINS.csv -o LIB.kicad_sym [options]

The pin table is CSV (header optional) or JSON, one row per pin:

    number,name,type[,side]

  type  input output bidirectional tri_state passive free unspecified
        power_in power_out open_collector open_emitter no_connect
  side  left right top bottom. Optional; when missing it follows the type:
        input and passive go left, output, bidirectional and the rest right,
        power_in on a ground-like name (GND, VSS, ...) goes bottom, other
        power_in and power_out go top.

JSON form: [{"number": "1", "name": "IN", "type": "input", "side": "left"}, ...]

Pin names written ~{RESET} get an overbar. The symbol is one rectangle with
pins on the 2.54 mm grid. If LIB exists, a symbol of the same name is replaced
and others are kept; otherwise LIB is created.
"""

import argparse
import csv
import json
import math
import os
import re
import sys

TYPES = {"input", "output", "bidirectional", "tri_state", "passive", "free", "unspecified",
         "power_in", "power_out", "open_collector", "open_emitter", "no_connect"}
GROUND = re.compile(r"^((A|D|P|S)?(GND|VSS|VEE|EP|PAD)|V-|-V|VMINUS)", re.I)
GRID = 2.54
PIN_LEN = 2.54
CHAR = 1.0  # mm per character of 1.27 mm text, a little generous


def q(s):
    return '"%s"' % str(s).replace("\\", "\\\\").replace('"', '\\"')


def f(v):
    s = ("%.4f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def read_pins(path):
    if path.lower().endswith(".json"):
        rows = json.load(open(path))
        return [(str(r["number"]), str(r["name"]), r["type"], r.get("side")) for r in rows]
    rows = [r for r in csv.reader(open(path, newline="")) if r and any(c.strip() for c in r)]
    if rows and rows[0][0].strip().lower() in ("number", "pin", "no", "#"):
        rows = rows[1:]
    out = []
    for r in rows:
        r = [c.strip() for c in r]
        if len(r) < 3:
            sys.exit("error: pin row needs number,name,type: %r" % r)
        out.append((r[0], r[1], r[2], r[3] if len(r) > 3 and r[3] else None))
    return out


def side_for(name, typ):
    if typ == "power_in":
        return "bottom" if GROUND.match(name) else "top"
    if typ == "power_out":
        return "top"
    if typ in ("input", "passive"):
        return "left"
    return "right"


def vis_len(name):
    """Printed length: ~{X} shows as X."""
    return len(re.sub(r"~\{([^}]*)\}", r"\1", name))


def build(name, pins, ref, value, footprint, datasheet, descr, keywords, fp_filters):
    sides = {"left": [], "right": [], "top": [], "bottom": []}
    seen = set()
    for num, pname, typ, side in pins:
        if typ not in TYPES:
            sys.exit("error: pin %s has unknown type %r" % (num, typ))
        if (num in seen) and typ != "no_connect":
            sys.exit("error: duplicate pin number %s" % num)
        seen.add(num)
        side = side or side_for(pname, typ)
        if side not in sides:
            sys.exit("error: pin %s has unknown side %r" % (num, side))
        sides[side].append((num, pname, typ))

    ln = max([vis_len(p[1]) for p in sides["left"]] or [0])
    rn = max([vis_len(p[1]) for p in sides["right"]] or [0])
    tn = max([vis_len(p[1]) for p in sides["top"]] or [0])
    bn = max([vis_len(p[1]) for p in sides["bottom"]] or [0])
    rows = max(len(sides["left"]), len(sides["right"]))
    cols = max(len(sides["top"]), len(sides["bottom"]))

    # Side pins start below the names of the top pins (which run down into the
    # body) and end above those of the bottom pins, so the texts never overlap.
    top_off = math.ceil((tn * CHAR + 1.27) / GRID - 1e-9) * GRID if sides["top"] else GRID
    bot_off = math.ceil((bn * CHAR + 1.27) / GRID - 1e-9) * GRID if sides["bottom"] else GRID

    width = max(10.16, (ln + rn) * CHAR + GRID * 2, (cols + 1) * GRID)
    height = max(top_off + max(rows - 1, 0) * GRID + bot_off, 5.08)
    width = math.ceil(width / GRID - 1e-9) * GRID
    height = math.ceil(height / GRID - 1e-9) * GRID
    hw, hh = width / 2, height / 2

    pin_s = []

    def pin(typ, x, y, ang, num, pname):
        pin_s.append(
            "\t\t\t(pin %s line (at %s %s %d) (length %s) (name %s (effects (font (size 1.27 1.27)))) "
            "(number %s (effects (font (size 1.27 1.27)))))"
            % (typ, f(x), f(y), ang, f(PIN_LEN), q(pname), q(num)))

    for i, (num, pname, typ) in enumerate(sides["left"]):
        pin(typ, -hw - PIN_LEN, hh - top_off - GRID * i, 0, num, pname)
    for i, (num, pname, typ) in enumerate(sides["right"]):
        pin(typ, hw + PIN_LEN, hh - top_off - GRID * i, 180, num, pname)
    for sd, y, ang in (("top", hh + PIN_LEN, 270), ("bottom", -hh - PIN_LEN, 90)):
        n = len(sides[sd])
        for j, (num, pname, typ) in enumerate(sides[sd]):
            pin(typ, -(n - 1) * GRID / 2 + GRID * j, y, ang, num, pname)

    def prop(key, val, x, y, hide=False):
        return ("\t\t(property %s %s (at %s %s 0) (show_name no) (do_not_autoplace no)%s "
                "(effects (font (size 1.27 1.27))))"
                % (q(key), q(val), f(x), f(y), " (hide yes)" if hide else ""))

    ref_y = hh + 1.27 + (PIN_LEN + 1.27 if sides["top"] else 0)
    val_y = -hh - 1.27 - (PIN_LEN + 1.27 if sides["bottom"] else 0)
    out = ["\t(symbol %s" % q(name),
           "\t\t(exclude_from_sim no)", "\t\t(in_bom yes)", "\t\t(on_board yes)",
           "\t\t(in_pos_files yes)", "\t\t(duplicate_pin_numbers_are_jumpers no)",
           prop("Reference", ref, 0, ref_y),
           prop("Value", value or name, 0, val_y),
           prop("Footprint", footprint, 0, 0, True),
           prop("Datasheet", datasheet, 0, 0, True),
           prop("Description", descr, 0, 0, True)]
    if keywords:
        out.append(prop("ki_keywords", keywords, 0, 0, True))
    if fp_filters:
        out.append(prop("ki_fp_filters", fp_filters, 0, 0, True))
    out += ["\t\t(symbol %s" % q(name + "_0_1"),
            "\t\t\t(rectangle (start %s %s) (end %s %s) (stroke (width 0.254) (type default)) "
            "(fill (type background)))" % (f(-hw), f(hh), f(hw), f(-hh)),
            "\t\t)",
            "\t\t(symbol %s" % q(name + "_1_1")] + pin_s + ["\t\t)", "\t\t(embedded_fonts no)", "\t)"]
    return "\n".join(out) + "\n"


def top_level_blocks(text):
    """Yield (start, end, name) of each top-level (symbol "NAME" ...) in a library."""
    depth, i, n = 0, 0, len(text)
    in_str = False
    start = None
    while i < n:
        c = text[i]
        if in_str:
            if c == "\\":
                i += 1
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "(":
            depth += 1
            if depth == 2:
                m = re.match(r'\(symbol\s+"((?:[^"\\]|\\.)*)"', text[i:])
                start = (i, m.group(1)) if m else None
        elif c == ")":
            if depth == 2 and start:
                yield start[0], i + 1, start[1]
                start = None
            depth -= 1
        i += 1


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("name")
    p.add_argument("--pins", required=True, help="pin table, .csv or .json")
    p.add_argument("-o", "--output", required=True, help="library file (.kicad_sym), created if missing")
    p.add_argument("--ref", default="U", help="reference prefix (default U)")
    p.add_argument("--value")
    p.add_argument("--footprint", default="", help="Library:Footprint")
    p.add_argument("--datasheet", default="", help="URL or path, e.g. datasheets/part.pdf")
    p.add_argument("--description", default="")
    p.add_argument("--keywords", default="")
    p.add_argument("--fp-filters", default="")
    a = p.parse_args()

    pins = read_pins(a.pins)
    if not pins:
        sys.exit("error: the pin table is empty")
    sym = build(a.name, pins, a.ref, a.value, a.footprint, a.datasheet, a.description,
                a.keywords, a.fp_filters)

    header = '(kicad_symbol_lib\n\t(version 20251024)\n\t(generator "kicad-libraries-skill")\n\t(generator_version "10.0")\n'
    if os.path.exists(a.output) and os.path.getsize(a.output) > 0:
        text = open(a.output).read()
        for s, e, nm in reversed(list(top_level_blocks(text))):
            if nm == a.name:
                text = text[:s].rstrip("\t \n") + "\n" + text[e:].lstrip("\n")
        end = text.rstrip().rfind(")")
        text = text[:end].rstrip() + "\n" + sym + ")\n"
    else:
        d = os.path.dirname(a.output)
        if d:
            os.makedirs(d, exist_ok=True)
        text = header + sym + ")\n"
    with open(a.output, "w") as fh:
        fh.write(text)
    print(a.output)


if __name__ == "__main__":
    main()
