---
type: belief
id: frag-program-items-is-one-level-deep
provenance: measured on once-campfire-koru — koru/dom:component declared in an imported views/ module produced no synthesized tor and failed KORU080; std/store's flatItems memo documents the same pitfall on the read side.
ts: 2026-10-06
---

# program.items is one level deep

A transform handler that iterates `program.items` sees only the entry file's
items. Every imported module arrives as a single `.module_decl` wrapper whose
`.items` hold that module's declarations. A whole-program scan written against
`program.items` is therefore blind to anything declared inside a library —
and the failure never looks like a miss. The decl stays in the tree
unconsumed, so it surfaces downstream as a call-validation error that names
the wrong thing (koru/dom: `KORU080 'component' requires input 'expr'` —
the decl site misread as a call missing its transform-machinery arg).

`std/store`'s `flatItems` memo documents the same pitfall from the read side:
every direct `program.items` scan there is predicate-guarded for this reason.
The write side's twin rule is that `SiteResult.whole_program` is the wrong
shape for anything site-local — it makes the handler responsible for
placement it cannot see. The site-local ABI (`replacement` + `appended`)
exists precisely so placement belongs to the runner, whose `appendItems`
routes synthesized declarations into their home module_decl and whose
`replaceFlowRecursive` splices nested items in place.

Measured: `koru/dom:component` declared in an imported `views/` module
produced no synthesized `*-render` tor and failed KORU080 (repro:
component in `lib/index.k`, `lib:Greet-render` called from the entry file).
The fix was not descending harder — it was deleting the walk: the handler
reads the site's own `invocation`/`item` and returns the standard contract.

The prior worth keeping: when a transform's subject can legally live inside
a module (declarations, watches, queries), assume `program.items` shows you
the entry file only. Descend `.module_decl.items` for reads; for writes,
return `appended` and let `appendItems` route.
