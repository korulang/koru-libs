#!/usr/bin/env python3
"""Gate comparator: koru instance dump vs nanoui reference dump.
Same workload = same painted instance stream. Position tolerance 0.005pt
(f32-vs-f64 sin/layout rounding), color tolerance 0.002 (printed .4f).
Usage: boxes_gate_cmp.py <reference> <candidate>"""
import re, sys

def parse(path):
    rows = []
    pat = re.compile(r"^(\d+) kind=(\d+) rect=([-\d.]+),([-\d.]+),([-\d.]+),([-\d.]+) r=([-\d.]+) c=([-\d.]+),([-\d.]+),([-\d.]+),([-\d.]+)")
    for line in open(path):
        m = pat.match(line.strip())
        if m:
            g = m.groups()
            rows.append(dict(idx=int(g[0]), kind=int(g[1]),
                             rect=[float(g[2]), float(g[3]), float(g[4]), float(g[5])],
                             radius=float(g[6]),
                             color=[float(g[7]), float(g[8]), float(g[9]), float(g[10])]))
    return rows

ref, cand = parse(sys.argv[1]), parse(sys.argv[2])
fails = []
if len(ref) != len(cand):
    fails.append(f"instance count: ref {len(ref)} vs cand {len(cand)}")
for a, b in zip(ref, cand):
    if a["idx"] != b["idx"] or a["kind"] != b["kind"]:
        fails.append(f"line {a['idx']}: kind/order mismatch {a['kind']} vs {b['kind']}")
        continue
    for k, name in ((a["rect"], "rect"), (a["color"], "color")):
        for j, (x, y) in enumerate(zip(k, b[name])):
            tol = 0.005 if name == "rect" else 0.002
            if abs(x - y) > tol:
                fails.append(f"inst {a['idx']}: {name}[{j}] {x} vs {y} (d={x-y:+.4f})")
    if abs(a["radius"] - b["radius"]) > 0.01:
        fails.append(f"inst {a['idx']}: radius {a['radius']} vs {b['radius']}")

shown = fails[:10]
print(f"GATE {'PASS' if not fails else 'FAIL'} — {len(cand)} instances vs {len(ref)} ref, {len(fails)} divergences")
for f in shown:
    print("  " + f)
sys.exit(0 if not fails else 1)
