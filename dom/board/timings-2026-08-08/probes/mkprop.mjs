// Build the `koruprop` probe: price the five attributes every painted row
// carries, by replacing them with what the hand-written reference does —
// identity as a plain JavaScript property on the element, and a delegation
// that decides the action from WHICH CELL was hit rather than from an
// attribute (vanillajs Main.js:168-185, 349-356).
//
// Every replacement asserts its hit count. A silently missed edit would
// measure the baseline and report it as a win.
import fs from "node:fs";

const p = process.argv[2];
let s = fs.readFileSync(p, "utf8");

function sub(needle, repl, expect) {
    const hits = s.split(needle).length - 1;
    if (hits !== expect) {
        console.error(`EXPECTED ${expect} of [${needle.slice(0, 70)}], found ${hits}`);
        process.exit(1);
    }
    s = s.split(needle).join(repl);
    console.log(`  ${hits}x  ${needle.slice(0, 66).replace(/\n/g, "\\n")}`);
}

// 1. the row template loses both baked data-action attributes
sub(String.raw`<a data-action=\"8\"></a>`, String.raw`<a></a>`, 1);
sub(String.raw`<a data-action=\"7\">`, String.raw`<a>`, 1);

// 2. the paint stops writing three data-id attributes; identity becomes a JS
//    property, plus the id->element book the row lookup now needs
sub(
    `__root.setAttribute("data-id", String(id));\n`,
    `__root.__koru_id = id;\n__koru_id_reg.set(id, __root);\n`,
    2,
);
sub(`__root.children[1].children[0].setAttribute("data-id", String(id));\n`, ``, 2);
sub(`__root.children[2].children[0].setAttribute("data-id", String(id));\n`, ``, 2);

// 3. select-row / swap-rows can no longer scan for an attribute that is gone
sub(
    `return document.querySelector("tr[data-id='" + id + "']");`,
    `return __koru_id_reg.get(id);`,
    1,
);

// 4. the id book has to be emptied with the rows, or it grows across every
//    clear and the run degrades iteration by iteration
sub(`__koru_dom_reg.clear();`, `__koru_dom_reg.clear();\n__koru_id_reg.clear();`, 1);
sub(
    `__koru_dom_reg.delete(key);`,
    `const __n = __koru_dom_reg.get(key);\nif (__n !== undefined && __n.__koru_id !== undefined) __koru_id_reg.delete(__n.__koru_id);\n__koru_dom_reg.delete(key);`,
    1,
);

// 5. delegation. The page BUTTONS still carry data-action — they live in the
//    static HTML and are not painted. Rows are identified by walking to the
//    TR and reading the property, with the action decided by which cell was
//    hit, which is what the reference does.
sub(
    `      const el = ev.target.closest("[data-action]");
      if (el === null) return;
      const action = parseInt(el.getAttribute("data-action"), 10);
      const idAttr = el.getAttribute("data-id");
      const id = idAttr === null ? 0 : parseInt(idAttr, 10);
      click({ action: action, id: id });`,
    `      let hit = ev.target;
      while (hit !== null && hit.tagName !== "TD" && hit.getAttribute !== undefined && hit.getAttribute("data-action") === null) hit = hit.parentNode;
      if (hit === null || hit.getAttribute === undefined) return;
      if (hit.tagName !== "TD") {
        click({ action: parseInt(hit.getAttribute("data-action"), 10), id: 0 });
        return;
      }
      const tr = hit.parentNode;
      if (tr.__koru_id === undefined) return;
      const cells = tr.children;
      if (cells[1] === hit) { click({ action: 8, id: tr.__koru_id }); return; }
      if (cells[2] === hit) { click({ action: 7, id: tr.__koru_id }); return; }`,
    1,
);

// the book itself
const anchor = `const __koru_dom_tpl_Row_0`;
if (s.split(anchor).length - 1 !== 1) {
    console.error("anchor not unique");
    process.exit(1);
}
s = s.replace(anchor, `const __koru_id_reg = new Map();\n` + anchor);

// nothing painted may still carry a data-id
const left = s.split(`setAttribute("data-id"`).length - 1;
if (left !== 0) {
    console.error(`still ${left} data-id writes in the paint — the probe would measure the baseline`);
    process.exit(1);
}

fs.writeFileSync(p, s);
console.log("koruprop written");
