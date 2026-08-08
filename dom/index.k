// koru/dom — a DOM component library for Koru, on the koru/vaxis template.
//
// The vaxis `run` shape (vaxis/index.kz:156-165): one long-running event owns
// the document for its whole body, consumers write effect branches and never
// an outer loop. In a terminal the producer blocks on nextEvent; in a browser
// there is nothing to block on — the host event loop IS the loop — so run's
// |js body installs its listeners and returns, and every later fire arrives
// from a closure. (Pinned live by the effect-continuation-in-closure shape
// this library's own probe established; the splice survives setTimeout and
// addEventListener alike.)
//
// Round 1 surface: the run shape with click delegation. That is deliberately
// all of it — every op the DOM gauntlet's create path needs, and nothing the
// suite has not pinned.
//
// ! ?click { action, id } — one delegated listener; the payload is read off
// the clicked element's closest [data-action] ancestor. `action` is an
// INTEGER code, not the element's string id, because runtime string equality
// has no Koru surface today: no passing test compares strings with == in a
// when-guard, an if, or a cond (the only string == in the whole suite is the
// comptime import bracket `~[build == "release"]`). vaxis dispatches keys the
// same way — `when k.ch == 'q'` is a number compare. When string guards land,
// `action` should become the element id and the codes should go.
//
// Not here yet, with reasons:
//   ! ready — a VOID effect op fired from a |js body emits `const _auto_N = ;`
//     (js_emitter.zig:2263-2270 binds the consumer arm off an empty fire-arg).
//     Pinned as a compiler defect; the mount hook returns when that lands.
//   component — the vaxis markup transform (vaxis/index.kz:2944). Stage-C
//     transforms DO run under --lang=js (std/store's new/insert/rule are
//     transforms and pass); the dom retarget is round-2 work, not blocked.

// A click carries WHERE IT LANDED, not just what was pressed.
//
// `key` is the key of the nearest keyed element the click happened inside —
// the same value the component was painted with. A consumer keyed on a store
// row therefore gets the row's handle back from the click directly, instead of
// reading an identifier out of the page and searching for the row that matches
// it.
//
// It is 0 when the click landed outside anything keyed, which is a designed
// absence rather than a sentinel picked for convenience: `std/store` reserves
// brand 0 precisely so no small integer can ever pass as a row address, so 0
// is the one i64 guaranteed not to name a row of any store.
pub tor run { title: string }
! ?click { action: i64, id: i64, key: i64 }

// The markup surface — `component(Name) { <markup> }`. A Stage-C transform
// (body in index.kz): capital tag = a call to that component's synthesized
// event; anything else passes through untouched (ruled 2026-08-07). The
// declaration is consumed at compile time; it has no runtime existence.
[comptime|transform|pre]pub tor component {
    expr: Expression,
    source: Source,
    invocation: *const Invocation,
    item: *const Item,
    program: *const Program,
    allocator: std.mem.Allocator
} -> SiteResult

// The inverse of a keyed paint: let go of the element a `key` owns.
//
// A component that takes a `key` remembers what it painted under it, so the
// element is reachable in one step instead of by searching the page. `drop`
// is how a consumer says the row is gone: it detaches what was painted and
// forgets it. Pass the same value the paint was given — from a store, that is
// `[id]` on the `! removed` arm, which is the same handle `! inserted` saw.
//
// Dropping a key nothing was painted under is a no-op, not an error: a row
// that never reached the page has nothing to take off it.
pub tor drop { key: i64 }

// The aggregate inverse: let go of EVERY element the library is holding.
//
// The twin of `drop` the way `std/store:clear` is the twin of `std/store:take`
// — and it exists for the same reason. Calling `drop` once per row is not the
// expensive part; being ASKED once per row is. A store's `! cleared` arm fires
// once, and this is what it calls.
pub tor drop-all {}
