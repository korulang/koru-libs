// Print the ladder: every framework measured against hand-written vanilla, from
// one directory of results.
//
// WHY THIS EXISTS. For four sessions the only reference we ever timed was
// vanilla JavaScript, and every comparison against Solid or Svelte was made
// against numbers published from someone else's machine — which is not a
// comparison, it is a hedge with a table in it. The reason was not principle:
// vanilla is plain source and runs straight out of the checkout, while every
// real framework needs installing and building first. So the one reference that
// required no work was the only one we had, and a caveat got written around the
// gap instead of the gap getting closed. Closing it took twenty minutes.
//
// Reads the same shape read-timings.mjs does — the fast cluster, never the
// median, because on a machine that is not quiet a median ranks scheduling luck.
// See read-timings.mjs for why that is not a stylistic preference.
//
//   node ladder.mjs --results <dir> [--base vanillajs-keyed]
//
// Framework directory names carry versions (`solid-v1.9.3-keyed`), so the
// column labels are derived rather than hardcoded: whatever versions are in the
// directory are the versions in the table, and a stale label cannot survive a
// re-run.

import fs from "node:fs";
import path from "node:path";

const argv = process.argv.slice(2);
const opt = (n, d) => {
    const i = argv.indexOf(`--${n}`);
    return i === -1 ? d : argv[i + 1];
};

const dir = opt("results");
const base = opt("base", "vanillajs-keyed");
if (!dir) {
    console.error("ladder: --results <dir> is required.");
    process.exit(2);
}

const BENCHMARKS = [
    ["01_run1k", "build 1,000 rows"],
    ["02_replace1k", "replace all rows"],
    ["03_update10th1k_x16", "update every 10th"],
    ["04_select1k", "select a row"],
    ["05_swap1k", "swap two rows"],
    ["06_remove-one-1k", "remove one row"],
    ["07_create10k", "build 10,000 rows"],
    ["08_create1k-after1k_x2", "build 1,000 more"],
    ["09_clear1k_x8", "clear 1,000 rows"],
];

// Same split rule as read-timings.mjs: the widest RELATIVE gap above 1.25x
// separates the uncontended cluster from the contended one. No gap → one
// cluster → the whole set is the answer.
const SPLIT = 1.25;
function fast(file) {
    if (!fs.existsSync(file)) return null;
    const xs = JSON.parse(fs.readFileSync(file, "utf8")).values.total.values.slice().sort((a, b) => a - b);
    let cut = -1;
    let widest = SPLIT;
    for (let i = 0; i < xs.length - 1; i++) {
        const r = xs[i + 1] / xs[i];
        if (r > widest) {
            widest = r;
            cut = i;
        }
    }
    const k = cut === -1 ? xs : xs.slice(0, cut + 1);
    const m = Math.floor(k.length / 2);
    return { v: k.length % 2 ? k[m] : (k[m - 1] + k[m]) / 2, kept: k.length, n: xs.length };
}

// Whoever is in the directory is in the table.
const frameworks = [
    ...new Set(
        fs
            .readdirSync(dir)
            .filter((f) => f.endsWith("_01_run1k.json"))
            .map((f) => f.replace("_01_run1k.json", "")),
    ),
];
if (!frameworks.includes(base)) {
    console.error(`ladder: the base '${base}' has no results in ${dir} — nothing to compare against.`);
    process.exit(1);
}

const label = (f) => f.replace(/-keyed$/, "").replace(/-v[\d.]+$/, "");
const rows = [];
const geo = Object.fromEntries(frameworks.map((f) => [f, 1]));
const thin = [];

for (const [b, name] of BENCHMARKS) {
    const baseline = fast(path.join(dir, `${base}_${b}.json`));
    if (!baseline) continue;
    // A column that survived very few samples is a real measurement of a busy
    // moment, not of the program. Say so rather than printing it plain.
    if (baseline.kept <= 2) thin.push(`${name} (base kept ${baseline.kept}/${baseline.n})`);
    const row = { name, absolute: baseline.v, cells: {} };
    for (const f of frameworks) {
        const r = fast(path.join(dir, `${f}_${b}.json`));
        if (!r) continue;
        row.cells[f] = r.v / baseline.v;
        geo[f] *= r.v / baseline.v;
    }
    rows.push(row);
}

const ordered = [base, ...frameworks.filter((f) => f !== base).sort((a, b) => geo[a] - geo[b])];

let head = "operation".padEnd(20) + "base ms".padStart(9);
for (const f of ordered) head += label(f).padStart(12);
console.log("\n" + head);
for (const r of rows) {
    let line = r.name.padEnd(20) + r.absolute.toFixed(1).padStart(9);
    for (const f of ordered) line += (r.cells[f] === undefined ? "--" : r.cells[f].toFixed(3)).padStart(12);
    console.log(line);
}
let g = "GEOMEAN".padEnd(20) + "".padStart(9);
for (const f of ordered) g += Math.pow(geo[f], 1 / rows.length).toFixed(3).padStart(12);
console.log("\n" + g + "\n");

if (thin.length) {
    console.log("THIN — the baseline kept almost no samples here, so read these rows as a busy");
    console.log("moment rather than as the program:");
    for (const t of thin) console.log("  " + t);
    console.log("");
}
