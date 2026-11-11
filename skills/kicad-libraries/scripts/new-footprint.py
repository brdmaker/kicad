#!/usr/bin/env python3
"""Generate a KiCad footprint (.kicad_mod) for a common package family.

All dimensions are in mm and come from the part's datasheet land-pattern
drawing. Nothing here is IPC-calculated: the pad sizes and positions you pass
are used as given, so check the result against the datasheet.

Kinds
  chip    2-pad SMD (resistor, capacitor, diode)
            --pitch P --pad-w W --pad-h H --body-l L --body-w B
  dual    SMD dual row (SOIC, TSSOP, SOT-23 style rows)
            --pins N --pitch P --span S --pad-l L --pad-w W --body-w B --body-l H
  quad    SMD four sides (QFN, QFP, LQFP)
            --pins N --pitch P --span S --pad-l L --pad-w W --body B [--epad WxH]
  dip     through-hole dual row
            --pins N [--pitch 2.54] [--row 7.62] [--pad-d 1.6] [--drill 0.8]
            --body-w B --body-l H
  row     through-hole single row (pin header, screw terminal)
            --pins N [--pitch 2.54] [--pad-d 1.7] [--drill 1.0]

  span   centre-to-centre distance between opposite pad rows
  pad-l  pad size in the direction pointing away from the body
  pad-w  pad size along the row

Pin 1 is top left; numbering runs counter-clockwise (dual, quad) or top to
bottom (row). The file is written to OUTDIR/NAME.kicad_mod; OUTDIR is created
if needed and should end in .pretty.
"""

import argparse
import math
import os
import sys


