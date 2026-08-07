#!/usr/bin/env node
// The DOM gauntlet closer — a structural DOM assertion harness.
//
// Per operation it renders exactly one of: pass | fail | cant-tell.
//   pass       — every assertion held.
//   fail       — at least one assertion was DEMONSTRABLY violated (wrong text,
//                wrong count, missing required element, wrong structure).
//   cant-tell  — the closer itself could not resolve a verdict (navigation
//                failure, evaluate error, browser/protocol trouble). First-class,
//                counted, never swallowed.
// The cant-tell fraction is reported on every run. That number gates the gauntlet.
//
// Semantic choices, grounded:
// - id cells (td.col-md-1) are asserted EXACT on trimmed text. The reference
//   asserts contains (checkElementContainsText), but its expected values are
//   full ids ("1000", "2000") so contains is near-exact there; for single-digit
//   ids contains would be vacuous. The control renders the bare id
//   (frameworks/keyed/vanillajs/src/Main.js:353), so exact-trimmed is faithful.
// - label cells are asserted CONTAINS, exactly as the reference does
//   (webdriver-ts/src/benchmarksPlaywright.ts:85,90 assert " !!!" containment).
// - a missing required click target (#run, #add, a row's remove anchor …) is a
//   FAIL, not cant-tell: the reference requires those elements
//   (frameworks/keyed/vanillajs/index.html:19-34; every clickElement in
//   benchmarksPlaywright.ts), so absence is nonconformance, demonstrated.
//
// Usage:
//   node closer.mjs --root <static-root> --path <url-path-to-app-dir> \
//                   [--reference <clone-dir>] [--out results.json] [--print-opset]

import http from "node:http";
import { promises as fs } from "node:fs";
import { createReadStream } from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { chromium } from "playwright-core";
import { OPSET } from "./opset.mjs";

const ASSERT_TIMEOUT = 5000;
const BIG_TIMEOUT = 30000;
const NAV_TIMEOUT = 20000;
const POLL_MS = 100;

// ---------- CLI ----------
function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--print-opset") args.printOpset = true;
    else if (a.startsWith("--")) args[a.slice(2)] = argv[++i];
    else throw new Error(`unrecognized argument: ${a}`);
  }
  return args;
}

// ---------- static server ----------
const MIME = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".css": "text/css",
  ".json": "application/json",
  ".ico": "image/x-icon",
  ".map": "application/json",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".eot": "application/vnd.ms-fontobject",
  ".svg": "image/svg+xml",
  ".png": "image/png",
};

function startServer(root) {
  return new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => {
      const urlPath = decodeURIComponent(new URL(req.url, "http://x").pathname);
      let filePath = path.join(root, urlPath);
      if (!filePath.startsWith(path.resolve(root))) {
        res.writeHead(403).end();
        return;
      }
      fs.stat(filePath)
        .then((st) => {
          if (st.isDirectory()) filePath = path.join(filePath, "index.html");
          const stream = createReadStream(filePath);
          stream.on("error", () => res.writeHead(404).end("not found"));
          stream.on("open", () => {
            res.writeHead(200, {
              "content-type": MIME[path.extname(filePath)] ?? "application/octet-stream",
            });
            stream.pipe(res);
          });
        })
        .catch(() => res.writeHead(404).end("not found"));
    });
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

// ---------- verdict plumbing ----------
class Violated extends Error {}
class Unresolvable extends Error {}

