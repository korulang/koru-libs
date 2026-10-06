---
type: belief
id: frag-flow-module-is-the-file-stem
provenance: measured on once-campfire-koru — synthesized views:Msg-render lost impl-linking because the dom transform spelled the qualifier "index" (the stem of views/index.k), 2026-10-07
ts: 2026-10-07
---

# flow.module is the file stem, not the module's registered name

`item.flow.module` on a declaration inside `views/index.k` reads `"index"`.
The module_decl that wraps that file registers under `logical_name`
`"views"` — the directory (or `lib.k` stem) the loader canonicalised. A
transform that stamps synthesized paths with `flow.module` produces
`index:Msg-render`; registration, impl-linking, and dead-strip all key on
the logical name, so the decl lands correctly (appendItems routes by
canonical_path match) but every qualifier-aware lookup misses: the event registers as
`views:Msg-render`, the proc's own qualifier says `index:`, and KORU047
reports an implementation that is sitting right there.

The tell that makes it hard: it only bites companion-shaped modules. A
module that is a bare `lib.k` has stem == logical name and works; a
`views/` directory module — where the `.k` contract and `.kz` impl files
both have stems unrelated to the directory name — mismatches on every
synthesized qualifier.

The lookup the handler needs is the same one appendItems already does:
find the module_decl whose `canonical_path` equals the site's file (or its
dirname) and take its `logical_name`. The file, not the field, is the
identity.

The prior worth keeping: any AST field named `module` on a decl is
file-derived metadata — useful for diagnostics, wrong for path
construction. When a transform mints qualified names, the qualifier must
be the name the module registered under, not the name the file happened
to be called.