def f(v):
    """Format a number without trailing zeros."""
    s = ("%.4f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def up(v, step=0.01):
    """Round up to the grid so courtyard lines stay on it."""
    return round(math.ceil(v / step - 1e-9) * step, 4)


class Fp:
    def __init__(self, name, kind, descr, tags):
        self.name, self.kind, self.descr, self.tags = name, kind, descr, tags
        self.pads, self.lines, self.polys = [], [], []
        self.ext = [0.0, 0.0]  # half extents of everything on copper and body
        self.model = None

    def grow(self, x, y, w=0.0, h=0.0):
        self.ext[0] = max(self.ext[0], abs(x) + w / 2)
        self.ext[1] = max(self.ext[1], abs(y) + h / 2)

    def pad(self, num, x, y, w, h, shape="roundrect", drill=None, smd=True):
        self.pads.append((num, x, y, w, h, shape, drill, smd))
        self.grow(x, y, w, h)

    def line(self, layer, width, x1, y1, x2, y2):
        self.lines.append((layer, width, x1, y1, x2, y2))

    def rect(self, layer, width, x1, y1, x2, y2):
        for a, b, c, d in ((x1, y1, x2, y1), (x2, y1, x2, y2), (x2, y2, x1, y2), (x1, y2, x1, y1)):
            self.line(layer, width, a, b, c, d)

    def courtyard(self, margin, body_hw, body_hh):
        hw = up(max(self.ext[0], body_hw) + margin)
        hh = up(max(self.ext[1], body_hh) + margin)
        self.rect("F.CrtYd", 0.05, -hw, -hh, hw, hh)
        return hh

    def fab_body(self, hw, hh):
        """Body outline with a chamfered pin 1 corner."""
        c = min(1.0, hw / 2, hh / 2)
        pts = [(-hw + c, -hh), (hw, -hh), (hw, hh), (-hw, hh), (-hw, -hh + c)]
        for (a, b), (c2, d) in zip(pts, pts[1:] + pts[:1]):
            self.line("F.Fab", 0.1, a, b, c2, d)

    def triangle(self, x, y, s=0.25):
        self.polys.append(("F.SilkS", [(x, y), (x - s * 1.4, y - s), (x - s * 1.4, y + s)]))

    def text(self, ref_y, val_y):
        self.ref_y, self.val_y = ref_y, val_y

    def render(self):
        o = []
        a = o.append
        smd = all(p[7] for p in self.pads)
        a('(footprint "%s"' % self.name)
        a("\t(version 20260206)")
        a('\t(generator "kicad-libraries-skill")')
        a('\t(layer "F.Cu")')
        a('\t(descr "%s")' % self.descr.replace('"', "'"))
        a('\t(tags "%s")' % self.tags)
        for key, val, y, layer in (("Reference", "REF**", self.ref_y, "F.SilkS"),
                                   ("Value", self.name, self.val_y, "F.Fab")):
            a('\t(property "%s" "%s"' % (key, val))
            a("\t\t(at 0 %s 0)" % f(y))
            a('\t\t(layer "%s")' % layer)
            a("\t\t(effects (font (size 1 1) (thickness 0.15)))")
            a("\t)")
        a("\t(attr %s)" % ("smd" if smd else "through_hole"))
        for layer, w, x1, y1, x2, y2 in self.lines:
            a("\t(fp_line (start %s %s) (end %s %s) (stroke (width %s) (type solid)) (layer \"%s\"))"
              % (f(x1), f(y1), f(x2), f(y2), f(w), layer))
        for layer, pts in self.polys:
            a("\t(fp_poly (pts %s) (stroke (width 0.12) (type solid)) (fill yes) (layer \"%s\"))"
              % (" ".join("(xy %s %s)" % (f(x), f(y)) for x, y in pts), layer))
        for num, x, y, w, h, shape, drill, is_smd in self.pads:
            if is_smd:
                kind, layers = "smd", '"F.Cu" "F.Mask" "F.Paste"'
                if shape == "rect_nopaste":
                    shape, layers = "rect", '"F.Cu" "F.Mask"'
                extra = " (roundrect_rratio 0.25)" if shape == "roundrect" else ""
                a('\t(pad "%s" smd %s (at %s %s) (size %s %s) (layers %s)%s)'
                  % (num, shape, f(x), f(y), f(w), f(h), layers, extra))
            else:
                a('\t(pad "%s" thru_hole %s (at %s %s) (size %s %s) (drill %s) (layers "*.Cu" "*.Mask"))'
                  % (num, shape, f(x), f(y), f(w), f(h), f(drill)))
        if self.model:
            a('\t(model "%s" (offset (xyz 0 0 0)) (scale (xyz 1 1 1)) (rotate (xyz 0 0 0)))' % self.model)
        a(")")
        return "\n".join(o) + "\n"


def chip(a):
    m = Fp(a.name, "chip", a.descr or "Chip, 2 pads", a.tags or "chip")
    x = a.pitch / 2
    m.pad("1", -x, 0, a.pad_w, a.pad_h)
    m.pad("2", x, 0, a.pad_w, a.pad_h)
    hw, hh = a.body_l / 2, a.body_w / 2
    m.fab_body(hw, hh)
    # silk stays clear of the pads
    sx = max(0.0, x - a.pad_w / 2 - 0.2)
    sy = max(hh, a.pad_h / 2) + 0.12
    if sx > 0.1:
        m.line("F.SilkS", 0.12, -sx, -sy, sx, -sy)
        m.line("F.SilkS", 0.12, -sx, sy, sx, sy)
    top = m.courtyard(0.25, hw, hh)
    m.text(-top - 0.8, top + 0.8)
    return m


def dual(a):
    if a.pins % 2:
        sys.exit("error: dual needs an even number of pins")
    half = a.pins // 2
    m = Fp(a.name, "dual", a.descr or "%d-pin dual row" % a.pins, a.tags or "dual")
    y0 = -(half - 1) * a.pitch / 2
    for i in range(half):
        m.pad(str(i + 1), -a.span / 2, y0 + i * a.pitch, a.pad_l, a.pad_w)
        m.pad(str(a.pins - i), a.span / 2, y0 + i * a.pitch, a.pad_l, a.pad_w)
    hw, hh = a.body_w / 2, a.body_l / 2
    m.fab_body(hw, hh)
    sy = max(hh, m.ext[1]) + 0.12
    m.line("F.SilkS", 0.12, -hw, -sy, hw, -sy)
    m.line("F.SilkS", 0.12, -hw, sy, hw, sy)
    m.triangle(-a.span / 2 - a.pad_l / 2 - 0.3, y0)
    top = m.courtyard(0.25, hw, hh)
    m.text(-top - 0.8, top + 0.8)
    return m


def quad(a):
    if a.pins % 4:
        sys.exit("error: quad needs a pin count that is a multiple of 4")
    n = a.pins // 4
    m = Fp(a.name, "quad", a.descr or "%d-pin quad" % a.pins, a.tags or "quad")
    p0 = -(n - 1) * a.pitch / 2
    s = a.span / 2
    for i in range(n):
        c = p0 + i * a.pitch
        m.pad(str(i + 1), -s, c, a.pad_l, a.pad_w)                 # left, top to bottom
        m.pad(str(n + i + 1), c, s, a.pad_w, a.pad_l)              # bottom, left to right
        m.pad(str(3 * n - i), s, c, a.pad_l, a.pad_w)              # right, bottom to top
        m.pad(str(4 * n - i), c, -s, a.pad_w, a.pad_l)             # top, right to left
    if a.epad:
        ew, eh = (float(v) for v in a.epad.lower().split("x"))
        m.pad(str(a.pins + 1), 0, 0, ew, eh, shape="rect")
    hw = a.body / 2
    m.fab_body(hw, hw)
    c = hw + 0.11
    g = (n - 1) * a.pitch / 2 + a.pad_w / 2 + 0.2
    if g < c - 0.3:
        for sx in (-1, 1):
            for sy in (-1, 1):
                m.line("F.SilkS", 0.12, sx * c, sy * c, sx * g, sy * c)
                m.line("F.SilkS", 0.12, sx * c, sy * c, sx * c, sy * g)
    m.triangle(-s - a.pad_l / 2 - 0.3, p0)
    top = m.courtyard(0.25, hw, hw)
    m.text(-top - 0.8, top + 0.8)
    return m


def tht(a, rows):
    m = Fp(a.name, "tht", a.descr or "%d-pin through hole" % a.pins, a.tags or "THT")
    d = a.pad_d
    if rows == 2:
        if a.pins % 2:
            sys.exit("error: dip needs an even number of pins")
        half = a.pins // 2
        for i in range(half):
            shape = "rect" if i == 0 else "circle"
            m.pad(str(i + 1), 0, i * a.pitch, d, d, shape, a.drill, False)
            m.pad(str(a.pins - i), a.row, i * a.pitch, d, d, "circle", a.drill, False)
        # centre the footprint on the pad field
        cx, cy = a.row / 2, (half - 1) * a.pitch / 2
        m.pads = [(n, x - cx, y - cy, w, h, s, dr, sm) for n, x, y, w, h, s, dr, sm in m.pads]
        m.ext = [0.0, 0.0]
        for n, x, y, w, h, s, dr, sm in m.pads:
            m.grow(x, y, w, h)
        hw, hh = a.body_w / 2, a.body_l / 2
        m.fab_body(hw, hh)
        # silk stays clear of the pad rows
        sw = min(hw, a.row / 2 - d / 2 - 0.2)
        m.rect("F.SilkS", 0.12, -sw, -hh - 0.12, sw, hh + 0.12)
    else:
        half = a.pins
        cy = (a.pins - 1) * a.pitch / 2
        for i in range(a.pins):
            m.pad(str(i + 1), 0, i * a.pitch - cy, d, d, "rect" if i == 0 else "circle", a.drill, False)
        hw, hh = a.pitch / 2 + 0.0, a.pins * a.pitch / 2
        m.fab_body(hw, hh)
        m.rect("F.SilkS", 0.12, -hw - 0.12, -hh - 0.12, hw + 0.12, hh + 0.12)
    top = m.courtyard(0.5, hw, hh)
    m.text(-top - 0.8, top + 0.8)
    return m


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("kind", choices=["chip", "dual", "quad", "dip", "row"])
    p.add_argument("name", help="footprint name, also the file name")
    p.add_argument("-o", "--outdir", required=True, help="library directory (NAME.pretty)")
    p.add_argument("--pins", type=int)
    p.add_argument("--pitch", type=float)
    p.add_argument("--span", type=float)
    p.add_argument("--row", type=float, default=7.62)
    p.add_argument("--pad-l", type=float)
    p.add_argument("--pad-w", type=float)
    p.add_argument("--pad-h", type=float)
    p.add_argument("--pad-d", type=float)
    p.add_argument("--drill", type=float)
    p.add_argument("--body-l", type=float)
    p.add_argument("--body-w", type=float)
    p.add_argument("--body", type=float)
    p.add_argument("--epad", help="thermal pad size WxH (quad)")
    p.add_argument("--descr")
    p.add_argument("--tags")
    p.add_argument("--model", help='3D model path, e.g. "${KIPRJMOD}/3dshapes/NAME.step"')
    a = p.parse_args()

    need = {"chip": ["pitch", "pad_w", "pad_h", "body_l", "body_w"],
            "dual": ["pins", "pitch", "span", "pad_l", "pad_w", "body_w", "body_l"],
            "quad": ["pins", "pitch", "span", "pad_l", "pad_w", "body"],
            "dip": ["pins", "body_w", "body_l"],
            "row": ["pins"]}[a.kind]
    missing = [k for k in need if getattr(a, k) is None]
    if missing:
        sys.exit("error: %s needs %s" % (a.kind, ", ".join("--" + k.replace("_", "-") for k in missing)))
    if a.kind in ("dip", "row"):
        a.pitch = a.pitch or 2.54
        a.pad_d = a.pad_d or (1.6 if a.kind == "dip" else 1.7)
        a.drill = a.drill or (0.8 if a.kind == "dip" else 1.0)

    fp = {"chip": chip, "dual": dual, "quad": quad,
          "dip": lambda x: tht(x, 2), "row": lambda x: tht(x, 1)}[a.kind](a)
    fp.model = a.model
    os.makedirs(a.outdir, exist_ok=True)
    path = os.path.join(a.outdir, a.name + ".kicad_mod")
    with open(path, "w") as fh:
        fh.write(fp.render())
    print(path)


if __name__ == "__main__":
    main()
