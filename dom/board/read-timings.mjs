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
// Usage:
//   node read-timings.mjs --results <dir> --benchmark 07_create10k \
//        --control vanillajs --expect 311 [--tolerance 0.15] \
//        --framework korurp --framework korubatch

import fs from "node:fs";
import path from "node:path";

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

// A run's samples, sorted, plus when the file was written. The driver leaves
// one file per framework/benchmark and OVERWRITES IN PLACE, so a directory
// always looks complete even when half of it is from a run two hours ago.
function samples(framework) {
    const file = path.join(resultsDir, `${framework}-keyed_${benchmark}.json`);
    if (!fs.existsSync(file)) return null;
    return {
        xs: JSON.parse(fs.readFileSync(file, "utf8")).values.total.values.slice().sort((a, b) => a - b),
        mtime: fs.statSync(file).mtimeMs,
    };
}

// SAME WINDOW OR NOTHING.
//
// Comparing two frameworks measured hours apart is the error this whole file
// exists to prevent, wearing different clothes — and the control check does
// NOT catch it, because a stale control file can be a perfectly good
// measurement of a different afternoon. Caught 2026-08-08 reading a fresh
// probe against two baselines from earlier runs; the tell was that the sample
// counts disagreed with what had been asked for.
//
// Two independent signals, because either alone is defeatable: iteration
// counts must match (a different --count is a different run), and the files
// must have been written close enough together to belong to one invocation.
const SAME_RUN_MINUTES = 90;
function assertOneWindow(rows) {
    const counts = [...new Set(rows.map((r) => r.n))];
    if (counts.length > 1) {
        console.log("");
        console.log("  REFUSING TO RANK — these results are from DIFFERENT RUNS.");
        console.log("  Iteration counts disagree, so they cannot be one invocation:");
        for (const r of rows) console.log(`    ${r.framework.padEnd(14)} ${r.n} samples`);
        console.log("");
        console.log("  The driver overwrites result files in place, so a stale one looks");
        console.log("  exactly like a fresh one. Re-run every framework together.");
        process.exit(1);
    }
    const span = (Math.max(...rows.map((r) => r.mtime)) - Math.min(...rows.map((r) => r.mtime))) / 60000;
    if (span > SAME_RUN_MINUTES) {
        console.log("");
        console.log(`  REFUSING TO RANK — the result files span ${span.toFixed(0)} minutes.`);
        for (const r of rows) {
            console.log(`    ${r.framework.padEnd(14)} written ${new Date(r.mtime).toTimeString().slice(0, 5)}`);
        }
        console.log("");
        console.log("  Whatever else changed between those two moments changed the machine.");
        process.exit(1);
    }
}

// Split at the widest RELATIVE gap between consecutive samples. A run with no
// interference has no such gap and the whole set is one cluster; a run with
// interference has an obvious one, because the two regimes differ by a factor
// rather than by noise. The 1.25x floor is what makes "no split" possible —
// without it every set splits somewhere.
const SPLIT_RATIO = 1.25;
function fastCluster(xs) {
    let cut = -1;
    let widest = SPLIT_RATIO;
    for (let i = 0; i < xs.length - 1; i++) {
        const ratio = xs[i + 1] / xs[i];
        if (ratio > widest) {
            widest = ratio;
            cut = i;
        }
    }
    if (cut === -1) return { fast: xs, split: false, ratio: 1 };
    return { fast: xs.slice(0, cut + 1), split: true, ratio: widest };
}

function median(xs) {
    if (xs.length === 0) return NaN;
    const m = Math.floor(xs.length / 2);
    return xs.length % 2 ? xs[m] : (xs[m - 1] + xs[m]) / 2;
}

function report(framework) {
    const got = samples(framework);
    if (got === null) return null;
    const xs = got.xs;
    const { fast, split, ratio } = fastCluster(xs);
    return {
        framework,
        mtime: got.mtime,
        n: xs.length,
        fastN: fast.length,
        split,
        ratio,
        fastMedian: median(fast),
        naiveMedian: median(xs),
    };
}

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
