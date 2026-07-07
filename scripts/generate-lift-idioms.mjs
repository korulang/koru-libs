#!/usr/bin/env node

/**
 * Generate LIFT_IDIOMS.md — the footgun gallery of the koru-libs catalog.
 *
 * The lift layer's distinctive idiom is not "what to do" (koru-by-example
 * already covers core-language positives) — it is "what the compiler WON'T let
 * you do." Every lift ships a negative test: a misuse (leak, use-after-free,
 * premature finalize, wrong-type bind) that must FAIL to compile. Those
 * negatives ARE the receipts that the phantom obligations bite.
 *
 * This script auto-discovers every negative test across the catalog, builds
 * each one through the FULL koruc pipeline (NOT `--check` — phantom validation
 * only fires in the emit pass), and captures the REAL koru-level diagnostics.
 * The corpus is verbatim source + the actual rejection. No added prose: the
 * test's own comments carry the explanation; the compiler output is the proof.
 *
 * A negative that STOPS failing is a regression: it is flagged loudly and the
 * script exits non-zero, so the corpus doubles as a footgun-liveness gate.
 *
 * Usage:  node scripts/generate-lift-idioms.mjs            (writes LIFT_IDIOMS.md)
 *         node scripts/generate-lift-idioms.mjs --check     (verify only, no write)
 * Env:    KORUC=/path/to/koruc  (default: ../koru/zig-out/bin/koruc)
 */

import fs from 'fs';
import path from 'path';
import { execFileSync } from 'child_process';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const KORUC =
  process.env.KORUC || path.resolve(ROOT, '..', 'koru', 'zig-out', 'bin', 'koruc');
const OUTPUT = path.join(ROOT, 'LIFT_IDIOMS.md');
const CHECK_ONLY = process.argv.includes('--check');

// ----------------------------------------------------------------------
// Discovery
// ----------------------------------------------------------------------

// Every top-level dir with an index.kz is a lift.
function discoverPackages() {
  return fs
    .readdirSync(ROOT, { withFileTypes: true })
    .filter((e) => e.isDirectory() && fs.existsSync(path.join(ROOT, e.name, 'index.kz')))
    .map((e) => e.name)
    .sort();
}

// A test is NEGATIVE (must-fail) if it lives under a negative/ dir, its
// basename says so, or its body carries an explicit must-fail marker.
const NEGATIVE_MARKER = /NEGATIVE \(must FAIL|EXPECTED:\s*error|EXPECT:\s|must FAIL to compile/;
function isNegative(relPath, source) {
  return (
    /(^|\/)negative(\/|_)/.test(relPath) ||
    /negative/.test(path.basename(relPath)) ||
    NEGATIVE_MARKER.test(source)
  );
}

function collectNegatives(pkg) {
  const testsDir = path.join(ROOT, pkg, 'tests');
  if (!fs.existsSync(testsDir)) return [];
  const out = [];
  const walk = (dir) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, e.name);
      if (e.isDirectory()) {
        if (e.name === '.zig-cache' || e.name.startsWith('.')) continue;
        walk(full);
      } else if (e.name.endsWith('.kz')) {
        const source = fs.readFileSync(full, 'utf-8');
        const rel = path.relative(path.join(ROOT, pkg), full);
        if (isNegative(rel, source)) out.push({ full, rel, source });
      }
    }
  };
  walk(testsDir);
  return out.sort((a, b) => a.rel.localeCompare(b.rel));
}

// ----------------------------------------------------------------------
// Building — capture the real rejection
// ----------------------------------------------------------------------

// Build one file through the full pipeline. Returns { ok, combined }.
// `ok` is true when the build SUCCEEDED (exit 0) — for a negative test that is
// the failure case (the footgun stopped biting).
function build(file, extraArgs = []) {
  try {
    const combined = execFileSync(
      KORUC,
      ['build', path.relative(ROOT, file), ...extraArgs],
      { cwd: ROOT, encoding: 'utf-8', stdio: ['ignore', 'pipe', 'pipe'] }
    );
    return { ok: true, combined };
  } catch (err) {
    const combined = `${err.stdout || ''}${err.stderr || ''}`;
    return { ok: false, combined };
  }
}

// Classify a negative test by the weakest invocation that makes it bite.
//   - 'default'  : rejected under a plain `koruc build` (use-after-X, premature
//                  finalize — auto-discharge cannot rescue these).
//   - 'disable'  : compiles by default (auto-discharge inserts the missing
//                  disposer) but rejected under `--auto-discharge=disable`
//                  (forgotten-discharge / leak class — proves obligation
//                  tracking with the safety net off).
//   - 'regression': compiles clean even with the safety net off — the footgun
//                  no longer bites.
// Also reports `hostErrorDefault`: the default build failed with host-level
// (non-koru) errors — an auto-discharge disposer-emission leak worth flagging.
function classify(file) {
  const r0 = build(file);
  const d0 = extractDiagnostics(r0.combined);
  if (d0.length > 0) return { kind: 'default', diagnostics: d0 };
  const hostErrorDefault = !r0.ok;
  const r1 = build(file, ['--auto-discharge=disable']);
  const d1 = extractDiagnostics(r1.combined);
  if (d1.length > 0) return { kind: 'disable', diagnostics: d1, hostErrorDefault };
  return { kind: 'regression', diagnostics: [], ok: r1.ok, hostErrorDefault };
}

