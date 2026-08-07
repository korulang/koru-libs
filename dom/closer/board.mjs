#!/usr/bin/env node
// The board generator — the ONLY writer of dom/board/history.jsonl and
// dom/board/latest.md. Nothing on the board is written by hand, ever; a
// hand-patched number is a corrupted instrument steering an unsupervised fleet.
//
// Every field is computed from inputs that are themselves closer output:
//   bar        — operation count, read from the calibration run's op list.
//   current    — the vehicle's pass count from a closer run against it; or 0,
//                computed from the measured absence of a vehicle entry point.
//   delta      — current minus the previous row's current; null on round zero
//                (genuinely no previous, not 0).
//   what_moved — per-op verdict diff against the previous row.
//   cant_tell  — the closer's own unresolved fraction on the run that produced
//                `current`; with no vehicle run, the calibration run's fraction,
//                and the source is named.
//   js_escape  — fraction of vehicle source lines that fall out to `|js`;
//                OMITTED entirely while no implementation exists (absent, not 0).
//
// Usage:
//   node board.mjs --calibration <control-results.json> \
//                  [--perturbation <name>=<results.json> ...] \
//                  [--vehicle <vehicle-results.json>] \
//                  [--vehicle-root <dir>] [--vehicle-src <dir>] \
//                  [--board-dir <dir>]   (default: ../board next to this script)

import { promises as fs } from "node:fs";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const args = { perturbation: [] };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith("--")) throw new Error(`unrecognized argument: ${a}`);
    const key = a.slice(2);
    const val = argv[++i];
    if (key === "perturbation") args.perturbation.push(val);
    else args[key] = val;
  }
  return args;
}

function loadResults(file) {
  const r = JSON.parse(readFileSync(file, "utf8"));
  if (!r.ops || !r.summary) {
    throw new Error(`${file} is not closer output (missing ops/summary). Run dom/closer/closer.mjs to produce it.`);
  }
  return r;
}

// js_escape: the fraction of the vehicle that fell out to host JavaScript
// rather than being expressible in Koru. The second headline metric — the
// feature-mining count.
//
// Definition (round 1, generator fixed to match the facet layout the vehicle
// actually uses — the original only walked .k/.kz and grepped for `|js`, so a
// vehicle whose escapes live in .kjs facet files reported near-zero):
//   - files: every .k, .kz, .kjs under --vehicle-src;
//   - lines counted: non-blank, non-comment (trimmed `//`-leading excluded);
//   - .k files are pure Koru — every counted line is a Koru line;
//   - in .kz/.kjs host files, a counted line is KORU when it is `~`-mode
//     surface (trimmed line starts with `~`), HOST otherwise — top-level host
//     lines and the bodies of `~proc …|<target> { … }` blocks (tracked by
//     brace balance from the proc header). The proc header itself counts as
//     ESCAPED: it is the line that declares the escape.
//   - js_escape = js_host_lines / (js_host_lines + koru_lines).
// Round-3 refinement (disclosed on the board commit): host lines are
// classified by HOST LANGUAGE, the same discrimination the compiler makes
// (src/file_types.zig hostLangOfFile / proc.target). A `~proc …|js` body and
// a bare .kjs host line are JavaScript the app ships — ESCAPED. A
// `~proc …|zig` body and a bare .kz host line are compile-time Zig (Stage-C
// transform machinery, e.g. the koru/dom `component` transform) — they never
// reach the browser and are counted on NEITHER side of a metric named
// js_escape. Rounds 1 and 2 recomputed under this rule are bit-identical
// (66.7% = 36/54, 46.2% = 60/130): no |zig line existed in the vehicle then.
// Scope note: the classifier covers the facet layout (declarations in .k,
// host bodies in .kjs/.kz). Effect-branch continuation lines under a ~tor
// inside a HOST file would misclassify as host; the vehicle declares events
// in .k facets where the question cannot arise.
export function computeJsEscape(srcDir) {
  let koru = 0;
  let host = 0;
  const classifyHostFile = (text, fileHostIsJs) => {
    let depth = 0; // brace depth inside a ~proc host body
    let bodyIsJs = false; // whether the current proc body is a |js body
    for (const raw of text.split("\n")) {
      const line = raw.trim();
      if (line === "" || line.startsWith("//")) continue;
      if (depth > 0) {
        if (bodyIsJs) host++;
        for (const ch of line) {
          if (ch === "{") depth++;
          else if (ch === "}") depth--;
        }
        continue;
      }
      if (line.startsWith("~")) {
        if (/^~proc\b.*\|[a-z]+/.test(line)) {
          const tags = (line.split("{")[0].match(/\|[a-z]+/g) ?? []).map((t) => t.slice(1));
          const isJs = tags.includes("js");
          if (isJs) host++; // the escape declaration itself
          let d = 0;
          for (const ch of line) {
            if (ch === "{") d++;
            else if (ch === "}") d--;
          }
          if (d > 0) {
            depth = d;
            bodyIsJs = isJs;
          }
        } else {
          koru++;
        }
      } else {
        if (fileHostIsJs) host++;
      }
    }
  };
  // The vehicle is the shipping surface: the instrument (closer/, board/),
  // pinned-defect repros (tests/), and dependency trees are not vehicle source.
  const SKIP_DIRS = new Set(["closer", "board", "tests", "node_modules", "zig-out", ".zig-cache"]);
  const walk = (dir) => {
    for (const entry of readdirSync(dir)) {
      const p = path.join(dir, entry);
      const st = statSync(p);
      if (st.isDirectory()) {
        if (!SKIP_DIRS.has(entry)) walk(p);
      }
      else if (/\.k$/.test(entry)) {
        for (const raw of readFileSync(p, "utf8").split("\n")) {
          const line = raw.trim();
          if (line === "" || line.startsWith("//")) continue;
          koru++;
        }
      } else if (/\.(kz|kjs)$/.test(entry)) {
        classifyHostFile(readFileSync(p, "utf8"), /\.kjs$/.test(entry));
      }
    }
  };
  walk(srcDir);
  const total = koru + host;
  if (total === 0) throw new Error(`no .k/.kz/.kjs source lines found under ${srcDir} — cannot compute js_escape`);
  return { fraction: host / total, escaped_lines: host, total_lines: total };
}