function makeChecker(page, assertions) {
  const record = (name, status, detail) => {
    assertions.push({ name, status, detail });
    if (status === "violated") throw new Violated(`${name}: ${detail}`);
    if (status === "unresolvable") throw new Unresolvable(`${name}: ${detail}`);
  };

  // Poll an in-page probe until it reports ok, or timeout. The probe returns
  // { ok: boolean, actual: string } — actual is rendered in the verdict detail.
  const poll = async (name, probeFn, arg, describe, timeout = ASSERT_TIMEOUT) => {
    const deadline = Date.now() + timeout;
    let last;
    for (;;) {
      try {
        last = await page.evaluate(probeFn, arg);
      } catch (e) {
        record(name, "unresolvable", `in-page evaluation failed: ${e.message}`);
      }
      if (last && last.ok) {
        record(name, "holds", describe);
        return last;
      }
      if (Date.now() > deadline) {
        record(name, "violated", `${describe}; actual after ${timeout}ms: ${last ? last.actual : "no result"}`);
      }
      await new Promise((r) => setTimeout(r, POLL_MS));
    }
  };

  return {
    record,
    poll,

    // Structural click: wait for the element to EXIST, then dispatch a real
    // bubbling click via el.click(). Deliberately not Playwright's coordinate
    // click — that gates on visual actionability (size, opacity, hit-testing),
    // which drags CSS into what is a purely structural harness. Measured during
    // calibration: with the global bootstrap CSS absent, .glyphicon spans are
    // zero-width and page.click() times out with "element is not visible" —
    // an infrastructure cant-tell on a target whose DOM was fully conformant.
    async click(sel, timeout = ASSERT_TIMEOUT) {
      const deadline = Date.now() + timeout;
      for (;;) {
        let found;
        try {
          found = await page.evaluate((s) => !!document.querySelector(s), sel);
        } catch (e) {
          record(`click ${sel}`, "unresolvable", `in-page evaluation failed: ${e.message}`);
        }
        if (found) break;
        if (Date.now() > deadline) {
          record(`click ${sel}`, "violated", `required click target missing after ${timeout}ms`);
        }
        await new Promise((r) => setTimeout(r, POLL_MS));
      }
      try {
        await page.evaluate((s) => document.querySelector(s).click(), sel);
        assertions.push({ name: `click ${sel}`, status: "holds", detail: "clicked (structural dispatch)" });
      } catch (e) {
        record(`click ${sel}`, "unresolvable", `click dispatch failed on present element: ${e.message}`);
      }
    },

    textIs(sel, expected, timeout) {
      return poll(
        `text ${sel} == "${expected}"`,
        ([s, exp]) => {
          const el = document.querySelector(s);
          if (!el) return { ok: false, actual: "element absent" };
          const t = (el.textContent ?? "").trim();
          return { ok: t === exp, actual: JSON.stringify(t) };
        },
        [sel, expected],
        `expected exact trimmed text "${expected}"`,
        timeout
      );
    },

    textContains(sel, expected, timeout) {
      return poll(
        `text ${sel} contains "${expected}"`,
        ([s, exp]) => {
          const el = document.querySelector(s);
          if (!el) return { ok: false, actual: "element absent" };
          const t = (el.textContent ?? "").trim();
          return { ok: t.includes(exp), actual: JSON.stringify(t) };
        },
        [sel, expected],
        `expected text containing "${expected}"`,
        timeout
      );
    },

    textLacks(sel, needle, timeout) {
      return poll(
        `text ${sel} lacks "${needle}"`,
        ([s, exp]) => {
          const el = document.querySelector(s);
          if (!el) return { ok: false, actual: "element absent" };
          const t = (el.textContent ?? "").trim();
          return { ok: !t.includes(exp), actual: JSON.stringify(t) };
        },
        [sel, needle],
        `expected text NOT containing "${needle}"`,
        timeout
      );
    },

    countIs(sel, expected, timeout) {
      return poll(
        `count ${sel} == ${expected}`,
        ([s, exp]) => {
          const n = document.querySelectorAll(s).length;
          return { ok: n === exp, actual: String(n) };
        },
        [sel, expected],
        `expected exactly ${expected} matches`,
        timeout
      );
    },

    hasClass(sel, cls, timeout) {
      return poll(
        `class ${sel} has "${cls}"`,
        ([s, c]) => {
          const el = document.querySelector(s);
          if (!el) return { ok: false, actual: "element absent" };
          return { ok: el.classList.contains(c), actual: JSON.stringify(el.className) };
        },
        [sel, cls],
        `expected class "${cls}"`,
        timeout
      );
    },

    // Pre-state read. Element absence here is unresolvable, not violated: the
    // op's own preceding assertions establish presence; if a read still misses,
    // the closer lost the race, not the target.
    async read(sel) {
      let r;
      try {
        r = await page.evaluate((s) => {
          const el = document.querySelector(s);
          return el ? { present: true, text: (el.textContent ?? "").trim() } : { present: false };
        }, sel);
      } catch (e) {
        record(`read ${sel}`, "unresolvable", `in-page evaluation failed: ${e.message}`);
      }
      if (!r.present) record(`read ${sel}`, "unresolvable", "element vanished between assertion and read");
      return r.text;
    },

    async evaluate(name, fn, arg) {
      try {
        return await page.evaluate(fn, arg);
      } catch (e) {
        record(name, "unresolvable", `in-page evaluation failed: ${e.message}`);
      }
    },
  };
}