// Pull the koru-level diagnostics out of the build output. These are the
// `error[KORUnnn]:` / `warning[KORUnnn]:` lines — the diagnostics that belong
// to the language, not the host (Zig) backend chatter.
function extractDiagnostics(combined) {
  return combined
    .split('\n')
    .map((l) => l.replace(/\s+$/, ''))
    .filter((l) => /^\s*(error|warning)\[KORU\d+\]:/.test(l))
    .map((l) => l.trim());
}

// ----------------------------------------------------------------------
// Emission
// ----------------------------------------------------------------------

function emit(catalog) {
  const L = [];
  L.push('# Lift idioms by example — the footgun gallery');
  L.push('');
  L.push(
    '> Generated by `scripts/generate-lift-idioms.mjs`. Do not edit by hand — ' +
      'run the script. Every entry below is a **negative test**: a misuse the ' +
      'lift makes *uncompilable*. The source is verbatim; the rejection is the ' +
      'REAL `koruc build` diagnostics, captured live. No prose is added — the ' +
      "test's own comments explain, the compiler proves."
  );
  L.push('');
  L.push(
    'This is the receipts half of the catalog: where `koru-by-example` (in the ' +
      'compiler repo) shows core-language *what-to-do*, this shows the ' +
      'resource-safety *what-you-cannot-do* that only the lifts, wrapping real ' +
      'C resources, can demonstrate. A footgun that stops being rejected is a ' +
      'regression — the generator flags it and fails.'
  );
  L.push('');
  const total = catalog.reduce((n, p) => n + p.entries.length, 0);
  L.push(
    `**${total} uncompilable footguns** across **${catalog.length} lifts**, ` +
      `each rejected at compile time by \`koruc build\`.`
  );
  L.push('');
  L.push('## Contents');
  L.push('');
  for (const p of catalog) {
    L.push(`- **${p.pkg}** — ${p.entries.length} footgun${p.entries.length === 1 ? '' : 's'}`);
  }
  L.push('');
  L.push('---');
  L.push('');
  for (const p of catalog) {
    L.push(`# ${p.pkg}`);
    L.push('');
    for (const e of p.entries) {
      L.push(`## ${p.pkg} — ${e.rel}`);
      L.push('');
      L.push('```koru');
      L.push(e.source.replace(/\n+$/, ''));
      L.push('```');
      L.push('');
      if (e.kind === 'disable') {
        L.push(
          '**Rejected at compile time (`koruc build … --auto-discharge=disable`):** ' +
            '*(a forgotten-discharge/leak footgun — compiles by default because ' +
            'auto-discharge inserts the disposer for you; the safety net off ' +
            'lays the obligation bare)*'
        );
      } else {
        L.push('**Rejected at compile time (`koruc build`):**');
      }
      L.push('');
      L.push('```');
      L.push(e.diagnostics.join('\n'));
      L.push('```');
      L.push('');
      L.push('---');
      L.push('');
    }
  }
  return L.join('\n');
}

// ----------------------------------------------------------------------
// Main
// ----------------------------------------------------------------------

if (!fs.existsSync(KORUC)) {
  console.error(`[fatal] koruc not found at ${KORUC} — set KORUC env var.`);
  process.exit(2);
}

const packages = discoverPackages();
const catalog = [];
const regressions = [];
const hostErrors = [];

for (const pkg of packages) {
  const negatives = collectNegatives(pkg);
  if (negatives.length === 0) continue;
  const entries = [];
  for (const n of negatives) {
    process.stderr.write(`  building ${n.rel} … `);
    const r = classify(n.full);
    if (r.kind === 'regression') {
      process.stderr.write('COMPILED CLEAN even with safety net off — REGRESSION\n');
      regressions.push({ pkg, rel: n.rel });
      continue;
    }
    if (r.hostErrorDefault) {
      // Auto-discharge tried to insert a disposer and produced a host (Zig)
      // error instead of a koru diagnostic — a real toolchain leak to flag.
      hostErrors.push({ pkg, rel: n.rel });
    }
    process.stderr.write(`rejected via ${r.kind} (${r.diagnostics.length} diag)\n`);
    entries.push({ rel: n.rel, source: n.source, diagnostics: r.diagnostics, kind: r.kind });
  }
  if (entries.length > 0) catalog.push({ pkg, entries });
}

if (regressions.length > 0) {
  console.error('\n[REGRESSION] footguns that no longer bite (clean even with --auto-discharge=disable):');
  for (const r of regressions) console.error(`   ${r.pkg}/${r.rel}`);
}

if (hostErrors.length > 0) {
  console.error(
    '\n[host-error] default auto-discharge emitted a raw host (Zig) error instead of a\n' +
      '            koru diagnostic — a disposer-resolution leak to investigate:'
  );
  for (const h of hostErrors) console.error(`   ${h.pkg}/${h.rel}`);
}

if (CHECK_ONLY) {
  console.error(
    `\n[check] ${catalog.reduce((n, p) => n + p.entries.length, 0)} live footguns, ` +
      `${regressions.length} regression(s).`
  );
  process.exit(regressions.length > 0 ? 1 : 0);
}

fs.writeFileSync(OUTPUT, emit(catalog));
console.error(`\n[ok] wrote ${path.relative(ROOT, OUTPUT)} — ` +
  `${catalog.reduce((n, p) => n + p.entries.length, 0)} footguns across ${catalog.length} lifts.`);
process.exit(regressions.length > 0 ? 1 : 0);
