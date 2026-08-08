import fs from "node:fs";
import path from "node:path";

const dir = process.argv[2];
const order = ["vanillajs", "koru", "korumap", "korubulk", "koruboth"];
const rows = {};
for (const f of fs.readdirSync(dir).filter((f) => f.endsWith(".json"))) {
  const j = JSON.parse(fs.readFileSync(path.join(dir, f), "utf8"));
  const fw = j.framework.replace(/-keyed$/, "").replace(/-v[\d.]+.*$/, "");
  rows[j.benchmark] ??= {};
  rows[j.benchmark][fw] = j.values?.total?.median;
}

const benches = Object.keys(rows).sort();
const w = 12;
console.log(
  "benchmark".padEnd(24) + order.map((o) => o.padStart(w)).join("") + "   (ms medians)"
);
for (const b of benches) {
  console.log(b.padEnd(24) + order.map((o) => (rows[b][o]?.toFixed(1) ?? "—").padStart(w)).join(""));
}
console.log();
console.log("ratio to vanillajs".padEnd(24) + order.slice(1).map((o) => o.padStart(w)).join(""));
for (const b of benches) {
  const v = rows[b]["vanillajs"];
  console.log(
    b.padEnd(24) +
      order
        .slice(1)
        .map((o) => (rows[b][o] && v ? (rows[b][o] / v).toFixed(2) : "—").padStart(w))
        .join("")
  );
}
// Geomean over the COMMON set only — a mean taken over different operation
// sets per variant silently flatters whichever variant is missing its worst
// result. Which operations it covers is printed, never implied.
const common = benches.filter((b) => order.every((o) => rows[b][o] != null));
const geo = (fw) => Math.exp(common.reduce((a, b) => a + Math.log(rows[b][fw] / rows[b]["vanillajs"]), 0) / common.length);
console.log();
console.log(`geomean over the ${common.length} operation(s) ALL variants have: ${common.join(", ")}`);
console.log("geomean vs vanillajs".padEnd(24) + order.slice(1).map((o) => geo(o).toFixed(2).padStart(w)).join(""));
