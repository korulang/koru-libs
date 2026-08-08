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
// See read-timings.mjs for why that is not a stylistic preference. Both files
// now take that reader, and the same-window gate, from window.mjs: a second
// implementation of a measurement gate is a second standard of proof, and the
// lenient one always wins.
//
//   node ladder.mjs --results <dir> [--base vanillajs] [--twin vanillajstwin]
//
// Framework directory names carry versions (`solid-v1.9.3-keyed`), so the
// column labels are derived rather than hardcoded: whatever versions are in the
// directory are the versions in the table, and a stale label cannot survive a
// re-run.
//
// THE TWIN CONTROL, added 2026-08-08 after the 25-iteration run.
//
// Gating a window by comparing the control against a value it is KNOWN to
// measure is weak here, because the control's own absolute time drifts between
// sessions by more than the effects being measured: on this machine vanilla's
// partial update read 16.7 ms in one session and 23.2 ms in the next, a 39%
// move in a program that did not change by one byte. Gate on that and you
// either reject every honest window or accept a dirty one.
//
// So the control is measured TWICE IN THE SAME RUN, as two directory entries
// holding byte-identical code served from two URLs. Nothing can make those two
// differ except the machine. If they agree the window was quiet while it ran;
// if they disagree, no ratio in it means anything — and that verdict needs no
// memory of another afternoon to be trustworthy.

import fs from "node:fs";
import { report, windowFault } from "./window.mjs";

const argv = process.argv.slice(2);
const opt = (n, d) => {
    const i = argv.indexOf(`--${n}`);
    return i === -1 ? d : argv[i + 1];
};

const dir = opt("results");
const base = opt("base", "vanillajs");
const twin = opt("twin");
const twinTolerance = Number(opt("twin-tolerance", "0.10"));
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

// Whoever is in the directory is in the table. window.mjs appends the `-keyed`
// the reference puts in every filename, so it comes off here.
const frameworks = [
    ...new Set(
        fs
            .readdirSync(dir)
            .filter((f) => f.endsWith("_01_run1k.json"))
            .map((f) => f.replace("-keyed_01_run1k.json", "")),
    ),
];
if (!frameworks.includes(base)) {
    console.error(`ladder: the base '${base}' has no results in ${dir} — nothing to compare against.`);
    process.exit(1);
}
if (twin && !frameworks.includes(twin)) {
    console.error(`ladder: the twin '${twin}' has no results in ${dir}.`);
    process.exit(1);
}

const label = (f) => f.replace(/-v[\d.]+$/, "");

// AN OPERATION A FRAMEWORK DID NOT COMPLETE IS NOT AN OPERATION IT SKIPPED.
//
// The reference aborts a whole framework/benchmark cell when its own
// correctness assertion fails mid-run, and leaves no file behind. Read that as
// "no data here" and the geomean quietly becomes a product over eight
// operations for one column and nine for the others — which does not compare
// two frameworks, and flatters exactly the column that failed. So a benchmark
// any column did not complete is dropped from EVERY column's geomean and named
// at the bottom of the table as a non-result.
const ranked = [];
const dropped = [];
for (const [b, name] of BENCHMARKS) {
    const cells = Object.fromEntries(frameworks.map((f) => [f, report(dir, f, b)]));
    const absent = frameworks.filter((f) => cells[f] === null);
    if (absent.length > 0) {
        dropped.push({ b, name, absent, cells });
        continue;
    }
    const fault = windowFault(frameworks.map((f) => cells[f]));
    if (fault !== null) {
        console.log("");
        console.log(`  on ${name} (${b}):`);
        for (const line of fault.lines) console.log(`  ${line}`);
        process.exit(1);
    }
    ranked.push({ b, name, cells });
}
if (ranked.length === 0) {
    console.error("ladder: no operation was completed by every framework — nothing to rank.");
    process.exit(1);
}

const geo = Object.fromEntries(frameworks.map((f) => [f, 1]));
const thin = [];
const rows = [];
for (const { name, cells } of ranked) {
    const baseline = cells[base];
    // A column that survived very few samples is a real measurement of a busy
    // moment, not of the program. Say so rather than printing it plain.
    if (baseline.fastN <= 2) thin.push(`${name} (base kept ${baseline.fastN}/${baseline.n})`);
    const row = { name, absolute: baseline.fastMedian, cells: {} };
    for (const f of frameworks) {
        const ratio = cells[f].fastMedian / baseline.fastMedian;
        row.cells[f] = ratio;
        geo[f] *= ratio;
    }
    rows.push(row);
}

