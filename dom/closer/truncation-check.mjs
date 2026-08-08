// Does koru's row label truncate? char[40] in dom/app/main.k:74 says it must,
// once a label plus four " !!!" marks passes forty characters. The official
// harness asserts exactly that string on row 991 after four updates.
import { chromium } from "playwright-core";

const url = process.argv[2];
const b = await chromium.launch({ channel: "chrome", headless: true });
const p = await b.newPage();
await p.goto(url, { waitUntil: "load" });
await p.click("#run");
await p.waitForSelector("tbody>tr:nth-of-type(1000)");
for (let i = 0; i < 4; i++) await p.click("#update");
await p.waitForTimeout(500);
const rows = await p.$$eval("tbody>tr", (trs) =>
  trs.map((tr, i) => ({ i: i + 1, text: tr.querySelector("td:nth-of-type(2)>a").textContent })),
);
const marked = rows.filter((r) => (r.i - 1) % 10 === 0);
const bad = marked.filter((r) => !r.text.endsWith(" !!! !!! !!! !!!"));
console.log(`marked rows: ${marked.length}`);
console.log(`rows NOT carrying four full marks: ${bad.length}`);
console.log(`every bad row is exactly 40 chars: ${bad.every((r) => r.text.length === 40)}`);
for (const r of bad.slice(0, 5)) console.log(`  row ${r.i}  len=${r.text.length}  ${JSON.stringify(r.text)}`);
const lens = marked.map((r) => r.text.length);
console.log(`label+marks length: min ${Math.min(...lens)} max ${Math.max(...lens)}`);
await b.close();
