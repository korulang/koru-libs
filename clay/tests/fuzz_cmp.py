#!/usr/bin/env python3
"""Differential fuzz gate comparator — one dump file, three sections.

  ==REF==   Clay oracle CmdView stream
  ==CAND==  candidate stream (must match REF)
  ==MUT==   known-wrong candidate (must NOT match REF)

Per-kind field rules (matching what consumers actually read):
  kind, ud        : exact, always
  rect            : all kinds, tol 0.001 (same binary — near-exact expected)
  color c=        : kinds 1 (RECT) and 3 (TEXT) only — other kinds read
                    union garbage in `each`, not part of the contract
  img i=          : kind 4 only
  fs f=, tx=      : kind 3 only (fs tol 0.001, tx exact)

Usage: fuzz_cmp.py <dump>
Exit 0 only if CAND matches REF *and* MUT diverges from REF."""
import re, sys

pat = re.compile(
    r"^cmd k=(\d+) ud=(-?\d+) r=([-\d.]+),([-\d.]+),([-\d.]+),([-\d.]+)"
    r" c=([-\d.]+),([-\d.]+),([-\d.]+),([-\d.]+)"
    r" i=(-?\d+) f=([-\d.]+) tx=(.*)$")

def parse(path):
    secs, cur = {}, None
    for line in open(path):
        line = line.rstrip("\n")
        if line.startswith("==") and line.endswith("=="):
            cur = line.strip("=")
            secs[cur] = []
            continue
        if cur is None:
            continue
        m = pat.match(line)
        if m:
            g = m.groups()
            secs[cur].append(dict(k=int(g[0]), ud=int(g[1]),
                                  r=[float(g[2]), float(g[3]), float(g[4]), float(g[5])],
                                  c=[float(g[6]), float(g[7]), float(g[8]), float(g[9])],
                                  i=int(g[10]), f=float(g[11]), tx=g[12]))
    return secs

def cmp_rows(a, b, label):
    fails = []
    if len(a) != len(b):
        fails.append(f"{label}: command count {len(a)} vs {len(b)}")
    for idx, (x, y) in enumerate(zip(a, b)):
        if x["k"] != y["k"]:
            fails.append(f"{label}[{idx}]: kind {x['k']} vs {y['k']}")
            continue
        if x["ud"] != y["ud"]:
            fails.append(f"{label}[{idx}]: ud {x['ud']} vs {y['ud']}")
        for j, (u, v) in enumerate(zip(x["r"], y["r"])):
            if abs(u - v) > 0.001:
                fails.append(f"{label}[{idx}]: rect[{j}] {u} vs {v} (d={u-v:+.4f})")
        if x["k"] in (1, 3):
            for j, (u, v) in enumerate(zip(x["c"], y["c"])):
                if abs(u - v) > 0.002:
                    fails.append(f"{label}[{idx}]: color[{j}] {u} vs {v} (d={u-v:+.4f})")
        if x["k"] == 4 and x["i"] != y["i"]:
            fails.append(f"{label}[{idx}]: img {x['i']} vs {y['i']}")
        if x["k"] == 3:
            if abs(x["f"] - y["f"]) > 0.001:
                fails.append(f"{label}[{idx}]: fs {x['f']} vs {y['f']}")
            if x["tx"] != y["tx"]:
                fails.append(f"{label}[{idx}]: tx '{x['tx']}' vs '{y['tx']}'")
    return fails

secs = parse(sys.argv[1])
missing = [s for s in ("REF", "CAND", "MUT") if s not in secs]
if missing:
    print(f"GATE FAIL — missing sections: {', '.join(missing)}")
    sys.exit(1)

ref, cand, mut = secs["REF"], secs["CAND"], secs["MUT"]
cand_fails = cmp_rows(ref, cand, "cand")
mut_fails = cmp_rows(ref, mut, "mut")

problems = []
if not ref:
    problems.append("REF section is empty")
if cand_fails:
    problems.append(f"CAND diverges from REF ({len(cand_fails)} divergences)")
    problems += ["  " + f for f in cand_fails[:8]]
if not mut_fails:
    problems.append("MUT is identical to REF — the gate cannot reject a known-wrong candidate")

if problems:
    print(f"GATE FAIL — ref {len(ref)} cmds")
    for p in problems:
        print("  " + p)
    sys.exit(1)
print(f"GATE PASS — CAND==REF over {len(ref)} cmds; MUT rejected with {len(mut_fails)} divergences")
sys.exit(0)