const row = (n) => `tbody>tr:nth-of-type(${n})`;
const id = (n) => `${row(n)}>td:nth-of-type(1)`;
const label = (n) => `${row(n)}>td:nth-of-type(2)>a`;
const removeBtn = (n) => `${row(n)}>td:nth-of-type(3)>a>span:nth-of-type(1)`;

// The MutationObserver instrument, adapted from the reference's non-keyed
// detector (webdriver-ts/src/isKeyed.ts:46-128). Shadow-DOM branch dropped:
// the reference itself tells implementations to avoid shadow DOM (README:338).
const KEYED_INSTRUMENT = `
window.kd_reset = function() {
  window.kd_tradded = [];
  window.kd_trremoved = [];
};
window.kd_countDiff = function(list1, list2) {
  let s = new Set(list1);
  for (let o of list2) s.delete(o);
  return s.size;
};
window.kd_instrument = function() {
  var target = document.querySelector('table.table');
  if (!target) return false;
  function filterTR(nodeList) {
    let trs = [];
    nodeList.forEach(n => {
      if (n.tagName === 'TR') {
        trs.push(n);
        trs = trs.concat(filterTR(n.childNodes));
      }
    });
    return trs;
  }
  var observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(mutation) {
      if (mutation.type === 'childList') {
        window.kd_tradded = window.kd_tradded.concat(filterTR(mutation.addedNodes));
        window.kd_trremoved = window.kd_trremoved.concat(filterTR(mutation.removedNodes));
      }
    });
  });
  observer.observe(target, { childList: true, attributes: true, subtree: true, characterData: true });
  return true;
};
window.kd_result = function() {
  return {
    tradded: window.kd_tradded.length,
    trremoved: window.kd_trremoved.length,
    removedStoredTr: window.kd_trremoved.indexOf(window.kd_storedTr) > -1,
    newNodes: window.kd_countDiff(window.kd_tradded, window.kd_trremoved),
  };
};
window.kd_storeTr = function() {
  // Alpine workaround carried over from the reference (isKeyed.ts:123-125).
  let index = document.querySelector('tbody>tr:nth-child(1)') ? 2 : 3;
  window.kd_storedTr = document.querySelector('tbody>tr:nth-child(' + index + ')');
};
window.kd_reset();
true;
`;

