---
type: belief
id: frag-a-build-that-does-not-name-its-compiler-can-be-a-different-program
provenance: DOM gauntlet round 9, 2026-08-08 — a clean build against another session's branch shipped un-rendered template text and cost a fifteen-minute timing run
ts: 2026-08-08
---

# A build that does not name its compiler can silently be a different program (belief)

`koruc` does not carry its standard library. On this machine
`/usr/local/lib/koru/koru_std` and `/usr/local/lib/koru/src` are symlinks into
one shared checkout, so any consumer build — an app, an example, a benchmark —
compiles against whatever branch that checkout happens to be sitting on. It
reports nothing about this. There is no flag to override it and no line in the
output that names it.

The failure that established the belief did not look like a build problem at
any point. The checkout was on another session's branch, which predated a fix
to how the store lowers a write that builds text. The app compiled with no
warning, no error, and a plausible byte count. It shipped a row whose visible
text was the *un-rendered template* — `{{ (&__koru_store_rows.label)[…] }} !!!`
— which meant every row carried a long literal string instead of a short label.
A full fifteen-minute timing run then reported the app 2.5× slower than the
previous round, degrading iteration by iteration in the shape of a memory leak.

Two things nearly went wrong from there, and both were the interesting part.
The result was almost read as a regression in the change under test, which it
had nothing to do with. And once the corrupted output was found, it was almost
filed as a compiler defect — against a fix that was correct, was on main, and
simply was not in the tree being used.

**The shared checkout is not the defect.** Sharing it is deliberate and a
worktree does not isolate it — a worktree's builds resolve the compiler through
the same symlinks. The defect is that a build inherits an arbitrary compiler
and says nothing, so a wrong build and a right build are indistinguishable
until the output is wrong in a way something happens to check.

That makes "check which branch it is on first" the wrong response, because it
is a resolution rather than a mechanism, and this trap had already fired once
that same day. The response that changes anything is a gate the build runs
itself: name the compiler tree and its branch out loud before compiling, refuse
a branch nobody asked for, and refuse an output carrying a shape that only a
mis-lowering produces. It costs a second and it fires before the fifteen
minutes rather than after.

**Its blind spot, which belongs in the belief rather than in a footnote:** the
output check catches exactly one corruption shape. Any other way a stale
compiler can emit a plausible-looking wrong program passes it. The branch check
is the general guard; the output check is one specific tripwire that happened
to be cheap because we had just watched it fail.

**And a COMMITTED artifact does not track its compiler either** — measured
2026-08-08 at 22:04, three hours after the belief above was written. The
benchmark app's emitted JavaScript is checked in beside its source. Rebuilding
it from unchanged sources, with the gate above passing and the compiler tree
on main and clean, did not reproduce the committed file: `koruc` had been
rebuilt at 21:06 and now wraps the row-removal body in a tag dispatch that the
committed build ran unconditionally.

This is the same disease with the diagnosis inverted. Above, the build was
suspect and the fix was to name the compiler. Here the build was *not* suspect
— it was committed, reviewed, and had a passing conformance run behind it —
and the compiler moved out from under it afterwards. A checked-in artifact
looks like a fact about the source; it is a fact about a moment. The gate the
build runs cannot help, because nobody runs a build.

What the gate cannot give you, a rebuild-and-compare can, and it costs nine
seconds: before measuring or publishing a committed artifact, rebuild it and
diff. If the bytes differ, the thing you were about to characterise is not the
thing the compiler now produces. On this occasion the difference turned out to
cost nothing — both builds measured 1.058 and 1.056 against hand-written
vanilla, identical on the very operation the change touched — but that was
found by measuring both, not by assuming either.

Relates to [[frag-a-bisect-is-only-as-good-as-the-artifact-under-test]] — the
same disease one layer down. There the artifact under test was stale; here the
*compiler that produced the artifact* was, which is worse, because rebuilding
is the move you make to rule staleness out.
