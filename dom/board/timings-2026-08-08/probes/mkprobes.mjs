// Build hand-edited variants of the emitted JS to PRICE candidate fixes
// before writing any compiler code. Every replacement asserts its hit count —
// a silently-missed edit would measure the baseline and call it a win.
import fs from "node:fs";
import path from "node:path";

const REF = "/private/tmp/claude-501/-Users-larsde-src-koru/8b62cc24-de83-4ac4-af86-07f80bf61b9a/scratchpad/js-framework-benchmark";
const BASE = path.join(REF, "frameworks/keyed/koru");
const src = fs.readFileSync(path.join(BASE, "output_emitted.js"), "utf8");

function replace(text, from, to, expect) {
  const n = text.split(from).length - 1;
  if (n !== expect) throw new Error(`expected ${expect} occurrence(s), found ${n}:\n${from.slice(0, 90)}`);
  return text.split(from).join(to);
}

// ---- edit 1: the app RETAINS the node it just created, instead of re-finding
// it by scanning the live DOM. This is what a markup surface that kept its
// own handle would emit; domRow's querySelector is the escape standing in
// for the association the compiler had at creation time and discarded.
function nodeMap(text) {
  let t = text;
  t = replace(
    t,
    `function domRow(id) {
    return document.querySelector("tr[data-id='" + id + "']");
}`,
    `const __koru_dom_nodes = new Map();
function domRow(id) {
    return __koru_dom_nodes.get(id);
}`,
    1
  );
  // both row-creation sites (the Row event and its inlined copy in the
  // inserted-interceptor) register the node they minted
  t = replace(
    t,
    `document.querySelector(parent).appendChild(__root);`,
    `__koru_dom_nodes.set(id, __root); document.querySelector(parent).appendChild(__root);`,
    2
  );
  // removal drops the entry so the map cannot outlive the row
  t = replace(
    t,
    `      const tr = domRow(id);
      tr.parentNode.removeChild(tr);`,
    `      const tr = domRow(id);
      __koru_dom_nodes.delete(id);
      tr.parentNode.removeChild(tr);`,
    1
  );
  return t;
}

// ---- edit 2: a BULK clear — the vocabulary candidate. The store empties in
// one step and the observer gets one aggregate DOM write instead of 1000
// per-row ones. This is the ceiling any `store:empty`-shaped verb could reach.
function bulkClear(text) {
  return replace(
    text,
    `  clear_event: {
    handler(__koru_input) {
      main_module.__store_write_op_event.handler({ field: 0, value: 5 });
      main_module.sweep_event.handler({});
      main_module.__store_write_op_event.handler({ field: 0, value: 0 });
    },
  },`,
    `  clear_event: {
    handler(__koru_input) {
      // SIMULATED bulk-empty: store reset in one step, one aggregate DOM
      // write. Brand bump invalidates every outstanding handle, which is
      // what a real empty() must do to keep the stale-handle trap honest.
      __koru_store_rows.len = 0;
      __koru_store_rows.__koru_hslot_free_len = 0;
      __koru_store_rows.__koru_hslot_next = 0;
      __koru_store_rows.__koru_brand += 1;
      main_module.__store_write_cnt_event.handler({ field: 0, value: 0 });
      document.querySelector("#tbody").textContent = "";
    },
  },`,
    1
  );
}

const variants = {
  korumap: nodeMap(src),
  korubulk: bulkClear(src),
  koruboth: bulkClear(nodeMap(src)),
};

for (const [name, code] of Object.entries(variants)) {
  const dir = path.join(REF, "frameworks/keyed", name);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, "output_emitted.js"), code);
  fs.copyFileSync(path.join(BASE, "index.html"), path.join(dir, "index.html"));
  fs.writeFileSync(
    path.join(dir, "package.json"),
    JSON.stringify(
      {
        name: `js-framework-benchmark-${name}`,
        version: "1.0.0",
        description: `Koru probe: ${name}`,
        "js-framework-benchmark": { frameworkVersion: "", language: "Koru" },
        scripts: { dev: "exit 0", "build-prod": "exit 0" },
        license: "Apache-2.0",
      },
      null,
      2
    )
  );
  fs.writeFileSync(
    path.join(dir, "package-lock.json"),
    JSON.stringify(
      {
        name: `js-framework-benchmark-${name}`,
        version: "1.0.0",
        lockfileVersion: 3,
        requires: true,
        packages: { "": { name: `js-framework-benchmark-${name}`, version: "1.0.0", license: "Apache-2.0" } },
      },
      null,
      2
    )
  );
  console.log(`${name}: ${code.length} bytes (baseline ${src.length})`);
}