// ---------- the operations ----------
// Each op receives a fresh page. Signature: async (c) where c is the checker.
const OPERATIONS = {
  // benchmarksPlaywright.ts:39-56 — click #run, rows 1..1000 appear, ids sequential from 1.
  async "01_run1k"(c) {
    await c.click("#run");
    await c.countIs("tbody>tr", 1000);
    await c.textIs(id(1), "1");
    await c.textIs(id(1000), "1000");
  },

  // benchmarksPlaywright.ts:58-73 — second #run replaces all rows; ids continue (1001..2000).
  async "02_replace1k"(c) {
    await c.click("#run");
    await c.textIs(id(1000), "1000");
    await c.click("#run");
    await c.textIs(id(1), "1001");
    await c.textIs(id(1000), "2000");
    await c.countIs("tbody>tr", 1000);
  },

  // benchmarksPlaywright.ts:75-92 — #update appends " !!!" to every 10th row's label
  // (rows 1, 11, …, 991 per Main.js:75-80); other rows untouched.
  async "03_update10th1k"(c) {
    await c.click("#run");
    await c.textIs(id(1000), "1000");
    await c.click("#update");
    await c.textContains(label(991), " !!!");
    await c.textContains(label(1), " !!!");
    await c.textContains(label(11), " !!!");
    await c.textLacks(label(2), " !!!");
  },

  // benchmarksPlaywright.ts:94-113 — clicking a row's label selects it: class
  // "danger" on the TR, exactly one selected; selection moves on the next click.
  async "04_select1k"(c) {
    await c.click("#run");
    await c.textIs(id(1000), "1000");
    await c.click(label(5));
    await c.hasClass(row(5), "danger");
    await c.countIs("tbody>tr.danger", 1);
    await c.click(label(2));
    await c.hasClass(row(2), "danger");
    await c.countIs("tbody>tr.danger", 1);
  },

  // benchmarksPlaywright.ts:115-136 — #swaprows exchanges rows 2 and 999
  // (Main.js:109-115); neighbors stay put.
  async "05_swap1k"(c) {
    await c.click("#run");
    await c.textIs(id(1000), "1000");
    const pre = {};
    for (const n of [1, 2, 3, 998, 999, 1000]) pre[n] = await c.read(id(n));
    await c.click("#swaprows");
    await c.textIs(id(2), pre[999]);
    await c.textIs(id(999), pre[2]);
    await c.textIs(id(1), pre[1]);
    await c.textIs(id(3), pre[3]);
    await c.textIs(id(998), pre[998]);
    await c.textIs(id(1000), pre[1000]);
  },

  // benchmarksPlaywright.ts:138-165 — clicking row N's remove anchor deletes it;
  // the successor shifts into position N.
  async "06_remove1k"(c) {
    await c.click("#run");
    await c.textIs(id(1000), "1000");
    const pre4 = await c.read(id(4));
    const pre5 = await c.read(id(5));
    const pre6 = await c.read(id(6));
    await c.click(removeBtn(4));
    await c.textIs(id(4), pre5);
    await c.textIs(id(5), pre6);
    await c.countIs("tbody>tr", 999);
    c.record("removed id gone", pre4 !== pre5 ? "holds" : "violated", `row 4 was "${pre4}", now "${pre5}"`);
  },

  // benchmarksPlaywright.ts:168-185 — #runlots creates 10,000 rows.
  async "07_create10k"(c) {
    await c.click("#runlots");
    await c.countIs("tbody>tr", 10000, BIG_TIMEOUT);
    await c.countIs(`${row(10000)}>td:nth-of-type(2)>a`, 1);
    await c.textIs(id(10000), "10000");
  },

  // benchmarksPlaywright.ts:187-206 — #add appends 1,000 rows to the existing 1,000.
  async "08_create1k_after1k"(c) {
    await c.click("#run");
    await c.textIs(id(1000), "1000");
    await c.click("#add");
    await c.countIs("tbody>tr", 2000, BIG_TIMEOUT);
    await c.textIs(id(1001), "1001");
    await c.textIs(id(2000), "2000");
    await c.textIs(id(1), "1");
  },

  // benchmarksPlaywright.ts:208-227 — #clear empties the table.
  async "09_clear1k"(c) {
    await c.click("#run");
    await c.textIs(id(1000), "1000");
    await c.click("#clear");
    await c.countIs("tbody>tr", 0);
  },

  // isKeyed.ts:205-249 (checkTRcorrect), reached via #add per isKeyed.ts:273-282.
  async "10_html_structure"(c) {
    await c.click("#add");
    await c.textIs(id(1000), "1000");
    const s = await c.evaluate("structure probe", () => {
      const tr = document.querySelector("tbody>tr:nth-of-type(1000)");
      if (!tr) return { present: false };
      const tags = [...tr.querySelectorAll("*")].map((e) => e.tagName.toLowerCase());
      const cls = (sel) => {
        const el = tr.querySelector(sel);
        return el ? el.className : null;
      };
      const span = tr.querySelector("td:nth-of-type(3)>a>span");
      return {
        present: true,
        tags,
        td1: cls("td:nth-of-type(1)"),
        td2: cls("td:nth-of-type(2)"),
        td3: cls("td:nth-of-type(3)"),
        td4: cls("td:nth-of-type(4)"),
        spanClass: span ? span.className : null,
        spanAria: span ? span.getAttribute("aria-hidden") : null,
      };
    });
    c.record("row 1000 present", s.present ? "holds" : "violated", "tbody>tr:nth-of-type(1000)");
    const golden = ["td", "td", "a", "td", "a", "span", "td"]; // isKeyed.ts:207
    c.record(
      "tr child tags",
      JSON.stringify(s.tags) === JSON.stringify(golden) ? "holds" : "violated",
      `expected ${JSON.stringify(golden)}, actual ${JSON.stringify(s.tags)}`
    );
    const classChecks = [
      ["td1 class", s.td1, "col-md-1"],
      ["td2 class", s.td2, "col-md-4"],
      ["td3 class", s.td3, "col-md-1"],
      ["td4 class", s.td4, "col-md-6"],
      ["span class glyphicon", s.spanClass, "glyphicon"],
      ["span class glyphicon-remove", s.spanClass, "glyphicon-remove"],
    ];
    for (const [name, actual, expected] of classChecks) {
      c.record(
        name,
        actual != null && actual.split(" ").includes(expected) ? "holds" : "violated",
        `expected class "${expected}", actual ${JSON.stringify(actual)}`
      );
    }
    c.record("span aria-hidden", s.spanAria === "true" ? "holds" : "violated", `expected "true", actual ${JSON.stringify(s.spanAria)}`);
  },

  // 11_keyedness runs via runKeyednessBody — it needs the raw instrument script
  // installed on the page first, so runOp handles it as its own arm.
};