const ordered = [base, ...frameworks.filter((f) => f !== base).sort((a, b) => geo[a] - geo[b])];
const counts = [...new Set(ranked.flatMap(({ cells }) => frameworks.map((f) => cells[f].n)))].sort((a, b) => a - b);
const every = ranked.flatMap(({ cells }) => frameworks.map((f) => cells[f]));
const span = (Math.max(...every.map((r) => r.mtime)) - Math.min(...every.map((r) => r.mtime))) / 60000;

console.log("");
console.log(
    `${dir} — ${counts.length === 1 ? counts[0] : `${counts[0]}–${counts[counts.length - 1]}`} iterations per cell, ` +
        `every file written inside ${span.toFixed(0)} minutes`,
);

let head = "\noperation".padEnd(21) + "base ms".padStart(9);
for (const f of ordered) head += label(f).padStart(12);
console.log(head);
for (const r of rows) {
    let line = r.name.padEnd(20) + r.absolute.toFixed(1).padStart(9);
    for (const f of ordered) line += r.cells[f].toFixed(3).padStart(12);
    console.log(line);
}
let g = "GEOMEAN".padEnd(20) + `of ${rows.length}`.padStart(9);
for (const f of ordered) g += Math.pow(geo[f], 1 / rows.length).toFixed(3).padStart(12);
console.log("\n" + g + "\n");

let kept = "samples kept".padEnd(20) + "".padStart(9);
for (const f of ordered) {
    const worst = ranked.reduce((a, { cells }) => Math.min(a, cells[f].fastN / cells[f].n), 1);
    kept += `${(worst * 100).toFixed(0)}% worst`.padStart(12);
}
console.log(kept + "\n");

if (dropped.length) {
    console.log("NOT RANKED — no framework is scored on these, because at least one of them did");
    console.log("not complete the operation. The reference abandons a cell when its own");
    console.log("correctness assertion fails, and a missing cell is a failure, never a zero:");
    for (const d of dropped) {
        console.log(`  ${d.name} (${d.b}) — no result for: ${d.absent.map(label).join(", ")}`);
    }
    console.log("");
}

if (thin.length) {
    console.log("THIN — the baseline kept almost no samples here, so read these rows as a busy");
    console.log("moment rather than as the program:");
    for (const t of thin) console.log("  " + t);
    console.log("");
}

if (!twin) {
    console.log("NO TWIN CONTROL (--twin). Nothing in this run proves the machine held still");
    console.log("while it ran, so the ratios above are unverified. Measure a byte-identical");
    console.log("copy of the base as a second framework directory in the same run.");
    process.exit(0);
}

const deltas = ranked.map(({ name, cells }) => ({
    name,
    a: cells[base].fastMedian,
    b: cells[twin].fastMedian,
    rel: Math.abs(cells[twin].fastMedian - cells[base].fastMedian) / cells[base].fastMedian,
}));
const worst = deltas.reduce((a, b) => (b.rel > a.rel ? b : a));
console.log(`TWIN CONTROL '${label(twin)}' — byte-identical to '${label(base)}', measured in the same run`);
for (const d of deltas) {
    console.log(
        `  ${d.name.padEnd(20)}${d.a.toFixed(1).padStart(9)}${d.b.toFixed(1).padStart(9)}   ` +
            `${(d.rel * 100).toFixed(1)}%${d.rel > twinTolerance ? "   OVER" : ""}`,
    );
}
console.log("");
if (deltas.some((d) => d.rel > twinTolerance)) {
    console.log(
        `REFUSING TO RANK — the same program measured twice in this run disagreed with itself by` +
            ` up to ${(worst.rel * 100).toFixed(0)}% (${worst.name}), tolerance ` +
            `${(twinTolerance * 100).toFixed(0)}%.`,
    );
    console.log("Nothing but the machine can make those two numbers differ. It was not quiet.");
    console.log("Re-run; do not write any of this down.");
    process.exit(1);
}
console.log(
    `Window accepted: the control measured twice agreed to within ${(worst.rel * 100).toFixed(1)}% ` +
        `(worst: ${worst.name}), tolerance ${(twinTolerance * 100).toFixed(0)}%.`,
);
