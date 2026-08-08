// Read a timing run without letting a busy machine tell you a story.
//
// WHY THIS EXISTS. On 2026-08-08 a fifteen-iteration median said batching rows
// into one page insertion was worth 5% on the ten-thousand-row build. It was
// worth nothing. Under load the samples do not scatter around a true value —
// they fall into TWO clusters, one near 340 ms and one near 800, with nothing
// in between, because a run either gets a fast core for its whole duration or
// it does not. The median then reports how many fast samples a framework
// happened to catch. In that run: one for the reference, four for the old
// build, nine for the new one. The ranking was scheduling luck and it looked
// like a clean win, which is the dangerous part — a contaminated median does
// not look noisy.
//
// Two rules, both mechanical:
//
//   1. READ THE FAST CLUSTER, not the median. Interference only ever ADDS
//      time, so the fast mode is the machine's uncontended behaviour and the
//      only part that says anything about the program.
//
//   2. THE CONTROL GATES THE WINDOW. The reference is the one program
//      guaranteed not to have changed between runs. If its fast cluster is not
//      where the reference is known to live, the window is not measuring what
//      you think and NOTHING in it may be ranked. This is the check that was
//      available and unread.
//
// The fast-cluster reader and the same-window gate now live in window.mjs, so
// that this file and ladder.mjs cannot drift into two different standards of
// proof. The rules and their reasons are unchanged; the comments moved with
// the code.
//
// Usage:
//   node read-timings.mjs --results <dir> --benchmark 07_create10k \
//        --control vanillajs --expect 311 [--tolerance 0.15] \
//        --framework korurp --framework korubatch

import { report as reportOne, windowFault } from "./window.mjs";

const argv = process.argv.slice(2);
function opt(name, fallback) {
    const i = argv.indexOf(`--${name}`);
    return i === -1 ? fallback : argv[i + 1];
}
function optAll(name) {
    return argv.reduce((acc, a, i) => (a === `--${name}` ? [...acc, argv[i + 1]] : acc), []);
}

const resultsDir = opt("results");
const benchmark = opt("benchmark");
const control = opt("control", "vanillajs");
const expect = Number(opt("expect", "NaN"));
const tolerance = Number(opt("tolerance", "0.15"));
const frameworks = optAll("framework");

if (!resultsDir || !benchmark) {
    console.error("read-timings: --results <dir> and --benchmark <name> are required.");
    process.exit(2);
}

function assertOneWindow(rows) {
    const fault = windowFault(rows);
    if (fault === null) return;
    console.log("");
    for (const line of fault.lines) console.log(`  ${line}`);
    process.exit(1);
}

const report = (framework) => reportOne(resultsDir, framework, benchmark);

const controlRow = report(control);
if (controlRow === null) {
    console.error(`read-timings: no samples for the control '${control}' — nothing can be ranked.`);
    process.exit(2);
}

const rows = [controlRow, ...frameworks.map(report).filter(Boolean)];
assertOneWindow(rows);

console.log(`\n${benchmark}  —  fast cluster vs naive median\n`);
console.log(
    "  " +
        "framework".padEnd(14) +
        "fast".padStart(8) +
        "naive".padStart(9) +
        "  kept".padStart(9) +
        "  split".padStart(9) +
        "   vs control".padStart(14),
);
for (const r of rows) {
    const rel = r.fastMedian / controlRow.fastMedian;
    console.log(
        "  " +
            r.framework.padEnd(14) +
            r.fastMedian.toFixed(1).padStart(8) +
            r.naiveMedian.toFixed(1).padStart(9) +
            `${r.fastN}/${r.n}`.padStart(9) +
            (r.split ? `${r.ratio.toFixed(2)}x` : "none").padStart(9) +
            (r === controlRow ? "—" : `x${rel.toFixed(3)}`).padStart(14),
    );
}

// The gate. A window whose control has drifted cannot rank anything, and the
// naive median is exactly where that drift hides — so the check is run against
// the fast cluster, which is the number a quiet machine would have produced.
console.log("");
if (Number.isNaN(expect)) {
    console.log(`  NO CONTROL EXPECTATION GIVEN (--expect). The ratios above are unverified —`);
    console.log(`  pass the value '${control}' is known to measure on this machine.`);
    process.exit(0);
}

const drift = Math.abs(controlRow.fastMedian - expect) / expect;
if (drift > tolerance) {
    console.log(
        `  REFUSING TO RANK — the control '${control}' measured ${controlRow.fastMedian.toFixed(1)} where it is`,
    );
    console.log(
        `  known to measure ${expect} (${(drift * 100).toFixed(0)}% off, tolerance ${(tolerance * 100).toFixed(0)}%).`,
    );
    console.log("");
    console.log("  The control is the one program guaranteed not to have changed. If it moved,");
    console.log("  the window moved, and every ratio above is a measurement of the machine.");
    console.log("  Re-run; do not write any of this down.");
    process.exit(1);
}

console.log(
    `  control '${control}' at ${controlRow.fastMedian.toFixed(1)} vs known ${expect} ` +
        `(${(drift * 100).toFixed(0)}% off) — window accepted.`,
);
const contaminated = rows.filter((r) => r.split);
if (contaminated.length > 0) {
    console.log(
        `  note: ${contaminated.length}/${rows.length} frameworks showed a split; ` +
            `their naive medians are NOT comparable.`,
    );
}
