// The two decisions that make a timing run readable, in one place.
//
// Extracted from read-timings.mjs on 2026-08-08 when a second reader appeared
// (ladder.mjs, which reads a whole nine-operation ladder across a field of
// frameworks rather than one benchmark). Two copies of a measurement gate is
// two gates, and the second one is always the lenient one. There is one.
//
// Nothing here is new. The rules and the reasons they exist are unchanged from
// the file this came out of; read that header for the afternoon that produced
// them.

import fs from "node:fs";
import path from "node:path";

// A run's samples, sorted, plus when the file was written. The driver leaves
// one file per framework/benchmark and OVERWRITES IN PLACE, so a directory
// always looks complete even when half of it is from a run two hours ago.
export function samples(resultsDir, framework, benchmark) {
    const file = path.join(resultsDir, `${framework}-keyed_${benchmark}.json`);
    if (!fs.existsSync(file)) return null;
    return {
        xs: JSON.parse(fs.readFileSync(file, "utf8")).values.total.values.slice().sort((a, b) => a - b),
        mtime: fs.statSync(file).mtimeMs,
    };
}

// Split at the widest RELATIVE gap between consecutive samples. A run with no
// interference has no such gap and the whole set is one cluster; a run with
// interference has an obvious one, because the two regimes differ by a factor
// rather than by noise. The 1.25x floor is what makes "no split" possible —
// without it every set splits somewhere.
export const SPLIT_RATIO = 1.25;
export function fastCluster(xs) {
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

export function median(xs) {
    if (xs.length === 0) return NaN;
    const m = Math.floor(xs.length / 2);
    return xs.length % 2 ? xs[m] : (xs[m - 1] + xs[m]) / 2;
}

export function report(resultsDir, framework, benchmark) {
    const got = samples(resultsDir, framework, benchmark);
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
export const SAME_RUN_MINUTES = 90;

// Returns null when the rows are one window, or the reason they are not.
export function windowFault(rows) {
    const counts = [...new Set(rows.map((r) => r.n))];
    if (counts.length > 1) {
        return {
            kind: "counts",
            lines: [
                "REFUSING TO RANK — these results are from DIFFERENT RUNS.",
                "Iteration counts disagree, so they cannot be one invocation:",
                ...rows.map((r) => `  ${r.framework.padEnd(20)} ${r.n} samples`),
                "",
                "The driver overwrites result files in place, so a stale one looks",
                "exactly like a fresh one. Re-run every framework together.",
            ],
        };
    }
    const span = (Math.max(...rows.map((r) => r.mtime)) - Math.min(...rows.map((r) => r.mtime))) / 60000;
    if (span > SAME_RUN_MINUTES) {
        return {
            kind: "span",
            span,
            lines: [
                `REFUSING TO RANK — the result files span ${span.toFixed(0)} minutes.`,
                ...rows.map(
                    (r) => `  ${r.framework.padEnd(20)} written ${new Date(r.mtime).toTimeString().slice(0, 5)}`,
                ),
                "",
                "Whatever else changed between those two moments changed the machine.",
            ],
        };
    }
    return null;
}
