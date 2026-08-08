// Probe E — isolate the DOM-detach half of the clear cost.
//
// korubulk changed two things at once (no rule sweep AND one DOM write), so it
// is a ceiling, not an isolation. This variant keeps the sweep-driven clear
// exactly as shipped — per-row take, removed-interceptor firing, both rule
// sweeps running — and changes ONLY how the observer writes the DOM: it
// batches instead of detaching a thousand elements one at a time.
//
// That is what "the removal observer gains a bulk form" would buy, with the
// store's own per-row work left untouched. With the three variants:
//   baseline -> korumap  = the page-search cost
//   korumap  -> koruE    = the per-element detach cost
//   koruE    -> korubulk = the rule-sweep cost
import fs from "node:fs";
import path from "node:path";

const REF = "/private/tmp/claude-501/-Users-larsde-src-koru/8b62cc24-de83-4ac4-af86-07f80bf61b9a/scratchpad/js-framework-benchmark";
const BASE = path.join(REF, "frameworks/keyed/koru");
let src = fs.readFileSync(path.join(BASE, "output_emitted.js"), "utf8");

function replace(text, from, to, expect) {
  const n = text.split(from).length - 1;
  if (n !== expect) throw new Error(`expected ${expect}, found ${n}: ${from.slice(0, 80)}`);
  return text.split(from).join(to);
}

// the observer skips its per-element write while a bulk removal is in flight
src = replace(
  src,
  `function domRow(id) {`,
  `let __koru_bulk = false;
function domRow(id) {`,
  1
);
src = replace(
  src,
  `      const id = __koru_input.id;
      const tr = domRow(id);
      tr.parentNode.removeChild(tr);`,
  `      const id = __koru_input.id;
      if (__koru_bulk) return;
      const tr = domRow(id);
      tr.parentNode.removeChild(tr);`,
  1
);
// clear runs the SAME sweep as shipped, then makes one aggregate DOM write
src = replace(
  src,
  `      main_module.__store_write_op_event.handler({ field: 0, value: 5 });
      main_module.sweep_event.handler({});
      main_module.__store_write_op_event.handler({ field: 0, value: 0 });`,
  `      __koru_bulk = true;
      main_module.__store_write_op_event.handler({ field: 0, value: 5 });
      main_module.sweep_event.handler({});
      main_module.__store_write_op_event.handler({ field: 0, value: 0 });
      __koru_bulk = false;
      document.querySelector("#tbody").textContent = "";`,
  1
);

const dir = path.join(REF, "frameworks/keyed/korubatch");
fs.mkdirSync(dir, { recursive: true });
fs.writeFileSync(path.join(dir, "output_emitted.js"), src);
fs.copyFileSync(path.join(BASE, "index.html"), path.join(dir, "index.html"));
const meta = (n) => ({ name: `js-framework-benchmark-${n}`, version: "1.0.0", "js-framework-benchmark": { frameworkVersion: "", language: "Koru" }, scripts: { dev: "exit 0", "build-prod": "exit 0" }, license: "Apache-2.0" });
fs.writeFileSync(path.join(dir, "package.json"), JSON.stringify(meta("korubatch"), null, 2));
fs.writeFileSync(path.join(dir, "package-lock.json"), JSON.stringify({ name: "js-framework-benchmark-korubatch", version: "1.0.0", lockfileVersion: 3, requires: true, packages: { "": { name: "js-framework-benchmark-korubatch", version: "1.0.0" } } }, null, 2));
console.log(`korubatch written: ${src.length} bytes`);