// The instrument script must run as a real page script, not a function body
// returning — install it via evaluate of the raw source.
async function installInstrument(page) {
  await page.evaluate(KEYED_INSTRUMENT);
}

// ---------- runner ----------
async function runOp(browser, baseUrl, op) {
  const assertions = [];
  let page;
  try {
    page = await browser.newPage();
    await page.goto(baseUrl, { waitUntil: "load", timeout: NAV_TIMEOUT });
  } catch (e) {
    assertions.push({ name: "navigate", status: "unresolvable", detail: `navigation failed: ${e.message}` });
    if (page) await page.close().catch(() => {});
    return { id: op.id, label: op.label, verdict: "cant-tell", assertions };
  }
  const c = makeChecker(page, assertions);
  try {
    if (op.id === "11_keyedness") {
      // Needs the instrument installed as a raw page script before its body runs.
      await c.click("#add");
      await c.textIs(id(1000), "1000");
      await installInstrument(page);
      await runKeyednessBody(c, page);
    } else {
      await OPERATIONS[op.id](c);
    }
  } catch (e) {
    if (!(e instanceof Violated) && !(e instanceof Unresolvable)) {
      assertions.push({ name: "harness", status: "unresolvable", detail: `unexpected closer error: ${e.stack}` });
    }
  }
  await page.close().catch(() => {});
  const verdict = assertions.some((a) => a.status === "violated")
    ? "fail"
    : assertions.some((a) => a.status === "unresolvable")
      ? "cant-tell"
      : "pass";
  return { id: op.id, label: op.label, verdict, assertions, provenance: op.provenance };
}

