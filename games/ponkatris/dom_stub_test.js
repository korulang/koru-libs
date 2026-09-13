// Headless DOM stub — run emitted ponkatris JS under node to prove the
// browser facet's mechanics: canvas creation, the interval pump, draw calls,
// and key down/pressed edge semantics. Not a browser — a contract check.
"use strict";

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

// Capture the frames pump's callback instead of scheduling it.
const realSetInterval = globalThis.setInterval;
globalThis.setInterval = (fn, ms) => { pump = fn; pump._ms = ms; return 42; };
globalThis.clearInterval = (id) => { if (id === 42) pump = null; };

// Load the emitted program (top-level script — runs on require).
require("./output_emitted.js");

console.log("canvas:", the_canvas ? `${the_canvas.width}x${the_canvas.height}` : "MISSING");
console.log("attached to body:", document.body.children.includes(the_canvas));
console.log("pump installed:", pump !== null, "ms:", pump && pump._ms);
console.log("ctx calls at install:", ctx_calls.length);

// Drive 5 frames. The marble should be falling (y increases from spawn 540).
pump();
const draws_after_1 = ctx_calls.length;
pump(); pump(); pump(); pump();
const draws_after_5 = ctx_calls.length;
console.log("ctx calls frame 1:", draws_after_1, "| after 5:", draws_after_5);

// Held key: dispatch ArrowLeft keydown, then a frame should see it down.
window.dispatch("keydown", { code: "ArrowLeft", preventDefault() {} });
pump();
window.dispatch("keyup", { code: "ArrowLeft", preventDefault() {} });
pump();
console.log("ctx calls after key frames:", ctx_calls.length);

// Sample of what got drawn — should include fillRect (clear), arc (ball),
// fillText (HUD).
const kinds = {};
for (const c of ctx_calls) kinds[c[0]] = (kinds[c[0]] || 0) + 1;
console.log("draw call kinds:", JSON.stringify(kinds));

// Text drawn — the HUD timer + score line.
const texts = ctx_calls.filter(c => c[0] === "fillText").map(c => c[1]);
console.log("sample texts:", JSON.stringify(texts.slice(-4)));
