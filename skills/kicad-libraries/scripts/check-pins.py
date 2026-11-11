#!/usr/bin/env python3
"""Check that a symbol's pins match a footprint's pads.

Usage: check-pins.py SYMBOL_LIB.kicad_sym SYMBOL_NAME FOOTPRINT.kicad_mod

Compares pin numbers with pad numbers and reports pins without a pad and pads
without a pin. Mounting or shield pads with an empty number are ignored, and so
are symbol pins of type no_connect (a pad is optional for those). Exit status 0
when they match, 1 when they differ, 2 on a usage or parse problem.

This catches wiring mistakes between the two files. It cannot tell whether the
pin numbering matches the datasheet; compare that yourself.
"""

import re
import sys


def block(text, start):
    """Return the balanced (...) text starting at index start."""
    depth, in_str, i = 0, False, start
    while i < len(text):
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
        elif c == ")":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
        i += 1
    return None


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    lib, name, fp = sys.argv[1:]
    text = open(lib).read()
    m = re.search(r'^\t\(symbol "%s"' % re.escape(name), text, re.M)
    if not m:
        print("error: symbol %r not found in %s" % (name, lib), file=sys.stderr)
        sys.exit(2)
    sym = block(text, m.start() + 1)
    if sym is None:
        print("error: could not parse symbol %r" % name, file=sys.stderr)
        sys.exit(2)

    pins = {}
    for pm in re.finditer(r"\(pin (\w+) \w+", sym):
        pin = block(sym, pm.start())
        num = re.search(r'\(number "((?:[^"\\]|\\.)*)"', pin)
        if num:
            pins[num.group(1)] = pm.group(1)
    pads = set(re.findall(r'\(pad "([^"]+)"', open(fp).read()))

    sym_nums = {n for n, t in pins.items() if t != "no_connect"}
    only_pin = sorted(sym_nums - pads, key=lambda s: (len(s), s))
    only_pad = sorted(pads - set(pins), key=lambda s: (len(s), s))
    print("symbol %s: %d pins; footprint: %d pads" % (name, len(pins), len(pads)))
    if only_pin:
        print("pins with no pad: %s" % ", ".join(only_pin))
    if only_pad:
        print("pads with no pin: %s" % ", ".join(only_pad))
    if only_pin or only_pad:
        sys.exit(1)
    print("ok: every pin has a pad and every pad has a pin")


if __name__ == "__main__":
    main()