// Body of 11_keyedness after #add + instrument install (sequence isKeyed.ts:283-312).
async function runKeyednessBody(c, page) {
  const ok = await c.evaluate("instrument table.table", () => window.kd_instrument());
  c.record("table.table observable", ok === true ? "holds" : "violated", "MutationObserver target table.table (isKeyed.ts:72)");

  await c.evaluate("storeTr", () => window.kd_storeTr());
  await c.click("#swaprows");
  await c.textIs(id(2), "999");
  let r = await c.evaluate("swap result", () => window.kd_result());
  c.record(
    "keyed swap",
    r.tradded > 0 && r.trremoved > 0 && r.newNodes === 0 ? "holds" : "violated",
    `tradded=${r.tradded} trremoved=${r.trremoved} newNodes=${r.newNodes} (need >0, >0, ==0; isKeyed.ts:152-168)`
  );

  await c.evaluate("storeTr", () => window.kd_storeTr());
  await c.evaluate("reset", () => window.kd_reset());
  await c.click("#run");
  await c.textIs(id(1000), "2000");
  r = await c.evaluate("run result", () => window.kd_result());
  c.record(
    "keyed run",
    r.tradded >= 1000 && r.trremoved >= 1000 ? "holds" : "violated",
    `tradded=${r.tradded} trremoved=${r.trremoved} (need >=1000 each; isKeyed.ts:130-142)`
  );

  await c.evaluate("storeTr", () => window.kd_storeTr());
  await c.evaluate("reset", () => window.kd_reset());
  await c.textIs(id(2), "1002");
  await c.click(removeBtn(2));
  await c.textIs(id(2), "1003");
  r = await c.evaluate("remove result", () => window.kd_result());
  c.record("keyed remove", r.removedStoredTr ? "holds" : "violated", `removedStoredTr=${r.removedStoredTr} (need true; isKeyed.ts:143-151)`);
}

async function main() {
  const args = parseArgs(process.argv);

  if (args.printOpset) {
    process.stdout.write(JSON.stringify(OPSET, null, 2) + "\n");
    return;
  }

  if (!args.root || !args.path) {
    console.error("closer: --root <static-root> and --path <url-path> are required.");
    console.error("The spec this harness asserts lives in the reference clone; see opset.mjs for provenance.");
    process.exit(2);
  }

  let referenceHead = null;
  if (args.reference) {
    referenceHead = execFileSync("git", ["-C", args.reference, "rev-parse", "HEAD"], { encoding: "utf8" }).trim();
  }

  const server = await startServer(args.root);
  const port = server.address().port;
  const baseUrl = `http://127.0.0.1:${port}${args.path.endsWith("/") ? args.path : args.path + "/"}index.html`;

  const browser = await chromium.launch({ channel: "chrome", headless: true });

  const ops = [];
  for (const op of OPSET) {
    const result = await runOp(browser, baseUrl, op);
    ops.push(result);
    console.error(`${result.verdict.padEnd(9)} ${op.id} — ${op.label}`);
    for (const a of result.assertions) {
      if (a.status !== "holds") console.error(`          ${a.status}: ${a.name} — ${a.detail}`);
    }
  }

  await browser.close();
  server.close();

  const total = ops.length;
  const summary = {
    total,
    pass: ops.filter((o) => o.verdict === "pass").length,
    fail: ops.filter((o) => o.verdict === "fail").length,
    cant_tell: ops.filter((o) => o.verdict === "cant-tell").length,
  };
  summary.cant_tell_fraction = summary.cant_tell / total;

  const result = {
    closer: "dom/closer/closer.mjs",
    timestamp: new Date().toISOString(),
    target: { root: path.resolve(args.root), path: args.path, url: baseUrl },
    reference: args.reference ? { clone: path.resolve(args.reference), head: referenceHead } : null,
    summary,
    ops,
  };

  const json = JSON.stringify(result, null, 2) + "\n";
  if (args.out) await fs.writeFile(args.out, json);
  else process.stdout.write(json);

  console.error(
    `\n${summary.pass}/${total} pass, ${summary.fail} fail, ${summary.cant_tell} cant-tell — cant-tell fraction ${(summary.cant_tell_fraction * 100).toFixed(1)}%`
  );
}

main().catch((e) => {
  console.error("closer: fatal:", e);
  process.exit(1);
});
