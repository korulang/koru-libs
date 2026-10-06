---
type: belief
id: frag-raw-markup-is-a-placeholder-code
provenance: once-campfire-koru's room page (2026-10) — 131 messages carrying Action Text bodies, and a page shell that needs rendered children injected as markup
ts: 2026-10-06
---

# Trusted markup is a placeholder type code, not a bypass channel

Every `{{ x:t }}` code in koru/dom escapes — `s/d/f/b` all lower to text-safe
writes. A real page breaks that assumption in two places at once: an Action
Text body is already markup (`<p>…</p>` must arrive verbatim), and the Rails
partial shape — `<%= render @messages %>` — is rendered-child HTML injected
into a parent's slot. Without a raw code the only escapes are unbalanced
fragments (which the scanner correctly refuses) or markup spliced through
`page-write` (which pushes HTML out of components and into zig).

The ruling (Lars, 2026-10-06): **`h` is a type code.** `{{ body:h }}` declares
a `string` prop whose render write is verbatim — the `raw`/`html_safe`
meaning — and in the JS paint lowering it assigns `innerHTML`. Raw is a
property of the *slot*, declared where the markup is authored, so the trust
boundary is visible at the declaration rather than distributed across call
sites. Escaping stays the default; `h` is opt-in per placeholder.

The same measurement surfaced a second completeness gap: quoted attribute
values were all-or-nothing (`attr="lit"` or `attr={{x}}`), while real markup
is full of prefixed ids (`id="message_{{ cmid:s }}"`). Quoted values now split
into literal/placeholder parts exactly as element text does — mixed parts,
escaping per-part. The attr rule is now "parts," uniformly, whether the parts
are one literal, one placeholder, or a run of both.

Composition consequence: balanced-tree fragments plus a raw slot code yields
parent-takes-rendered-children composition — one `RoomPage` with `{{ rows:h }}`
in its messages container is the whole shell, and per-row components stay
balanced trees. No `<%= yield %>` machinery needed.

The open question deferred: whether `h` in a *child-component attr* should
also mark the parent's forwarding prop raw — currently the child's own
placeholder site decides rawness (escape happens where the value is rendered,
not forwarded), which is correct but worth revisiting if a shared prop is
rendered at multiple trust levels.

Related:
[[frag-program-items-is-one-level-deep]] — the transform bug measured on the
same page: decls in imported modules were invisible to a top-level-only walk.
