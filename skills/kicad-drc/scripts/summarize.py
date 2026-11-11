#!/usr/bin/env python3
"""Summarise a kicad-cli DRC or ERC JSON report.

Usage: summarize.py {drc|erc} REPORT.json [-n EXAMPLES]

Prints counts by severity and type, a few examples per type, and exits 1 when
there are errors, 0 otherwise. Library-setup findings (a footprint library the
configuration does not list) are counted separately because they come from the
environment, not the design.
"""

import json
import sys
from collections import defaultdict

LIB_SETUP = {"lib_footprint_issues", "footprint_link_issues", "lib_symbol_issues"}


def items(v):
    out = []
    for it in v.get("items", []):
        pos = it.get("pos")
        where = " @ (%.2f, %.2f)" % (pos["x"], pos["y"]) if pos else ""
        out.append(it.get("description", "?") + where)
    return out


def main():
    args = sys.argv[1:]
    if len(args) < 2 or args[0] not in ("drc", "erc"):
        sys.exit(__doc__)
    kind, path = args[0], args[1]
    n_ex = int(args[args.index("-n") + 1]) if "-n" in args else 3
    d = json.load(open(path))

    viol = list(d.get("violations", []))
    for s in d.get("sheets", []):
        for v in s.get("violations", []):
            v = dict(v)
            v["_sheet"] = s.get("path", "/")
            viol.append(v)
    extra = {"unconnected": d.get("unconnected_items", []), "parity": d.get("schematic_parity", [])}

    by = defaultdict(list)
    for v in viol:
        by[(v["severity"], v["type"])].append(v)

    sev = defaultdict(int)
    for (s, _), vs in by.items():
        sev[s] += len(vs)
    n_unc, n_par = len(extra["unconnected"]), len(extra["parity"])

    print("== %s  %s  (kicad %s)" % (kind.upper(), d.get("source", "?"), d.get("kicad_version", "?")))
    print("errors: %d  warnings: %d  unconnected: %d  schematic parity: %d"
          % (sev["error"], sev["warning"], n_unc, n_par))

    order = {"error": 0, "warning": 1}
    for (s, t), vs in sorted(by.items(), key=lambda kv: (order.get(kv[0][0], 2), -len(kv[1]), kv[0][1])):
        tag = "  [library setup]" if t in LIB_SETUP else ""
        print("\n%-8s %s  x%d%s" % (s, t, len(vs), tag))
        for v in vs[:n_ex]:
            sheet = " (sheet %s)" % v["_sheet"] if "_sheet" in v else ""
            print("    - %s%s" % (v["description"], sheet))
            for line in items(v)[:3]:
                print("        %s" % line)
        if len(vs) > n_ex:
            print("    ... %d more" % (len(vs) - n_ex))
    for label, lst in (("unconnected items", extra["unconnected"]), ("schematic parity", extra["parity"])):
        if lst:
            print("\n%s  x%d" % (label, len(lst)))
            for v in lst[:n_ex]:
                print("    - %s" % v.get("description", "?"))
                for line in items(v)[:3]:
                    print("        %s" % line)

    lib = sum(len(vs) for (s, t), vs in by.items() if t in LIB_SETUP)
    if lib:
        print("\nnote: %d finding(s) are library setup, not design problems. If the standard "
              "libraries should be available, run the kicad-cli skill's scripts/install-libs.sh." % lib)
    sys.exit(1 if sev["error"] or n_unc else 0)


if __name__ == "__main__":
    main()
