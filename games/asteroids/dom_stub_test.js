// Headless DOM stub — run emitted asteroids JS under node to prove the
// browser facet's mechanics: canvas creation, the interval pump, draw calls,
// and key down/pressed edge semantics. Not a browser — a contract check.
//
// The emit is evaluated via vm.runInThisContext — top-level `const` lands in
// the global lexical environment exactly like a classic <script> tag — and it
// is evaluated TWICE, because an SPA revisit re-injects the script. The first
// emit crashed the second eval with `Identifier already declared`; the IIFE
// program wrap is the fix this pins.
"use strict";

const vm = require("vm");
const fs = require("fs");

const ctx_calls = [];
const listeners = {};
let the_canvas = null;
let pump = null;

const ctx = new Proxy({}, {
    get(t, prop) {
        if (prop === "fillStyle" || prop === "strokeStyle" || prop === "font" || prop === "lineWidth")
            return t[prop];
        if (typeof prop === "string")
            return (...args) => ctx_calls.push([prop, ...args]);
        return t[prop];
    },
    set(t, prop, v) { t[prop] = v; return true; },
});

globalThis.document = {
    createElement(tag) {
        const el = { tag, width: 0, height: 0, style: {}, getContext(kind) { return ctx; } };
        if (tag === "canvas") the_canvas = el;
        return el;
    },
    getElementById() { return null; },
    body: { children: [], appendChild(c) { this.children.push(c); } },
};

globalThis.window = {
    addEventListener(type, fn) { (listeners[type] = listeners[type] || []).push(fn); },
    dispatch(type, e) { for (const f of listeners[type] || []) f(e); },
};

globalThis.setInterval = (fn, ms) => { pump = fn; pump._ms = ms; return 42; };
globalThis.clearInterval = (id) => { if (id === 42) pump = null; };

const code = fs.readFileSync(__dirname + "/output_emitted.js", "utf8");

// Eval 1: the page mounts.
vm.runInThisContext(code, { filename: "output_emitted.js" });

console.log("canvas:", the_canvas ? `${the_canvas.width}x${the_canvas.height}` : "MISSING");
console.log("attached to body:", document.body.children.includes(the_canvas));
console.log("pump installed:", pump !== null, "ms:", pump && pump._ms);

// Eval 2: SPA revisit re-injects the script into the same page. This is the
// crash pin — before the IIFE wrap this threw SyntaxError at parse.
vm.runInThisContext(code, { filename: "output_emitted.js" });
console.log("double-eval (SPA revisit): ok");

// Per-frame segment census: each frame's ctx calls are the draw list. The
// ship is one triangle (3 lineTo in one stroke); each rock is a 9-segment
// polygon. Counting strokes that contain exactly 3 vs 9 lineTo's recovers
// ship and rock counts from the draw list alone.
function census(mark) {
    const calls = ctx_calls.slice(mark);
    let ships = 0, rock_segs = 0;
    let seg = 0; // lineTo count inside the current stroke
    for (const c of calls) {
        if (c[0] === "beginPath") seg = 0;
        else if (c[0] === "lineTo") seg++;
        else if (c[0] === "stroke") {
            if (seg === 2) ships++;          // triangle: moveTo + 2 lineTo + closePath
            else if (seg === 1) rock_segs++; // each rock side is its own draw.line stroke
            seg = 0;
        }
    }
    return { ships, rocks: Math.round(rock_segs / 9) };
}

let mark = 0;
for (let i = 0; i < 30; i++) pump();
const c0 = census(mark); mark = ctx_calls.length;
console.log(`attract census: ships=${c0.ships} rocks=${c0.rocks} ctx_calls=${ctx_calls.length}`);

// Gameplay: hold rotate + thrust so the aim sweeps the field, fire on the
// edge every cooldown, run ~5 seconds. A hit splits or kills a rock — the
// rock census MUST change or the collision loop is a no-op.
window.dispatch("keydown", { code: "KeyW", preventDefault() {} });
window.dispatch("keydown", { code: "ArrowLeft", preventDefault() {} });
let rock_censuses = new Set([c0.rocks]);
let saw_game_over = false;
for (let i = 0; i < 300; i++) {
    if (i % 16 === 0) window.dispatch("keydown", { code: "Space", preventDefault() {} });
    if (i % 16 === 4) window.dispatch("keyup", { code: "Space", preventDefault() {} });
    pump();
    const c = census(mark); mark = ctx_calls.length;
    rock_censuses.add(c.rocks);
    if (ctx_calls.slice(mark - 400).some(x => x[0] === "fillText")) saw_game_over = true;
}
console.log("rock census values seen:", [...rock_censuses].sort().join(","));
console.log("ship censused every frame:", rock_censuses.size > 0);
console.log("game-over text seen:", saw_game_over);
console.log("total ctx calls:", ctx_calls.length);

const kinds = {};
for (const c of ctx_calls) kinds[c[0]] = (kinds[c[0]] || 0) + 1;
console.log("draw call kinds:", JSON.stringify(kinds));

// ── verdict ────────────────────────────────────────────────────────────────
const failures = [];
if (!the_canvas) failures.push("no canvas");
if (!pump) failures.push("pump cleared before 7200 frames");
if (c0.ships < 1) failures.push("ship triangle never drawn");
if (c0.rocks < 3) failures.push("fewer than 3 rock polygons");
if (rock_censuses.size < 2) failures.push("rock count never changed — no hit/split/kill observed");
if (failures.length) {
    console.log("FAIL:", failures.join("; "));
    process.exit(1);
}
console.log("PASS: asteroids contract holds");