async function main() {
  const args = parseArgs(process.argv);
  const boardDir = path.resolve(args["board-dir"] ?? path.join(HERE, "..", "board"));
  const historyPath = path.join(boardDir, "history.jsonl");
  const latestPath = path.join(boardDir, "latest.md");

  if (!args.calibration) {
    console.error("board: --calibration <control-results.json> is required — the board does not exist without a calibrated closer.");
    console.error("Produce it: node closer.mjs --root <reference-clone> --path /frameworks/keyed/vanillajs/ --out control.json");
    process.exit(2);
  }
  const calibration = loadResults(args.calibration);

  const perturbations = args.perturbation.map((spec) => {
    const eq = spec.indexOf("=");
    if (eq < 0) throw new Error(`--perturbation wants <name>=<results.json>, got: ${spec}`);
    const name = spec.slice(0, eq);
    const r = loadResults(spec.slice(eq + 1));
    return {
      name,
      caught: r.ops.filter((o) => o.verdict === "fail").map((o) => o.id),
      cant_tell: r.ops.filter((o) => o.verdict === "cant-tell").map((o) => o.id),
    };
  });

  // --- current: from a vehicle run, or from the measured absence of a vehicle ---
  let current;
  let cantTell;
  let cantTellSource;
  let opVerdicts;
  let vehicleState;
  if (args.vehicle) {
    const v = loadResults(args.vehicle);
    current = v.summary.pass;
    cantTell = v.summary.cant_tell_fraction;
    cantTellSource = "vehicle-run";
    opVerdicts = Object.fromEntries(v.ops.map((o) => [o.id, o.verdict]));
    vehicleState = `measured (${args.vehicle})`;
  } else if (args["vehicle-root"]) {
    const entry = path.join(path.resolve(args["vehicle-root"]), "index.html");
    if (existsSync(entry)) {
      console.error(`board: a vehicle entry point exists at ${entry} but no --vehicle results were given.`);
      console.error("Run the closer against it and pass --vehicle — the board does not guess.");
      process.exit(2);
    }
    current = 0;
    cantTell = calibration.summary.cant_tell_fraction;
    cantTellSource = "control-calibration";
    opVerdicts = Object.fromEntries(calibration.ops.map((o) => [o.id, "unattempted"]));
    vehicleState = `absent (no ${entry})`;
  } else {
    console.error("board: pass --vehicle <results.json> or --vehicle-root <dir> so `current` is computed, not assumed.");
    process.exit(2);
  }

  const bar = calibration.ops.length;

  // --- previous row, for delta and what_moved ---
  let previous = null;
  if (existsSync(historyPath)) {
    const lines = readFileSync(historyPath, "utf8").split("\n").filter((l) => l.trim());
    if (lines.length > 0) previous = JSON.parse(lines[lines.length - 1]);
  }
  const round = previous ? previous.round + 1 : 0;
  const delta = previous ? current - previous.current : null;

  const whatMoved = [];
  if (previous && previous.op_verdicts) {
    for (const [id, verdict] of Object.entries(opVerdicts)) {
      const prev = previous.op_verdicts[id];
      if (prev !== verdict) whatMoved.push(`${id}: ${prev ?? "new-op"} -> ${verdict}`);
    }
  } else {
    whatMoved.push(
      `round zero: vehicle ${vehicleState}; closer calibrated on control ` +
        `${calibration.summary.pass}/${calibration.ops.length} pass at ${(calibration.summary.cant_tell_fraction * 100).toFixed(1)}% cant-tell` +
        (perturbations.length
          ? `; perturbation checks fired: ${perturbations.map((p) => `${p.name} caught [${p.caught.join(", ")}]${p.cant_tell.length ? ` cant-tell [${p.cant_tell.join(", ")}]` : ""}`).join("; ")}`
          : "")
    );
  }

  const row = {
    round,
    timestamp: new Date().toISOString(),
    bar,
    current,
    delta,
    what_moved: whatMoved,
    cant_tell: cantTell,
    cant_tell_source: cantTellSource,
    vehicle: vehicleState,
    op_verdicts: opVerdicts,
    control_certification: {
      target: calibration.target.url,
      pass: calibration.summary.pass,
      fail: calibration.summary.fail,
      cant_tell_fraction: calibration.summary.cant_tell_fraction,
      timestamp: calibration.timestamp,
      reference: calibration.reference,
    },
    perturbation_checks: perturbations,
    generator: "dom/closer/board.mjs",
  };
  if (args["vehicle-src"]) {
    row.js_escape = computeJsEscape(args["vehicle-src"]);
  }
  // No vehicle source -> js_escape is genuinely absent from the row. Not 0.

  await fs.mkdir(boardDir, { recursive: true });
  await fs.appendFile(historyPath, JSON.stringify(row) + "\n");

  // --- latest.md, rendered from the row just appended ---
  const pct = (x) => `${(x * 100).toFixed(1)}%`;
  const md = `# DOM_GAUNTLET — board, round ${row.round}

*Generated by \`${row.generator}\` at ${row.timestamp}. Do not edit — see \`dom/board/README.md\`.*

| field | value |
|---|---|
| **bar** | ${row.bar} operations conformant (reference: krausest/js-framework-benchmark, keyed) |
| **current** | ${row.current} / ${row.bar} |
| **delta** | ${row.delta === null ? "— (round zero, no previous round)" : (row.delta >= 0 ? "+" : "") + row.delta} |
| **cant_tell** | ${pct(row.cant_tell)} (source: ${row.cant_tell_source}) |
| **js_escape** | ${row.js_escape ? `${pct(row.js_escape.fraction)} (${row.js_escape.escaped_lines}/${row.js_escape.total_lines} lines)` : "absent — no implementation exists yet"} |
| **vehicle** | ${row.vehicle} |

## What moved

${row.what_moved.map((w) => `- ${w}`).join("\n")}

## Closer certification (positive control)

\`${row.control_certification.target}\`: ${row.control_certification.pass}/${row.bar} pass, ${row.control_certification.fail} fail, cant-tell ${pct(row.control_certification.cant_tell_fraction)} — run ${row.control_certification.timestamp}${row.control_certification.reference ? `, reference @ ${row.control_certification.reference.head}` : ""}

## Closer failure detection (negative controls)

${row.perturbation_checks.length ? row.perturbation_checks.map((p) => `- **${p.name}**: caught ${p.caught.length ? p.caught.map((c) => `\`${c}\``).join(", ") : "(nothing)"}${p.cant_tell.length ? `; cant-tell ${p.cant_tell.map((c) => `\`${c}\``).join(", ")}` : ""}`).join("\n") : "- none recorded this round"}

## Per-operation verdicts

| operation | verdict |
|---|---|
${Object.entries(row.op_verdicts).map(([id, v]) => `| ${id} | ${v} |`).join("\n")}
`;
  await fs.writeFile(latestPath, md);

  console.error(`board: appended round ${row.round} to ${historyPath}`);
  console.error(`board: rendered ${latestPath}`);
  console.error(`board: bar=${row.bar} current=${row.current} delta=${row.delta} cant_tell=${pct(row.cant_tell)} js_escape=${row.js_escape ? pct(row.js_escape.fraction) : "absent"}`);
}

// Run only as an entry script — computeJsEscape is importable (the round-3
// measure recomputation imports it to re-run earlier rounds' trees).
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((e) => {
    console.error("board: fatal:", e.message);
    process.exit(1);
  });
}
